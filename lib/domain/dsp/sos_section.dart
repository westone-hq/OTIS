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
