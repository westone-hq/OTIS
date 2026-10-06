import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';

/// 작성: 2026-10-07 01:44:43 · nada
/// 클래스: SosSection
/// 목적: 2차 구간(분자 · 분모가 2차식인 작은 필터. 여러 개를 차례로 이어
///       고차 필터를 만든다) 하나의 계수를 담는다. 순서는 SciPy `sos` 한
///       행 [b0, b1, b2, a0, a1, a2] 와 같고, a0 는 늘 1 이라 담지 않는다.
class SosSection {
  /// 작성: 2026-10-07 01:44:43 · nada
  /// 함수: SosSection
  /// 목적: 2차 구간 계수를 그대로 담는 생성자.
  /// 인자: b0, b1, b2 — 분자 계수
  ///       a1, a2 — 분모 계수 (a0 = 1 로 정규화한 뒤의 값)
  const SosSection({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  /// 분자 0차 계수
  final double b0;

  /// 분자 1차 계수
  final double b1;

  /// 분자 2차 계수
  final double b2;

  /// 분모 1차 계수 (a0 = 1 기준)
  final double a1;

  /// 분모 2차 계수 (a0 = 1 기준)
  final double a2;
}

/// 작성: 2026-10-07 01:44:43 · nada
/// 클래스: ButterworthLowpass
/// 목적: 버터워스 저역 필터(통과 대역이 평평한 저역 필터)를 설계하고, 앞으로
///       한 번 · 뒤로 한 번 걸러 위상 지연이 없게 한다(양방향, 영위상).
///       한 방향으로만 거르면 신호가 늦어지고 봉우리 모양이 비틀어져
///       최대 P2P 가 달라진다.
///       결과는 SciPy 1.18.1 의 `butter(..., output='sos')` ·
///       `sosfiltfilt()` 와 같아야 한다. 기대값 픽스처
///       (`test/fixtures/conditioning_*`)를 SciPy 로 만들었기 때문이다.
abstract final class ButterworthLowpass {
  /// 작성: 2026-10-07 01:44:43 · nada
  /// 함수: design
  /// 목적: 디지털 버터워스 저역 필터를 2차 구간 목록으로 설계한다. 필터
  ///       모양은 극점(응답이 끝없이 커지는 복소수 점)과 영점(응답이 0 이
  ///       되는 복소수 점)의 자리로 정한다.
  ///       1. 차단 주파수가 1 인 아날로그 원형(기준 모양) 극점을 차단
  ///          주파수로 늘린다. 쌍선형 변환(아날로그 필터를 디지털 필터로
  ///          옮기는 표준 변환식)이 주파수를 휘게 하므로 그만큼 미리
  ///          당겨 둔다
  ///       2. 쌍선형 변환으로 디지털 극점을 구한다. 영점은 모두 -1 이다
  ///       3. 켤레(허수부 부호만 다른 짝) 극점 쌍마다 2차 구간 하나를
  ///          만든다. 단위원(반지름 1 인 원. 극점이 가까울수록 응답이
  ///          뾰족해진다)에서 먼 쌍이 앞, 가까운 쌍이 뒤에 오고 전체 이득은
  ///          첫 구간에 싣는다. SciPy `zpk2sos()` 의 기본 짝짓기와 같은
  ///          순서다
  /// 인자: order — 필터 차수. 짝수
  ///       cutoffHz — 차단 주파수 (Hz). 0 보다 크고 표본 속도의 절반보다
  ///       작다
  ///       sampleRateHz — 거를 신호의 표본 속도 (Hz)
  /// 반환: 앞에서부터 차례로 걸 2차 구간 목록 (order / 2 개). 차수가 양의
  ///       짝수가 아니거나 차단 주파수가 0 과 표본 속도의 절반 사이에 있지
  ///       않으면 `ArgumentError` 를 던진다 — 설정값(`CaptureConfig`)으로
  ///       바꿀 수 있는 값이라 릴리스 빌드에서도 막는다
  /// 식: SciPy 는 표본 속도를 2 로 정규화하므로 fs2 = 2 x 2 = 4
  ///     wo = fs2 x tan(π x cutoffHz / sampleRateHz)        (`warped`)
  ///     p_m = wo x -exp(jπm / 2N),  m = -N+1, -N+3, …, N-1  (N = `order`)
  ///     z_m = (fs2 + p_m) / (fs2 - p_m)
  ///     k = wo^N / Π |fs2 - p_m|²  (켤레 쌍마다 한 번)     (`gain`)
  ///     구간: b = [1, 2, 1], a = [1, -2 Re z, |z|²]
  /// 근거: 표준 — SciPy 1.18.1 `iirfilter()` · `buttap()` · `lp2lp_zpk()`
  ///       · `bilinear_zpk()` · `zpk2sos()` 소스
  static List<SosSection> design({
    required int order,
    required double cutoffHz,
    required double sampleRateHz,
  }) {
    if (order <= 0 || order.isOdd) {
      throw ArgumentError.value(order, 'order', '양의 짝수 차수만 설계한다');
    }
    if (cutoffHz <= 0 || cutoffHz >= sampleRateHz / 2) {
      throw ArgumentError.value(
        cutoffHz,
        'cutoffHz',
        '차단 주파수는 0 과 표본 속도 $sampleRateHz Hz 의 절반 사이여야 한다',
      );
    }
    const fs2 = 4.0; // SciPy 가 표본 속도를 2 로 정규화한 뒤의 2 x fs
    final warped = // 미리 당겨 둔 아날로그 차단 각주파수
        fs2 * math.tan(math.pi * cutoffHz / sampleRateHz);
    var gain = math.pow(warped, order).toDouble(); // 첫 구간에 실을 전체 이득
    final pairs = <({double re, double im})>[]; // 위쪽 반평면 디지털 극점

    // m < 0 인 원형 극점이 위쪽 반평면에 놓인다. 아래쪽은 그 켤레다
    for (var m = -order + 1; m < 0; m += 2) {
      final theta = math.pi * m / (2 * order); // 원형 극점의 각 (라디안)
      final pRe = -warped * math.cos(theta); // 아날로그 극점 실수부
      final pIm = -warped * math.sin(theta); // 아날로그 극점 허수부 (양수)
      final den = // |fs2 - p|², 쌍선형 변환 분모의 크기 제곱
          (fs2 - pRe) * (fs2 - pRe) + pIm * pIm;
      gain /= den;
      pairs.add((
        re: (fs2 * fs2 - pRe * pRe - pIm * pIm) / den,
        im: 2 * fs2 * pIm / den,
      ));
    }

    // 극점이 단위원에서 떨어진 거리. 먼 쌍부터 둔다 — SciPy 는 가까운
    // 쌍을 맨 뒤 구간에 둔다
    double distance(({double re, double im}) z) =>
        (1 - math.sqrt(z.re * z.re + z.im * z.im)).abs();
    pairs.sort((a, b) => distance(b).compareTo(distance(a)));

    return [
      for (var i = 0; i < pairs.length; i++)
        SosSection(
          b0: i == 0 ? gain : 1.0,
          b1: i == 0 ? 2 * gain : 2.0,
          b2: i == 0 ? gain : 1.0,
          a1: -2 * pairs[i].re,
          a2: pairs[i].re * pairs[i].re + pairs[i].im * pairs[i].im,
        ),
    ];
  }

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 함수: padLength
  /// 목적: 양 끝에 덧붙이는 길이를 반환한다. 입력은 이보다 길어야 한다.
  /// 인자: sections — 걸 2차 구간 목록
  /// 반환: 한쪽 끝에 덧붙이는 표본 수
  /// 식: padlen = 3 x (2 x 구간 수 + 1)
  /// 근거: 표준 — SciPy 1.18.1 `sosfiltfilt()` 의 `padlen` 기본값. SciPy 는
  ///       b2 · a2 가 0 인 구간 수만큼 줄이지만, 버터워스 저역 구간은 둘 다
  ///       0 이 아니다
  static int padLength(List<SosSection> sections) =>
      3 * (2 * sections.length + 1);

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 함수: filtfilt
  /// 목적: 2차 구간 목록을 앞으로 한 번, 뒤로 한 번 걸어 위상 지연 없이
  ///       거른다. SciPy `sosfiltfilt(padtype='odd')` 의 순서를 따른다.
  ///       1. 양 끝을 끝값 기준 점대칭으로 `padLength()` 만큼 늘린다. 끝에서
  ///          필터가 0 부터 출발하며 생기는 출렁임을 덧붙인 쪽으로 밀어낸다
  ///       2. 구간마다 정상상태 초기값(같은 값이 끝없이 들어왔을 때의
  ///          내부 상태)에 첫 표본을 곱해 두고 앞으로 거른다
  ///       3. 거른 결과를 뒤에서부터 같은 방식으로 다시 거른다
  ///       4. 늘렸던 양 끝을 잘라낸다
  /// 인자: sections — 걸 2차 구간 목록
  ///       x — 거를 신호. `padLength()` 보다 길어야 한다
  /// 반환: 거른 신호 (x 와 같은 길이)
  /// 근거: 표준 — SciPy 1.18.1 `sosfiltfilt()` · `odd_ext()` 소스
  static List<double> filtfilt(List<SosSection> sections, List<double> x) {
    // → 로직 이동: padLength()
    final edge = padLength(sections); // 한쪽 끝에 덧붙이는 표본 수
    final n = x.length; // 입력 표본 수
    // 부르는 쪽(`SignalConditioner.condition()`)이 이보다 짧은 격자를 먼저
    // 사유와 함께 돌려보내므로 여기 오는 입력은 늘 이보다 길다
    assert(n > edge, '입력 $n 표본이 덧붙임 길이 $edge 보다 길어야 한다');

    final ext = Float64List(n + 2 * edge); // 양 끝을 늘린 신호
    for (var i = 0; i < edge; i++) {
      ext[i] = 2 * x[0] - x[edge - i];
      ext[edge + n + i] = 2 * x[n - 1] - x[n - 2 - i];
    }
    for (var i = 0; i < n; i++) {
      ext[edge + i] = x[i];
    }

    // → 로직 이동: _steadyState()
    final zi = _steadyState(sections); // 입력 1 에 대한 구간별 정상상태
    // → 로직 이동: _filterInPlace()
    _filterInPlace(sections, zi, ext, backward: false);
    // → 로직 이동: _filterInPlace()
    _filterInPlace(sections, zi, ext, backward: true);
    return Float64List.sublistView(ext, edge, edge + n);
  }

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 함수: _steadyState
  /// 목적: 입력이 처음부터 1 이었다면 각 구간의 내부 상태 두 칸이 어떤 값에
  ///       머물러 있을지를 구한다. 첫 표본을 곱해 초기값으로 쓰면 걸기
  ///       시작할 때 계단 응답이 생기지 않는다. 앞 구간들의 직류 이득(일정한
  ///       입력에 대해 출력이 입력의 몇 배인지)만큼 뒤 구간 값이 커진다.
  /// 인자: sections — 2차 구간 목록
  /// 반환: 구간별 내부 상태 (s0, s1)
  /// 식: B0 = b1 - a1 x b0,  B1 = b2 - a2 x b0
  ///     s0 = (B0 + B1) / (1 + a1 + a2),  s1 = B1 - a2 x s0
  ///     뒤 구간 배율 scale x= (b0 + b1 + b2) / (1 + a1 + a2)
  /// 근거: 표준 — SciPy 1.18.1 `sosfilt_zi()` · `lfilter_zi()` 소스.
  ///       SciPy 가 `np.linalg.solve()` 로 푸는 2x2 연립식을 손으로 풀어
  ///       쓴 꼴이다
  static List<({double s0, double s1})> _steadyState(
    List<SosSection> sections,
  ) {
    var scale = 1.0; // 앞 구간들의 직류 이득을 곱한 값
    final states = <({double s0, double s1})>[]; // 구간별 정상상태
    for (final s in sections) {
      final aSum = 1 + s.a1 + s.a2; // 분모 계수 합 (직류에서 분모 값)
      final bigB0 = s.b1 - s.a1 * s.b0; // 연립식 우변 첫째 칸
      final bigB1 = s.b2 - s.a2 * s.b0; // 연립식 우변 둘째 칸
      final s0 = (bigB0 + bigB1) / aSum; // 내부 상태 첫째 칸
      states.add((s0: scale * s0, s1: scale * (bigB1 - s.a2 * s0)));
      scale *= (s.b0 + s.b1 + s.b2) / aSum;
    }
    return states;
  }

  /// 작성: 2026-10-07 01:44:43 · nada
  /// 함수: _filterInPlace
  /// 목적: 2차 구간들을 차례로 걸어 신호를 그 자리에서 바꾼다. 모든 구간이
  ///       거르기 전 신호의 첫 표본에 정상상태를 곱한 값에서 출발한다.
  ///       앞 구간이 덮어쓴 값이 아니라 거르기 전 값을 쓴다 — SciPy 가
  ///       입력 첫 표본 하나를 모든 구간 초기값에 곱하기 때문이다.
  /// 인자: sections — 2차 구간 목록
  ///       zi — 입력 1 에 대한 구간별 정상상태 (`_steadyState()`)
  ///       data — 거를 신호. 결과로 덮어쓴다
  ///       backward — true 면 끝에서 앞으로 거른다
  /// 식: 직접형 II 전치 구조(SciPy 와 같은 2차 구간 계산 순서)
  ///     y = b0 x + s0
  ///     s0 ← b1 x - a1 y + s1
  ///     s1 ← b2 x - a2 y
  /// 근거: 표준 — SciPy 1.18.1 `sosfilt()` 의 구간 계산
  static void _filterInPlace(
    List<SosSection> sections,
    List<({double s0, double s1})> zi,
    Float64List data, {
    required bool backward,
  }) {
    final n = data.length; // 표본 수
    final first = data[backward ? n - 1 : 0]; // 거르기 전 시작 끝의 값
    for (var k = 0; k < sections.length; k++) {
      final s = sections[k]; // 이번 구간 계수
      var s0 = zi[k].s0 * first; // 내부 상태 첫째 칸
      var s1 = zi[k].s1 * first; // 내부 상태 둘째 칸
      for (var j = 0; j < n; j++) {
        final i = backward ? n - 1 - j : j; // 이번에 거를 표본 위치
        final x = data[i]; // 이 구간에 들어온 값
        final y = s.b0 * x + s0; // 이 구간이 내보내는 값
        s0 = s.b1 * x - s.a1 * y + s1;
        s1 = s.b2 * x - s.a2 * y;
        data[i] = y;
      }
    }
  }
}

/// 작성: 2026-10-07 01:55:02 · nada
/// 클래스: PolyphaseResampler
/// 목적: 신호의 표본 속도를 정수비 `up` / `down` 배로 바꾼다(재표본).
///       SciPy 1.18.1 `resample_poly(x, up, down, window=('kaiser', 5.0))`
///       와 같은 값을 낸다. 기대값 픽스처를 SciPy 로 만들었기 때문이다.
///       계산의 뜻은 다음 순서와 같다.
///       1. 표본 사이에 0 을 `up` - 1 개씩 끼워 넣어 늘린다
///       2. 저역 FIR 필터(정해진 길이의 계수를 곱해 더하는 필터)로 거른다
///       3. `down` 개마다 하나씩 남긴다
///       실제로는 늘린 배열을 만들지 않는다. 늘린 신호의 대부분이 0 이라,
///       출력 하나마다 실제 입력에 닿는 계수만 골라 곱한다(다상 방식).
///       25 / 64 이면 출력 하나에 계수 1281개 중 약 51개만 곱한다.
class PolyphaseResampler {
  /// 작성: 2026-10-07 01:55:02 · nada
  /// 함수: PolyphaseResampler
  /// 목적: 두 배수를 최대공약수로 약분하고 거를 계수를 설계해 둔다. 축마다
  ///       같은 계수를 쓰므로 한 번만 만든다.
  /// 인자: up — 늘리는 배수. 1 이상
  ///       down — 줄이는 배수. 1 이상
  /// 반환: 재표본기. 배수가 1 보다 작으면 `ArgumentError` 를 던진다
  /// 식: maxRate = max(up, down),  halfLen = 10 x maxRate
  ///     계수 = firwin(2 x halfLen + 1, 1 / maxRate, 카이저 창) x up
  /// 근거: 표준 — SciPy 1.18.1 `resample_poly()` 소스. 약분도 SciPy 가
  ///       하는 그대로다 (약분 전후로 계수 길이가 달라진다)
  factory PolyphaseResampler({required int up, required int down}) {
    if (up < 1 || down < 1) {
      throw ArgumentError('재표본 배수는 1 이상이어야 한다: up=$up, down=$down');
    }
    final divisor = up.gcd(down); // 두 배수의 최대공약수
    final reducedUp = up ~/ divisor; // 약분한 늘리는 배수
    final reducedDown = down ~/ divisor; // 약분한 줄이는 배수
    final maxRate = math.max(reducedUp, reducedDown); // 큰 쪽 배수
    final halfLen = halfLenPerRate * maxRate; // 계수 가운데에서 한쪽 길이
    // → 로직 이동: _lowpassTaps()
    final taps = _lowpassTaps(
      numTaps: 2 * halfLen + 1,
      cutoff: 1 / maxRate,
      gain: reducedUp.toDouble(),
    ); // 거를 계수 (직류 이득 `up`)
    return PolyphaseResampler._(reducedUp, reducedDown, halfLen, taps);
  }

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 함수: PolyphaseResampler._
  /// 목적: 약분한 배수와 설계한 계수를 그대로 담는 생성자.
  /// 인자: up — 약분한 늘리는 배수
  ///       down — 약분한 줄이는 배수
  ///       halfLen — 계수 가운데에서 한쪽 길이
  ///       taps — 거를 계수
  PolyphaseResampler._(this.up, this.down, this.halfLen, this.taps);

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 변수: halfLenPerRate
  /// 목적: 계수 한쪽 길이를 큰 배수의 몇 배로 잡을지 정한다. 길수록 차단이
  ///       가팔라지고 계산이 늘어난다.
  /// 근거: 표준 — SciPy 1.18.1 `resample_poly()` 의 `half_len = 10 *
  ///       max_rate`
  static const int halfLenPerRate = 10;

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 변수: kaiserBeta
  /// 목적: 계수에 곱하는 카이저 창(계수 양 끝을 0 쪽으로 줄여 잘린 끝에서
  ///       생기는 출렁임을 막는 가중치)의 모양값이다. 클수록 차단 대역이
  ///       더 깎이고 차단이 완만해진다.
  /// 근거: 표준 — SciPy 1.18.1 `resample_poly()` 의 기본 창
  ///       `('kaiser', 5.0)`
  static const double kaiserBeta = 5.0;

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 변수: _besselTermLimit
  /// 목적: 베셀 함수 급수를 멈추는 항 크기다. 항이 이보다 작아지면 더해도
  ///       배정밀도 실수 결과가 바뀌지 않는다.
  /// 근거: 표준 — 배정밀도 실수의 상대 정밀도는 약 2.2e-16 이고 I0(x) 는
  ///       1 이상이라, 이보다 작은 항은 결과를 바꾸지 않는다. x = 5 에서도
  ///       20항 안에 이 값 밑으로 내려간다
  static const double _besselTermLimit = 1e-17;

  /// 약분한 늘리는 배수
  final int up;

  /// 약분한 줄이는 배수
  final int down;

  /// 계수 가운데에서 한쪽 길이. 계수는 모두 2 x `halfLen` + 1 개다
  final int halfLen;

  /// 거를 계수. 가운데가 `halfLen` 번이고 좌우 대칭이다
  final Float64List taps;

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 함수: outputLength
  /// 목적: 입력 표본 수에 대한 출력 표본 수를 반환한다.
  /// 인자: inputLength — 입력 표본 수
  /// 반환: 출력 표본 수
  /// 식: ceil(inputLength x up / down)
  /// 근거: 표준 — SciPy 1.18.1 `resample_poly()` 의 `n_out`
  int outputLength(int inputLength) => (inputLength * up + down - 1) ~/ down;

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 함수: apply
  /// 목적: 신호 하나를 재표본한다. 입력 밖은 0 으로 보고(SciPy
  ///       `padtype='constant'`), 출력 자리는 SciPy 와 같게 맞춘다.
  ///       - 계수 앞에 0 을 `prePad` 개 붙인 셈 치고, 필터 출력의 앞
  ///         `preRemove` 개를 버린다. 그러면 계수 가운데가 출력 0 번
  ///         자리에 와서 출력이 입력보다 늦어지지 않는다
  ///       - SciPy 는 계수 뒤에도 0 을 붙여(n_post_pad) 필터 출력이 충분히
  ///         길게 만든다. 여기서는 필요한 출력 자리만 바로 계산하고, 0
  ///         계수는 합에 더할 것이 없어 붙이지 않는다
  ///       - 출력 k 번이 닿는 늘린 신호 자리 t 가 정해지면, 실제 입력 i 에
  ///         곱할 계수는 t - i x `up` 번 하나뿐이다. 그래서 계수를 `up`
  ///         칸씩 건너뛰며 곱한다
  /// 인자: x — 재표본할 신호
  /// 반환: 재표본한 신호. 길이는 `outputLength()`
  /// 식: prePad = down - halfLen mod down
  ///     preRemove = (halfLen + prePad) / down
  ///     t = (k + preRemove) x down - prePad
  ///     y[k] = Σ x[i] x taps[t - i x up],  0 ≤ t - i x up ≤ 2 x halfLen
  /// 근거: 표준 — SciPy 1.18.1 `resample_poly()` · `upfirdn()` 소스. 25 / 64
  ///       이면 prePad = 64, preRemove = 11 이다
  List<double> apply(List<double> x) {
    final n = x.length; // 입력 표본 수
    // → 로직 이동: outputLength()
    final out = Float64List(outputLength(n)); // 재표본한 신호
    final prePad = down - halfLen % down; // 계수 앞에 붙인 셈 치는 0 개수
    final preRemove = (halfLen + prePad) ~/ down; // 앞에서 버리는 출력 개수
    final lastTap = taps.length - 1; // 마지막 계수 번호
    for (var k = 0; k < out.length; k++) {
      // prePad 를 더하면 down 으로 나누어떨어지므로 t 는 halfLen 이상이다
      final t = (k + preRemove) * down - prePad; // 계수 번호 기준 자리
      final reach = t - lastTap; // 마지막 계수가 닿는 입력 자리 x up
      final iFirst = reach <= 0 ? 0 : (reach + up - 1) ~/ up; // 첫 입력 번호
      final iLast = math.min(n - 1, t ~/ up); // 마지막 입력 번호
      var sum = 0.0; // 이 출력에 쌓는 곱의 합
      for (var i = iFirst; i <= iLast; i++) {
        sum += x[i] * taps[t - i * up];
      }
      out[k] = sum;
    }
    return out;
  }

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 함수: _lowpassTaps
  /// 목적: 카이저 창을 씌운 저역 FIR 계수를 만든다. 이상적인 저역
  ///       필터의 응답(sinc, sin(πx) / (πx))을 정해진 길이로 자르고 창을
  ///       곱한 뒤, 직류 이득이 `gain` 이 되게 맞춘다. 0 을 끼워 늘린 신호는
  ///       평균이 1 / up 로 줄어 있어 이득 `up` 으로 되돌린다.
  /// 인자: numTaps — 계수 개수. 홀수
  ///       cutoff — 차단 주파수. 표본 속도의 절반을 1 로 본 비율 (0 ~ 1)
  ///       gain — 직류 이득
  /// 반환: 좌우 대칭 계수
  /// 식: α = (numTaps - 1) / 2,  m = n - α
  ///     h[n] = cutoff x sinc(cutoff x m)
  ///            x I0(β √(1 - (m / α)²)) / I0(β)        (β = `kaiserBeta`)
  ///     h[n] ← h[n] / Σh x gain
  /// 근거: 표준 — SciPy 1.18.1 `firwin(scale=True)` · `windows.kaiser()`
  ///       소스
  static Float64List _lowpassTaps({
    required int numTaps,
    required double cutoff,
    required double gain,
  }) {
    final alpha = (numTaps - 1) / 2; // 가운데 계수 번호
    // → 로직 이동: _besselI0()
    final windowScale = _besselI0(kaiserBeta); // 창 가운데 값을 1 로 맞출 몫
    final taps = Float64List(numTaps); // 만들 계수
    var sum = 0.0; // 계수 합 (직류 이득)
    for (var n = 0; n < numTaps; n++) {
      final m = n - alpha; // 가운데에서 떨어진 칸 수
      final arg = math.pi * cutoff * m; // sinc 의 πx
      final sinc = m == 0 ? 1.0 : math.sin(arg) / arg; // 이상적 저역 응답
      final edge = m / alpha; // 창 안 상대 위치 (-1 ~ 1)
      // → 로직 이동: _besselI0()
      final window = // 카이저 창 값 (0 ~ 1)
          _besselI0(kaiserBeta * math.sqrt(1 - edge * edge)) / windowScale;
      taps[n] = cutoff * sinc * window;
      sum += taps[n];
    }
    for (var n = 0; n < numTaps; n++) {
      taps[n] = taps[n] / sum * gain;
    }
    return taps;
  }

  /// 작성: 2026-10-07 01:55:02 · nada
  /// 함수: _besselI0
  /// 목적: 0차 제1종 변형 베셀 함수 I0 를 급수로 구한다. 카이저 창에
  ///       필요한데 Dart 표준 라이브러리에 없다. 항이 `_besselTermLimit`
  ///       보다 작아지면 멈춘다.
  /// 인자: x — 0 이상의 실수. 여기서는 0 ~ `kaiserBeta`
  /// 반환: I0(x). 1 이상
  /// 식: I0(x) = Σ ((x / 2)^k / k!)²,  k = 0, 1, 2, …
  ///     항_k = 항_(k-1) x (x² / 4) / k²
  /// 근거: 표준 — 변형 베셀 함수의 멱급수 전개
  static double _besselI0(double x) {
    final quarterSquare = x * x / 4; // 이웃 항 비의 분자 x² / 4
    var term = 1.0; // 지금 항 (k = 0 이면 1)
    var sum = 1.0; // 지금까지 더한 값
    var k = 0; // 지금 항 번호
    while (term >= _besselTermLimit) {
      k++;
      term *= quarterSquare / (k * k);
      sum += term;
    }
    return sum;
  }
}

/// 작성: 2026-10-07 02:22:28 · nada
/// 클래스: ConditioningFailure
/// 목적: 지표 계산 전 신호 처리가 실패한 원인의 종류. 화면이 사유 문자열을
///       비교하지 않고 이 값으로 안내 문구를 고른다.
///       - `gridTooShort` — 격자가 기준선 구간이나 필터 덧붙임 길이보다
///         짧다. 측정 시간이 모자란 경우다
///       - `invalidConfig` — 처리 설정(`CaptureConfig`)이 잘못됐다. 필터
///         차수 · 차단 주파수, 나노초로 나뉘지 않는 재표본 속도
enum ConditioningFailure { gridTooShort, invalidConfig }

/// 작성: 2026-10-07 02:01:58 · nada
/// 클래스: ConditionedGrid
/// 목적: 지표 계산 전 신호 처리(`SignalConditioner.condition()`)의 결과를
///       담는다. 처리한 격자는 `GridResampleResult` 형태 그대로라 지표
///       계산(`MeasurementAssembler`)이 받는 모양이 바뀌지 않는다. 각 축에서
///       뺀 기준선 값과 기준선 구간의 표준편차는 집계 파일(`meta.txt`)에
///       남기려고 함께 싣는다.
class ConditionedGrid {
  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: ConditionedGrid
  /// 목적: 처리에 성공한 격자와 기준선 값 · 표준편차를 그대로 담는 생성자.
  /// 인자: grid — 처리한 격자 (`CaptureConfig.conditionedRateHz` 간격)
  ///       baselineXMg, baselineYMg, baselineZMg — 각 축에서 뺀 기준선
  ///       값 (mg)
  ///       baselineStdXMg, baselineStdYMg, baselineStdZMg — 각 축 기준선
  ///       구간의 표준편차 (mg)
  const ConditionedGrid({
    required this.grid,
    required double this.baselineXMg,
    required double this.baselineYMg,
    required double this.baselineZMg,
    required double this.baselineStdXMg,
    required double this.baselineStdYMg,
    required double this.baselineStdZMg,
  }) : failureCause = null;

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: ConditionedGrid.failure
  /// 목적: 처리하지 못한 결과를 만든다. 기준선과 표준편차는 구하지
  ///       못했으므로 null 로 두고 0 으로 채우지 않는다.
  /// 인자: grid — 사유를 담은 실패 격자 (`GridResampleResult.failure`)
  ///       cause — 실패 원인의 종류
  const ConditionedGrid.failure(this.grid, ConditioningFailure cause)
    : failureCause = cause,
      baselineXMg = null,
      baselineYMg = null,
      baselineZMg = null,
      baselineStdXMg = null,
      baselineStdYMg = null,
      baselineStdZMg = null;

  /// 처리한 격자. 실패면 행이 없고 `failureReason` 에 사유가 있다. 행 수 이외
  /// 집계값(사용 · 폐기 이벤트 수, 앞뒤에서 버린 행 수)은 입력 격자 값을
  /// 그대로 옮긴 것이라 행 수 집계는 입력 격자(`targetSampleRateHz`) 기준이다
  final GridResampleResult grid;

  /// 실패 원인의 종류. 성공이면 null
  final ConditioningFailure? failureCause;

  /// X축에서 뺀 기준선 (mg). 실패면 null
  final double? baselineXMg;

  /// Y축에서 뺀 기준선 (mg). 실패면 null
  final double? baselineYMg;

  /// Z축에서 뺀 기준선 (mg). 실패면 null
  final double? baselineZMg;

  /// X축 기준선 구간의 표준편차 (mg). 기준선 구간에 손 움직임 같은 진동이
  /// 섞였는지 나중에 집계 파일에서 보려는 값이고, 판정에는 쓰지 않는다.
  /// 실패면 null
  final double? baselineStdXMg;

  /// Y축 기준선 구간의 표준편차 (mg). 실패면 null
  final double? baselineStdYMg;

  /// Z축 기준선 구간의 표준편차 (mg). 실패면 null
  final double? baselineStdZMg;

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: isSuccess
  /// 목적: 처리에 성공했는지 알려준다.
  bool get isSuccess => grid.isSuccess;

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: failureReason
  /// 목적: 처리 실패 사유를 반환한다. 성공이면 null.
  String? get failureReason => grid.failureReason;

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: rowCount
  /// 목적: 처리한 격자의 행 수를 반환한다. 실패면 0.
  int get rowCount => grid.rowCount;

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: sampleRateHz
  /// 목적: 처리한 격자의 표본 속도를 반환한다 (Hz). 격자 간격에서 구해
  ///       지표 계산(`MeasurementAssembler`)과 같은 식을 쓴다.
  /// 반환: 표본 속도 (Hz). 기본 설정이면 100.0
  /// 식: 1,000,000,000 / gridIntervalNs
  double get sampleRateHz => 1000000000 / grid.gridIntervalNs;
}

/// 작성: 2026-10-07 02:01:58 · nada
/// 클래스: SignalConditioner
/// 목적: 격자를 지표 · 리포트 계산 전에 오티스폰(OTIS iOS 앱)과 견줄 수
///       있는 모양으로 바꾼다. 2026-10-07 오티스폰 · 개발폰 동시 측정 6쌍
///       비교에서 정한 처리다.
///       - 기준선 0 맞춤 — 정지 상태에서 0 이 아닌 고정 오프셋을 뺀다
///       - 40Hz 저역 필터(양방향) — 오티스폰이 담지 못하는 50Hz 위 성분을
///         뺀다
///       - 100Hz 재표본 — 오티스폰과 같은 표본 속도로 맞춘다
///       격자 파일(`raw.txt`)에는 이 처리를 하지 않는다. 원시 데이터를
///       보존하려는 것이다.
class SignalConditioner {
  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: SignalConditioner
  /// 목적: 처리 설정을 받아 처리기를 만든다.
  /// 인자: config — 격자 속도와 처리 수치를 담은 수집 설정. 입력 격자를
  ///       만든 `GridResampler` 와 같은 설정이어야 한다
  const SignalConditioner({required this.config});

  /// 격자 속도와 처리 수치를 담은 수집 설정
  final CaptureConfig config;

  /// 작성: 2026-10-07 02:22:28 · nada
  /// 함수: methodLabel
  /// 목적: 이 처리기가 하는 처리를 짧은 문자열로 반환한다. 측정 결과
  ///       (`result.json` 의 `signalConditioning`)에 남겨, 처리 방식이
  ///       바뀐 뒤에도 어느 결과가 어떤 처리로 나왔는지 가린다.
  /// 반환: 처리 방식 문자열. 기본 설정이면 `baseline+lp40bw4zp+rs100`
  ///       (기준선 0 맞춤 + 40Hz 저역, 버터워스 4차, 영위상 + 100Hz 재표본)
  String get methodLabel =>
      'baseline+lp${config.lowpassCutoffHz}bw${config.lowpassOrder}zp'
      '+rs${config.conditionedRateHz}';

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: condition
  /// 목적: 격자 하나를 처리한다. 순서대로 진행한다.
  ///       1. 차단 주파수가 재표본 속도의 절반보다 낮은지 확인한다. 아니면
  ///          `ArgumentError` 를 던진다
  ///       2. 재표본 속도가 나노초 정수 간격으로 나뉘는지, 격자가 기준선
  ///          구간과 필터 덧붙임 길이보다 긴지 확인한다. 아니면 지어내지
  ///          않고 사유를 담아 실패한다
  ///       3. X · Y · Z 마다 첫 `baselineWindowMs` 평균(기준선)과 그 구간의
  ///          표준편차를 구하고 평균을 뺀다 (`_baseline()`,
  ///          `_baselineStd()`)
  ///       4. X · Y · Z 마다 저역 필터를 양방향으로 걸고
  ///          (`ButterworthLowpass.filtfilt()`), `conditionedRateHz` 로
  ///          재표본한다(`PolyphaseResampler.apply()`)
  ///       5. 소음 열은 거르지 않고 새 격자 시각에 선형 보간한다
  ///          (`_resampleNoise()`)
  ///       6. 시작 시각 · 집계값은 입력 격자 그대로 두고 간격만 바꾼 격자로
  ///          묶는다
  /// 인자: grid — 격자 환산(`GridResampler.resample()`)에 성공한 격자
  /// 반환: 처리한 격자와 기준선 · 표준편차. 격자가 짧거나 재표본 간격이
  ///       나뉘지 않으면 사유를 담은 실패 결과. 필터 설정(차수, 차단
  ///       주파수)이 잘못되면 `ArgumentError` 를 던진다
  /// 근거: 표준 — 재표본 속도의 절반 위 성분은 재표본 뒤 절반 아래로 접혀
  ///       들어와(앨리어싱) 없는 진동처럼 보인다. 필터가 그 위를 먼저
  ///       깎아야 한다
  ConditionedGrid condition(GridResampleResult grid) {
    if (config.lowpassCutoffHz * 2 >= config.conditionedRateHz) {
      throw ArgumentError.value(
        config.lowpassCutoffHz,
        'lowpassCutoffHz',
        '차단 주파수는 재표본 속도 ${config.conditionedRateHz} Hz 의 절반보다 '
            '낮아야 한다',
      );
    }
    final up = config.resampleUp; // 재표본에서 늘리는 배수
    final down = config.resampleDown; // 재표본에서 줄이는 배수
    // 두 배수는 두 속도를 최대공약수로 나눠 구하므로 늘 정확히 맞는다
    assert(
      config.targetSampleRateHz * up == config.conditionedRateHz * down,
      '재표본 비 $up/$down 이 ${config.targetSampleRateHz}Hz → '
      '${config.conditionedRateHz}Hz 와 맞지 않는다',
    );
    // 격자 환산기(`GridResampler`)와 같은 설정을 받으므로 늘 같다
    assert(
      grid.gridIntervalNs == config.idealIntervalNs,
      '입력 격자 간격 ${grid.gridIntervalNs}ns 가 설정 '
      '${config.idealIntervalNs}ns 와 다르다',
    );

    // 처리하지 못했을 때 입력 격자의 집계값을 실어 실패 결과를 만든다
    ConditionedGrid fail(String reason, ConditioningFailure cause) =>
        ConditionedGrid.failure(
          GridResampleResult.failure(
            reason,
            gridIntervalNs: config.conditionedIntervalNs,
            rawUsedCount: grid.rawUsedCount,
            gravityUsedCount: grid.gravityUsedCount,
            droppedZeroCount: grid.droppedZeroCount,
            droppedBackwardCount: grid.droppedBackwardCount,
            droppedLinearCount: grid.droppedLinearCount,
          ),
          cause,
        );

    if (!config.isConditionedGridExact) {
      return fail(
        '재표본 속도 ${config.conditionedRateHz} Hz 는 나노초 정수 간격으로 '
        '나뉘지 않아 등간격 격자를 만들 수 없다',
        ConditioningFailure.invalidConfig,
      );
    }
    final n = grid.rowCount; // 입력 격자 행 수
    final baselineRows = config.baselineWindowRows; // 기준선 구간 행 수
    if (n < baselineRows) {
      return fail(
        '격자가 $n행으로 기준선 구간 $baselineRows행'
        '(${config.baselineWindowMs}ms)보다 짧다',
        ConditioningFailure.gridTooShort,
      );
    }
    // → 로직 이동: ButterworthLowpass.design()
    final sections = ButterworthLowpass.design(
      order: config.lowpassOrder,
      cutoffHz: config.lowpassCutoffHz.toDouble(),
      sampleRateHz: config.targetSampleRateHz.toDouble(),
    ); // 저역 필터 2차 구간
    // → 로직 이동: ButterworthLowpass.padLength()
    final padRows = ButterworthLowpass.padLength(sections); // 덧붙임 길이
    if (n <= padRows) {
      // 기준선 구간이 덧붙임 길이보다 짧게 설정됐을 때만 온다
      return fail(
        '격자가 $n행으로 필터 덧붙임 길이 $padRows행보다 길지 않다',
        ConditioningFailure.gridTooShort,
      );
    }

    final resampler = PolyphaseResampler(up: up, down: down); // 축 공용 재표본기
    final samples = grid.samples; // 입력 격자 행
    final xs = samples.map((s) => s.xMg).toList(); // X 열 (mg)
    final ys = samples.map((s) => s.yMg).toList(); // Y 열 (mg)
    final zs = samples.map((s) => s.zMg).toList(); // Z 열 (mg)
    // → 로직 이동: _baseline()
    final baselineX = _baseline(xs, baselineRows); // X 기준선 (mg)
    // → 로직 이동: _baseline()
    final baselineY = _baseline(ys, baselineRows); // Y 기준선 (mg)
    // → 로직 이동: _baseline()
    final baselineZ = _baseline(zs, baselineRows); // Z 기준선 (mg)
    // → 로직 이동: _baselineStd()
    final stdX = _baselineStd(xs, baselineRows, baselineX); // X 표준편차
    // → 로직 이동: _baselineStd()
    final stdY = _baselineStd(ys, baselineRows, baselineY); // Y 표준편차
    // → 로직 이동: _baselineStd()
    final stdZ = _baselineStd(zs, baselineRows, baselineZ); // Z 표준편차

    // 한 축에서 기준선을 빼고 거른 뒤 재표본한다
    List<double> process(List<double> column, double baseline) {
      final shifted = [for (final v in column) v - baseline]; // 뺀 값 (mg)
      // → 로직 이동: ButterworthLowpass.filtfilt()
      final filtered = ButterworthLowpass.filtfilt(sections, shifted); // 거름
      // → 로직 이동: PolyphaseResampler.apply()
      return resampler.apply(filtered);
    }

    final outX = process(xs, baselineX); // 처리한 X (mg)
    final outY = process(ys, baselineY); // 처리한 Y (mg)
    final outZ = process(zs, baselineZ); // 처리한 Z (mg)
    // → 로직 이동: _resampleNoise()
    final outNoise = _resampleNoise(
      samples,
      up,
      down,
      outX.length,
    ); // 새 격자 시각의 소음 (dBA)

    return ConditionedGrid(
      grid: GridResampleResult(
        samples: [
          for (var k = 0; k < outX.length; k++)
            GridSample(
              xMg: outX[k],
              yMg: outY[k],
              zMg: outZ[k],
              noiseDba: outNoise[k],
            ),
        ],
        t0Ns: grid.t0Ns,
        gridIntervalNs: config.conditionedIntervalNs,
        rawUsedCount: grid.rawUsedCount,
        gravityUsedCount: grid.gravityUsedCount,
        droppedZeroCount: grid.droppedZeroCount,
        droppedBackwardCount: grid.droppedBackwardCount,
        droppedLinearCount: grid.droppedLinearCount,
        headTrimmedRows: grid.headTrimmedRows,
        tailTrimmedRows: grid.tailTrimmedRows,
        edgeTrimmedRows: grid.edgeTrimmedRows,
        rawMaxSpanNs: grid.rawMaxSpanNs,
        gravityMaxSpanNs: grid.gravityMaxSpanNs,
        degenerateSpanCount: grid.degenerateSpanCount,
      ),
      baselineXMg: baselineX,
      baselineYMg: baselineY,
      baselineZMg: baselineZ,
      baselineStdXMg: stdX,
      baselineStdYMg: stdY,
      baselineStdZMg: stdZ,
    );
  }

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: _baseline
  /// 목적: 측정 첫 구간의 평균(기준선)을 구한다. 정지 상태에서 0 이어야 할
  ///       진동값이 고정 오프셋만큼 떠 있으면, 그 오프셋이 반주기 P2P 에
  ///       계속 섞여 평균 진동(A95)이 크게 틀어진다.
  /// 인자: column — 한 축의 값 (mg)
  ///       rows — 평균을 낼 앞쪽 행 수. 1 이상, `column` 길이 이하
  /// 반환: 앞쪽 `rows` 행의 평균 (mg)
  /// 식: baseline = (1 / rows) x Σ column[i],  i = 0 … rows - 1
  /// 근거: 측정 — 2026-10-06 개발폰 원본 기록에서 정지 상태 가속도 센서
  ///       크기는 996~998mg 인데 중력 센서 크기는 늘 1000.0mg 이다. 진동
  ///       = 가속도 - 중력이라 그 차이가 Z 에 -2 ~ -4mg 오프셋으로 남는다.
  ///       X · Y 는 0.0~0.3mg 이고, 측정 처음과 끝 값이 같다(최종1 Z:
  ///       -4.03 / -4.09mg). 최종1 Z A95 는 보정 전 17.5mg, 보정 후 6.2mg,
  ///       오티스폰 5.1mg 이다
  static double _baseline(List<double> column, int rows) {
    var sum = 0.0; // 앞쪽 행 값의 합 (mg)
    for (var i = 0; i < rows; i++) {
      sum += column[i];
    }
    return sum / rows;
  }

  /// 작성: 2026-10-07 02:10:57 · nada
  /// 함수: _baselineStd
  /// 목적: 기준선 구간의 표준편차를 구한다. 기준선 구간은 정지 상태라고
  ///       가정하는데, 거치하며 손이 닿아 진동이 섞이면 이 값이 커진다.
  ///       나중에 집계 파일에서 확인하려는 값이고 판정 · 실패 처리는 하지
  ///       않는다.
  /// 인자: column — 한 축의 값 (mg)
  ///       rows — 기준선 구간 행 수. 1 이상, `column` 길이 이하
  ///       mean — 같은 구간의 평균 (`_baseline()`, mg)
  /// 반환: 모표준편차 (mg)
  /// 식: std = √((1 / rows) x Σ (column[i] - mean)²),  i = 0 … rows - 1
  /// 근거: 표준 — 모표준편차(나누는 수가 rows). NumPy `std()` 기본값과 같다
  static double _baselineStd(List<double> column, int rows, double mean) {
    var sumSquares = 0.0; // 평균에서 벗어난 값 제곱의 합 (mg²)
    for (var i = 0; i < rows; i++) {
      final d = column[i] - mean; // 평균에서 벗어난 값 (mg)
      sumSquares += d * d;
    }
    return math.sqrt(sumSquares / rows);
  }

  /// 작성: 2026-10-07 02:01:58 · nada
  /// 함수: _resampleNoise
  /// 목적: 소음 열을 새 격자 시각으로 옮긴다. 소음은 안드로이드가 RMS(제곱
  ///       평균의 제곱근, 소리 크기를 구하는 계산) 창으로 이미 구간마다
  ///       낸 값이라 거르지 않고 선형 보간만 한다. 시각은 입력
  ///       격자 첫 행을 0 초로 두고 출력 k 행을 k / `conditionedRateHz` 초로
  ///       본다. X · Y · Z 재표본 출력과 같은 정렬이다.
  ///       - 양옆 입력 중 하나라도 0(미측정)이면 0 을 쓴다. 0 과 측정값을
  ///         섞어 재지 않은 중간값을 지어내지 않는다
  ///       - 출력 시각이 입력 행 시각과 정확히 겹치면 그 행 값을 쓴다
  ///       - 마지막 입력 시각보다 뒤인 출력 행은 마지막 입력값을 쓴다. 밖으로
  ///         늘려 계산하지 않는다
  /// 인자: samples — 입력 격자 행
  ///       up, down — 재표본 배수 (`CaptureConfig.resampleUp` · `resampleDown`)
  ///       outLength — 출력 행 수. X · Y · Z 재표본 결과와 같다
  /// 반환: 새 격자 시각의 소음 (dBA). 0 이면 미측정
  /// 식: p = k x down / up            (입력 행 번호로 잰 출력 시각)
  ///     j = floor(p),  α = (k x down mod up) / up
  ///     소음 = 값_j + α x (값_(j+1) - 값_j)
  /// 근거: 표준 — 두 점 사이 선형 보간 공식
  static List<double> _resampleNoise(
    List<GridSample> samples,
    int up,
    int down,
    int outLength,
  ) {
    final n = samples.length; // 입력 행 수
    final last = samples[n - 1].noiseDba; // 마지막 입력 소음 (dBA)
    final out = Float64List(outLength); // 새 격자 시각의 소음
    for (var k = 0; k < outLength; k++) {
      final scaled = k * down; // 출력 시각 x up (입력 행 번호 기준, 정수)
      final j = scaled ~/ up; // 출력 시각 바로 앞 입력 행
      final remainder = scaled % up; // 앞 행에서 떨어진 정도 x up
      if (j >= n - 1) {
        out[k] = last;
        continue;
      }
      final before = samples[j].noiseDba; // 앞 행 소음 (dBA)
      if (remainder == 0) {
        out[k] = before;
        continue;
      }
      final after = samples[j + 1].noiseDba; // 뒤 행 소음 (dBA)
      out[k] = before == 0.0 || after == 0.0
          ? 0.0
          : before + (after - before) * remainder / up;
    }
    return out;
  }
}
