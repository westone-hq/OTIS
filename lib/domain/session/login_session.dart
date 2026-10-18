import 'package:vibration_checker/model/worker.dart';

/// 작성: 2026-10-18 09:09:47 · nada
/// 클래스: LoginSession
/// 목적: 지금 로그인한 작업자를 앱 전체에 하나만 둔다. 라우터가 로그인
///       화면으로 돌릴지 정하고, 측정을 저장할 때(`MeasurementRecorder`)
///       그 시점 작업자를 결과에 싣는다. 채우고 비우는 일은
///       `LoginStore` 만 한다 — 기기 저장 값과 어긋나지 않게 한다.
class LoginSession {
  /// 작성: 2026-10-18 09:09:47 · nada
  /// 변수: instance
  /// 목적: 앱 전역에서 공유하는 단일 로그인 상태.
  static final LoginSession instance = LoginSession._();

  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: LoginSession._
  /// 목적: 외부에서 직접 생성하지 못하게 막는 전용 생성자. `instance`
  ///       하나만 쓰도록 강제한다.
  LoginSession._();

  /// 지금 로그인한 작업자. 로그인 전이거나 로그아웃했으면 null
  Worker? current;
}
