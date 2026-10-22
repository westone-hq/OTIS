import 'dart:math' as math;

import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/dsp/analog_biquad.dart';
import 'package:vibration_checker/domain/dsp/butterworth.dart';
import 'package:vibration_checker/domain/dsp/sos_section.dart';

/// 작성: 2026-10-15 16:50:04 · 박건준
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
  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: methodLabel
  /// 목적: 결과 파일(result.json `signalConditioning`)에 신호 처리 문자열
  ///       (`SignalConditioner.methodLabel`) 뒤에 이어 붙이는 가중 · 구간
  ///       표기. 이 표기가 없는 예전 결과는 가중 · 운행 구간 없이 낸
  ///       지표다.
  ///       - `iso18738` — 출발 · 정지 0.5m 를 뺀 운행 구간에서 낸다
  ///       - `wd` — 수평 Wd 가중
  ///       - `zhp1wk` — 수직 1Hz 고역 + Wk 가중
  static const String methodLabel = 'iso18738(wd,zhp1wk)';

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: bandLimitHz
  /// 목적: Wd · Wk 공통 대역 제한 고역의 차단 주파수 (Hz).
  /// 근거: 표준 — ISO 2631-1 부속서 A, f1 = 0.4 Hz
  static const double bandLimitHz = 0.4;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: bandLimitQ
  /// 목적: 대역 제한 고역의 Q(봉우리 날카로움). 버터워스 2차 값이다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Q1 = 1/√2
  static const double bandLimitQ = 0.7071067811865476;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: wdTransitionHz
  /// 목적: Wd 가속도-속도 전이 주파수 (Hz). f3 = f4 로 같다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wd 의 f3 = f4 = 2.0 Hz
  static const double wdTransitionHz = 2.0;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: wdTransitionQ
  /// 목적: Wd 전이의 Q.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wd 의 Q4 = 0.63
  static const double wdTransitionQ = 0.63;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: wkTransitionHz
  /// 목적: Wk 가속도-속도 전이 주파수 (Hz). f3 = f4 로 같다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wk 의 f3 = f4 = 12.5 Hz
  static const double wkTransitionHz = 12.5;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: wkTransitionQ
  /// 목적: Wk 전이의 Q.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wk 의 Q4 = 0.63
  static const double wkTransitionQ = 0.63;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: wkStepLowHz
  /// 목적: Wk 위로 올리는 단계(upward step)의 아래 주파수 (Hz). 분자 쪽이다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wk 의 f5 = 2.37 Hz, Q5 = 0.91
  static const double wkStepLowHz = 2.37;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: wkStepHighHz
  /// 목적: Wk 위로 올리는 단계의 위 주파수 (Hz). 분모 쪽이다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Wk 의 f6 = 3.35 Hz, Q6 = 0.91
  static const double wkStepHighHz = 3.35;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 변수: wkStepQ
  /// 목적: Wk 위로 올리는 단계의 Q. 분자 · 분모가 같다.
  /// 근거: 표준 — ISO 2631-1 부속서 A, Q5 = Q6 = 0.91
  static const double wkStepQ = 0.91;

  /// 작성: 2026-10-15 16:50:04 · 박건준
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

  /// 작성: 2026-10-15 16:50:04 · 박건준
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

  /// 작성: 2026-10-15 16:50:04 · 박건준
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

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: wd
  /// 목적: Wd 가중을 디지털 2차 구간 목록으로 만든다.
  /// 인자: sampleRateHz — 거를 신호의 표본 속도 (Hz)
  /// 반환: [대역 제한 고역, 전이] 2차 구간
  static List<SosSection> wd(double sampleRateHz) => <SosSection>[
    _highpassStage(bandLimitHz, bandLimitQ).toDigital(sampleRateHz),
    _transitionStage(wdTransitionHz, wdTransitionQ).toDigital(sampleRateHz),
  ];

  /// 작성: 2026-10-15 16:50:04 · 박건준
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

  /// 작성: 2026-10-15 16:50:04 · 박건준
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

  /// 작성: 2026-10-15 16:50:04 · 박건준
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

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 수정: 2026-10-23 00:00:00 · 박건준
  /// 함수: horizontal
  /// 목적: 수평(X · Y) 한 축에 Wd 가중을 한 방향으로 건다.
  /// 인자: series — 한 축 진동 시계열 (mg)
  ///       sampleRateHz — 표본 속도 (Hz)
  /// 반환: 가중한 시계열 (mg, 같은 길이)
  static List<double> horizontal(List<double> series, double sampleRateHz) =>
      // → 로직 이동: SosSection.sosfilt()
      SosSection.sosfilt(wd(sampleRateHz), series);

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 수정: 2026-10-23 00:00:00 · 박건준
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
    // → 로직 이동: SosSection.sosfilt()
    return SosSection.sosfilt(wk(sampleRateHz), steady);
  }
}
