import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: AnalogBiquad
/// 목적: 아날로그 2차 전달함수(라플라스 변수 s 의 2차식 ÷ 2차식) 하나를
///       담는다. ISO 8041 가중 필터는 이 꼴의 단계 몇 개를 곱한 것으로
///       정의된다.
///       H(s) = (b2 s² + b1 s + b0) / (a2 s² + a1 s + a0)
class AnalogBiquad {
  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: AnalogBiquad
  /// 목적: 계수를 그대로 담는 생성자.
  /// 인자: b2, b1, b0 — 분자의 s², s, 상수 계수
  ///       a2, a1, a0 — 분모의 s², s, 상수 계수
  const AnalogBiquad({
    required this.b2,
    required this.b1,
    required this.b0,
    required this.a2,
    required this.a1,
    required this.a0,
  });

  /// 분자 s² 계수
  final double b2;

  /// 분자 s 계수
  final double b1;

  /// 분자 상수 계수
  final double b0;

  /// 분모 s² 계수
  final double a2;

  /// 분모 s 계수
  final double a1;

  /// 분모 상수 계수
  final double a0;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: toDigital
  /// 목적: 쌍선형 변환(아날로그 필터를 디지털 필터로 옮기는 표준 변환식)
  ///       으로 디지털 2차 구간을 만든다. 주파수를 미리 당기지 않는다 —
  ///       ISO 8041 가중은 아날로그 정의를 그대로 옮기고, 가중이 크게
  ///       변하는 주파수(≤ 12.5Hz)가 표본 속도(100Hz)의 절반보다 한참
  ///       낮아 휘는 정도가 작다.
  /// 인자: sampleRateHz — 거를 신호의 표본 속도 (Hz)
  /// 반환: a0 = 1 로 나눈 디지털 2차 구간
  /// 식: s = K (z - 1) / (z + 1),  K = 2 x sampleRateHz
  ///     B0 = b2 K² + b1 K + b0,  B1 = 2 b0 - 2 b2 K²,  B2 = b2 K² - b1 K + b0
  ///     (분모도 같은 꼴) 뒤 A0 로 나눈다
  /// 근거: 표준 — SciPy 1.18.1 `scipy.signal.bilinear(b, a, fs)` 와 같은 식
  SosSection toDigital(double sampleRateHz) {
    final k = 2 * sampleRateHz; // 쌍선형 변환 상수 K
    final kk = k * k; // K²
    final num0 = b2 * kk + b1 * k + b0; // 디지털 분자 z⁰ 계수 (정규화 전)
    final num1 = 2 * b0 - 2 * b2 * kk; // 디지털 분자 z⁻¹ 계수
    final num2 = b2 * kk - b1 * k + b0; // 디지털 분자 z⁻² 계수
    final den0 = a2 * kk + a1 * k + a0; // 디지털 분모 z⁰ 계수 (정규화 기준)
    final den1 = 2 * a0 - 2 * a2 * kk; // 디지털 분모 z⁻¹ 계수
    final den2 = a2 * kk - a1 * k + a0; // 디지털 분모 z⁻² 계수
    return SosSection(
      b0: num0 / den0,
      b1: num1 / den0,
      b2: num2 / den0,
      a1: den1 / den0,
      a2: den2 / den0,
    );
  }
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: RideWeighting
/// 목적: 승차감 진동 지표 전에 거는 주파수 가중. 사람이 느끼는 정도에 맞춰
///       주파수마다 값을 줄이거나 키우는 필터다(ISO 8041, ISO 2631-1).
///       - 수평(X · Y): Wd 가중 — 0.4Hz 고역 대역 제한 + 2Hz 가속도-속도
///         전이. 2Hz 위를 점점 줄인다
///       - 수직(Z): 1Hz 고역(양방향, `CaptureConfig.rideVerticalHighpassHz`)
///         으로 승강기 가감속을 뺀 뒤 Wk 가중 — 0.4Hz 고역 + 12.5Hz 전이 +
///         2.37 → 3.35Hz 위로 올리는 단계. 4~8Hz 를 가장 크게 본다
///       대역 제한의 100Hz 저역은 두지 않는다. 받는 신호가 이미 40Hz 저역
///       (`SignalConditioner`)을 거친 100Hz 표본이라 그 저역은 표본 속도의
///       절반(50Hz)을 넘어 디지털로 옮길 수 없고 할 일도 없다.
///       가중 필터는 한 방향(인과)으로 건다 — 양방향으로 걸면 크기 응답이
///       제곱돼 가중이 두 번 걸린다. 1Hz 고역만 양방향이다.
/// 근거: 표준 — ISO 8041 / ISO 2631-1 부속서 A 의 Wd · Wk 정의. 2026-10-15
///       Wd(0.5 · 1 · 2 · 8Hz) · Wk(0.5 · 1Hz) 의 주파수 응답을 ISO 2631-1
///       표 값과 대조해 소수 셋째 자리까지 같았다.
///       인용 — 2026-10-15 점검 지시: 원본 리포트(ISO 18738 방식)는 주파수
///       가중을 거친 신호로 지표를 낸다
abstract final class RideWeighting {
  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: methodLabel
  /// 목적: 결과 파일(result.json `signalConditioning`)에 신호 처리 문자열
  ///       (`SignalConditioner.methodLabel`) 뒤에 이어 붙이는 가중 · 구간
  ///       표기. 이 표기가 없는 예전 결과는 가중 · 운행 구간 없이 낸
  ///       지표다.
  ///       - `iso18738` — 출발 · 정지 0.5m 를 뺀 운행 구간에서 낸다
  ///       - `wd` — 수평 Wd 가중
  ///       - `zhp1wk` — 수직 1Hz 고역 + Wk 가중
  static const String methodLabel = 'iso18738(wd,zhp1wk)';

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: bandLimitHz
  /// 목적: Wd · Wk 공통 대역 제한 고역의 차단 주파수 (Hz).
  /// 근거: 표준 — ISO 2631-1 부속서 A, f1 = 0.4 Hz
  static const double bandLimitHz = 0.4;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: bandLimitQ
  /// 목적: 대역 제한 고역의 Q(봉우리 날카로움). 버터워스 2차 값이다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Q1 = 1/√2
  static const double bandLimitQ = 0.7071067811865476;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: wdTransitionHz
  /// 목적: Wd 가속도-속도 전이 주파수 (Hz). f3 = f4 로 같다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wd 의 f3 = f4 = 2.0 Hz
  static const double wdTransitionHz = 2.0;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: wdTransitionQ
  /// 목적: Wd 전이의 Q.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wd 의 Q4 = 0.63
  static const double wdTransitionQ = 0.63;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: wkTransitionHz
  /// 목적: Wk 가속도-속도 전이 주파수 (Hz). f3 = f4 로 같다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wk 의 f3 = f4 = 12.5 Hz
  static const double wkTransitionHz = 12.5;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: wkTransitionQ
  /// 목적: Wk 전이의 Q.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wk 의 Q4 = 0.63
  static const double wkTransitionQ = 0.63;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: wkStepLowHz
  /// 목적: Wk 위로 올리는 단계(upward step)의 아래 주파수 (Hz). 분자 쪽이다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wk 의 f5 = 2.37 Hz, Q5 = 0.91
  static const double wkStepLowHz = 2.37;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: wkStepHighHz
  /// 목적: Wk 위로 올리는 단계의 위 주파수 (Hz). 분모 쪽이다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wk 의 f6 = 3.35 Hz, Q6 = 0.91
  static const double wkStepHighHz = 3.35;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: wkStepQ
  /// 목적: Wk 위로 올리는 단계의 Q. 분자 · 분모가 같다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Q5 = Q6 = 0.91
  static const double wkStepQ = 0.91;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: _highpassStage
  /// 목적: 대역 제한 고역 단계를 만든다.
  /// 인자: hz — 차단 주파수 (Hz)
  ///       q — Q
  /// 반환: 아날로그 2차 단계
  /// 식: H(s) = s² / (s² + ω s / Q + ω²),  ω = 2π hz
  static AnalogBiquad _highpassStage(double hz, double q) {
    final w = 2 * math.pi * hz; // 차단 각주파수 (rad/s)
    return AnalogBiquad(b2: 1, b1: 0, b0: 0, a2: 1, a1: w / q, a0: w * w);
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: _transitionStage
  /// 목적: 가속도-속도 전이 단계를 만든다. 전이 주파수 아래는 그대로,
  ///       위는 주파수에 반비례해 줄인다(f3 = f4 인 경우만 쓴다).
  /// 인자: hz — 전이 주파수 f3 = f4 (Hz)
  ///       q — Q4
  /// 반환: 아날로그 2차 단계
  /// 식: H(s) = (1 + s / ω) / (1 + s / (Q ω) + s² / ω²)
  ///     = (ω s + ω²) / (s² + ω s / Q + ω²),  ω = 2π hz
  static AnalogBiquad _transitionStage(double hz, double q) {
    final w = 2 * math.pi * hz; // 전이 각주파수 (rad/s)
    return AnalogBiquad(b2: 0, b1: w, b0: w * w, a2: 1, a1: w / q, a0: w * w);
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: _upwardStepStage
  /// 목적: 위로 올리는 단계를 만든다. 아래 주파수보다 낮은 곳은
  ///       (f5 / f6)² 배로 줄이고 위 주파수보다 높은 곳은 그대로 둔다.
  /// 인자: lowHz — f5 (Hz)
  ///       highHz — f6 (Hz)
  ///       q — Q5 = Q6
  /// 반환: 아날로그 2차 단계
  /// 식: H(s) = (s² + ω5 s / Q + ω5²) / (s² + ω6 s / Q + ω6²)
  static AnalogBiquad _upwardStepStage(double lowHz, double highHz, double q) {
    final w5 = 2 * math.pi * lowHz; // 아래 각주파수 (rad/s)
    final w6 = 2 * math.pi * highHz; // 위 각주파수 (rad/s)
    return AnalogBiquad(
      b2: 1,
      b1: w5 / q,
      b0: w5 * w5,
      a2: 1,
      a1: w6 / q,
      a0: w6 * w6,
    );
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: wd
  /// 목적: Wd 가중을 디지털 2차 구간 목록으로 만든다.
  /// 인자: sampleRateHz — 거를 신호의 표본 속도 (Hz)
  /// 반환: [대역 제한 고역, 전이] 2차 구간
  static List<SosSection> wd(double sampleRateHz) => <SosSection>[
    _highpassStage(bandLimitHz, bandLimitQ).toDigital(sampleRateHz),
    _transitionStage(wdTransitionHz, wdTransitionQ).toDigital(sampleRateHz),
  ];

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: wk
  /// 목적: Wk 가중을 디지털 2차 구간 목록으로 만든다.
  /// 인자: sampleRateHz — 거를 신호의 표본 속도 (Hz)
  /// 반환: [대역 제한 고역, 전이, 위로 올리는 단계] 2차 구간
  static List<SosSection> wk(double sampleRateHz) => <SosSection>[
    _highpassStage(bandLimitHz, bandLimitQ).toDigital(sampleRateHz),
    _transitionStage(wkTransitionHz, wkTransitionQ).toDigital(sampleRateHz),
    _upwardStepStage(
      wkStepLowHz,
      wkStepHighHz,
      wkStepQ,
    ).toDigital(sampleRateHz),
  ];

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: _verticalHighpass
  /// 목적: 수직 진동의 가감속을 빼는 버터워스 고역을 설계한다.
  /// 인자: sampleRateHz — 표본 속도 (Hz)
  /// 반환: 고역 2차 구간 목록
  static List<SosSection> _verticalHighpass(double sampleRateHz) =>
      // → 로직 이동: Butterworth.highpass()
      Butterworth.highpass(
        order: CaptureConfig.rideVerticalHighpassOrder,
        cutoffHz: CaptureConfig.rideVerticalHighpassHz,
        sampleRateHz: sampleRateHz,
      );

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: canApply
  /// 목적: 이 길이 · 표본 속도의 시계열에 가중을 걸 수 있는지 알려 준다.
  ///       - 표본 속도가 Wk 전이 주파수(12.5Hz)의 두 배보다 커야 한다. 그
  ///         아래면 가중이 다루는 주파수를 표본이 담지 못한다
  ///       - 길이가 수직 고역 양방향 덧붙임(`Butterworth.padLength()`)보다
  ///         길어야 한다
  ///       운행 구간을 정할 수 있는 측정(운행 1 m 초과)은 늘 둘 다 맞는다.
  ///       짧은 시험용 격자를 가려내는 데 쓴다.
  /// 인자: length — 시계열 표본 수
  ///       sampleRateHz — 표본 속도 (Hz)
  /// 반환: 걸 수 있으면 true
  static bool canApply(int length, double sampleRateHz) {
    if (sampleRateHz <= 2 * wkTransitionHz) return false;
    // → 로직 이동: Butterworth.padLength()
    final pad = Butterworth.padLength(_verticalHighpass(sampleRateHz));
    return length > pad;
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: horizontal
  /// 목적: 수평(X · Y) 한 축에 Wd 가중을 한 방향으로 건다.
  /// 인자: series — 한 축 진동 시계열 (mg)
  ///       sampleRateHz — 표본 속도 (Hz)
  /// 반환: 가중한 시계열 (mg, 같은 길이)
  static List<double> horizontal(List<double> series, double sampleRateHz) =>
      // → 로직 이동: sosfilt()
      sosfilt(wd(sampleRateHz), series);

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: vertical
  /// 목적: 수직(Z) 진동에 1Hz 고역(양방향)을 건 뒤 Wk 가중을 한 방향으로
  ///       건다. 고역이 승강기 가감속을 빼므로 차트에서도 가감속 경사가
  ///       사라진다 — 가감속은 3쪽 가속도 차트가 따로 보여 준다.
  /// 인자: series — 수직 진동 시계열 (mg). 고역 덧붙임 길이
  ///       (`Butterworth.padLength()`)보다 길어야 한다
  ///       sampleRateHz — 표본 속도 (Hz)
  /// 반환: 가중한 시계열 (mg, 같은 길이)
  static List<double> vertical(List<double> series, double sampleRateHz) {
    // → 로직 이동: _verticalHighpass()
    final highpass = _verticalHighpass(sampleRateHz); // 가감속을 빼는 고역 구간
    // → 로직 이동: Butterworth.filtfilt()
    final steady = Butterworth.filtfilt(highpass, series); // 가감속을 뺀 신호
    return sosfilt(wk(sampleRateHz), steady); // → 로직 이동: sosfilt()
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: sosfilt
  /// 목적: 2차 구간들을 차례로 한 방향(앞에서 뒤로)으로 건다. 모든 구간의
  ///       내부 상태는 0 에서 출발한다 — 받는 신호가 기준선 0 맞춤
  ///       (`SignalConditioner`)을 거쳐 0 근처에서 시작하고, 출발 직후는
  ///       운행 구간(`TravelWindow`) 밖이라 지표에 들지 않는다.
  /// 인자: sections — 걸 2차 구간 목록
  ///       x — 거를 신호
  /// 반환: 거른 신호 (같은 길이)
  /// 식: 직접형 II 전치 구조
  ///     y = b0 x + s0,  s0 ← b1 x - a1 y + s1,  s1 ← b2 x - a2 y
  /// 근거: 표준 — SciPy 1.18.1 `sosfilt()`(zi 없이) · `lfilter()` 와 같은
  ///       계산
  static List<double> sosfilt(List<SosSection> sections, List<double> x) {
    final data = Float64List.fromList(x); // 거르며 덮어쓸 신호
    for (final s in sections) {
      var s0 = 0.0; // 내부 상태 첫째 칸
      var s1 = 0.0; // 내부 상태 둘째 칸
      for (var i = 0; i < data.length; i++) {
        final input = data[i]; // 이 구간에 들어온 값
        final y = s.b0 * input + s0; // 이 구간이 내보내는 값
        s0 = s.b1 * input - s.a1 * y + s1;
        s1 = s.b2 * input - s.a2 * y;
        data[i] = y;
      }
    }
    return data;
  }
}
