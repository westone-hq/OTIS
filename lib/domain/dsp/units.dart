/// 작성: 2026-10-22 23:55:00 · nada
/// 클래스: Units
/// 목적: 여러 계산이 함께 쓰는 단위 환산 상수. 같은 값을 파일마다 따로
///       두면 하나만 바뀌어 계산끼리 어긋날 수 있어 한 곳에 둔다.
abstract final class Units {
  /// 작성: 2026-09-15 14:32:07 · nada
  /// 수정: 2026-10-22 23:55:00 · nada
  /// 변수: mgToMetersPerSecondSquared
  /// 목적: mg(밀리지) → m/s² 환산 계수. 운동 계산(`Kinematics`) · 기준선
  ///       움직임 문턱(`SignalConditioner`) · 측정 중 속도
  ///       (`LiveSpeedEstimator`)가 쓴다.
  /// 근거: 표준 — 국제단위계(SI) 표준 중력 9.80665 m/s², 그 1/1000
  static const double mgToMetersPerSecondSquared = 9.80665e-3;
}
