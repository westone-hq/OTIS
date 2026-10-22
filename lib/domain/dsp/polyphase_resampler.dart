import 'dart:math' as math;
import 'dart:typed_data';

/// 작성: 2026-10-07 01:55:02 · 박건준
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
  /// 작성: 2026-10-07 01:55:02 · 박건준
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

  /// 작성: 2026-10-07 01:55:02 · 박건준
  /// 함수: PolyphaseResampler._
  /// 목적: 약분한 배수와 설계한 계수를 그대로 담는 생성자.
  /// 인자: up — 약분한 늘리는 배수
  ///       down — 약분한 줄이는 배수
  ///       halfLen — 계수 가운데에서 한쪽 길이
  ///       taps — 거를 계수
  PolyphaseResampler._(this.up, this.down, this.halfLen, this.taps);

  /// 작성: 2026-10-07 01:55:02 · 박건준
  /// 변수: halfLenPerRate
  /// 목적: 계수 한쪽 길이를 큰 배수의 몇 배로 잡을지 정한다. 길수록 차단이
  ///       가팔라지고 계산이 늘어난다.
  /// 근거: 표준 — SciPy 1.18.1 `resample_poly()` 의 `half_len = 10 *
  ///       max_rate`
  static const int halfLenPerRate = 10;

  /// 작성: 2026-10-07 01:55:02 · 박건준
  /// 변수: kaiserBeta
  /// 목적: 계수에 곱하는 카이저 창(계수 양 끝을 0 쪽으로 줄여 잘린 끝에서
  ///       생기는 출렁임을 막는 가중치)의 모양값이다. 클수록 차단 대역이
  ///       더 깎이고 차단이 완만해진다.
  /// 근거: 표준 — SciPy 1.18.1 `resample_poly()` 의 기본 창
  ///       `('kaiser', 5.0)`
  static const double kaiserBeta = 5.0;

  /// 작성: 2026-10-07 01:55:02 · 박건준
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

  /// 작성: 2026-10-07 01:55:02 · 박건준
  /// 함수: outputLength
  /// 목적: 입력 표본 수에 대한 출력 표본 수를 반환한다.
  /// 인자: inputLength — 입력 표본 수
  /// 반환: 출력 표본 수
  /// 식: ceil(inputLength x up / down)
  /// 근거: 표준 — SciPy 1.18.1 `resample_poly()` 의 `n_out`
  int outputLength(int inputLength) => (inputLength * up + down - 1) ~/ down;

  /// 작성: 2026-10-07 01:55:02 · 박건준
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

  /// 작성: 2026-10-07 01:55:02 · 박건준
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

  /// 작성: 2026-10-07 01:55:02 · 박건준
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
