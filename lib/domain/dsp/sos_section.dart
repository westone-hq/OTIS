import 'dart:typed_data';

/// 작성: 2026-10-07 01:44:43 · nada
/// 수정: 2026-10-23 00:00:00 · nada
/// 클래스: SosSection
/// 목적: 2차 구간(분자 · 분모가 2차식인 작은 필터. 여러 개를 차례로 이어
///       고차 필터를 만든다) 하나의 계수를 담는다. 순서는 SciPy `sos` 한
///       행 [b0, b1, b2, a0, a1, a2] 와 같고, a0 는 늘 1 이라 담지 않는다.
///       구간 목록을 한 방향으로 거는 `sosfilt()` 도 여기 둔다.
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

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 수정: 2026-10-23 00:00:00 · nada
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
