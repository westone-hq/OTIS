import 'package:vibration_checker/domain/session/site_info.dart';

/// 작성: 2026-07-04 15:04:38 · 박건준
/// 수정: 2026-10-04 18:15:24 · 박건준
/// 클래스: MeasurementSession
/// 목적: 화면 사이에 넘기는 이번 측정의 상태 보관소. 홈 화면 → 시작
///       화면 → 측정 화면이 차례로 채우고 읽는다. 앱 전체에 하나만 둔다.
class MeasurementSession {
  /// 작성: 2026-07-04 15:04:38 · 박건준
  /// 변수: instance
  /// 목적: 앱 전역에서 공유하는 단일 세션 인스턴스.
  static final MeasurementSession instance = MeasurementSession._();

  /// 작성: 2026-07-04 15:04:38 · 박건준
  /// 함수: MeasurementSession._
  /// 목적: 외부에서 직접 생성하지 못하게 막는 전용 생성자. `instance`
  ///       하나만 쓰도록 강제한다.
  MeasurementSession._();

  /// 홈 화면에서 입력한 이번 측정의 현장 정보. 아직 입력 전이면 null
  SiteInfo? currentSite;

  /// 측정 시작 전 카운트다운 대기 시간 (초). 0이면 카운트다운 없이 곧바로
  /// 시작. 시작 화면이 고른 값을 싣는다. 시작 화면을 거치지 않고 결과
  /// 화면의 "테스트 재실행" 으로 바로 잴 때도 휴대폰을 놓을 틈이 있도록
  /// 시작 화면의 기본값(5초)과 같게 둔다
  int delaySec = 5;
}
