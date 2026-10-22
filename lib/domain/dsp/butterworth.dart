import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vibration_checker/domain/dsp/sos_section.dart';

/// 작성: 2026-10-07 01:44:43 · nada
/// 수정: 2026-10-15 16:50:04 · nada
/// 클래스: Butterworth
/// 목적: 버터워스 필터(통과 대역이 평평한 필터)를 설계하고, 앞으로 한 번 ·
///       뒤로 한 번 걸러 위상 지연이 없게 한다(양방향, 영위상). 저역은
///       지표 전 신호 처리(`SignalConditioner`)가, 고역은 수직 진동
///       가중(`RideWeighting.vertical()`)이 쓴다.
///       한 방향으로만 거르면 신호가 늦어지고 봉우리 모양이 비틀어져
///       최대 P2P 가 달라진다.
///       결과는 SciPy 1.18.1 의 `butter(..., output='sos')` ·
///       `sosfiltfilt()` 와 같아야 한다. 기대값 픽스처
///       (`test/fixtures/scipy/conditioning_*`)를 SciPy 로 만들었기 때문이다.
abstract final class Butterworth {
  /// 작성: 2026-10-07 01:44:43 · nada
  /// 수정: 2026-10-15 16:50:04 · nada
  /// 함수: lowpass
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
  static List<SosSection> lowpass({
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

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: highpass
  /// 목적: 디지털 버터워스 고역 필터를 2차 구간 목록으로 설계한다. 같은 차수
  ///       · 차단 주파수의 저역 필터(`lowpass()`)와 디지털 극점이 같고 영점과
  ///       이득만 다르다. 원형 극점이 단위원 위에 있어 고역 변환(p → wo / p)
  ///       이 극점 집합을 그대로 두기 때문이다. 그래서 저역 설계를 받아
  ///       분자만 바꾼다.
  ///       - 영점은 모두 +1(직류에서 응답 0)이라 분자는 [1, -2, 1]
  ///       - 전체 이득은 저역 이득에 (fs2 / wo)^N 을 곱한 값이고 첫 구간에
  ///         싣는다
  /// 인자: order — 필터 차수. 짝수
  ///       cutoffHz — 차단 주파수 (Hz). 0 보다 크고 표본 속도의 절반보다
  ///       작다
  ///       sampleRateHz — 거를 신호의 표본 속도 (Hz)
  /// 반환: 앞에서부터 차례로 걸 2차 구간 목록 (order / 2 개). 인자가 틀리면
  ///       `lowpass()` 와 같은 `ArgumentError`
  /// 식: k_hp = k_lp x (fs2 / wo)^N,  wo = fs2 x tan(π x cutoffHz / fs)
  ///     구간: b = [1, -2, 1], a = 저역과 같음
  /// 근거: 표준 — SciPy 1.18.1 `lp2hp_zpk()` · `bilinear_zpk()` 소스.
  ///       `butter(N, Wn, btype='high', output='sos')` 와 같은 값을 낸다
  static List<SosSection> highpass({
    required int order,
    required double cutoffHz,
    required double sampleRateHz,
  }) {
    // → 로직 이동: lowpass()
    final low = lowpass(
      order: order,
      cutoffHz: cutoffHz,
      sampleRateHz: sampleRateHz,
    ); // 같은 극점을 가진 저역 설계 (인자 검사도 여기서 한다)
    const fs2 = 4.0; // `lowpass()` 와 같은 정규화된 2 x fs
    final warped = // 미리 당겨 둔 아날로그 차단 각주파수
        fs2 * math.tan(math.pi * cutoffHz / sampleRateHz);
    final gain = // 첫 구간에 실을 전체 이득
        low.first.b0 * math.pow(fs2 / warped, order).toDouble();
    return [
      for (var i = 0; i < low.length; i++)
        SosSection(
          b0: i == 0 ? gain : 1.0,
          b1: i == 0 ? -2 * gain : -2.0,
          b2: i == 0 ? gain : 1.0,
          a1: low[i].a1,
          a2: low[i].a2,
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
