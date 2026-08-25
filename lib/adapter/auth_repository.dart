/// 작성: 2026-08-19 10:35:09 · 박건준
/// 클래스: AuthRepository
/// 목적: 앱 내의 로그인, 로그아웃, 사용자 세션 관리 등 인증 관련 기능을 정의하는 인터페이스(설계도)
///       현재는 서버 연동이 미정이라 임시로 항상 로그인된 것처럼 우회 처리되어 있다.
/// 근거: 미정 — 서버 로그인 API 연동 방식이 정해지면 원복 및 재작성 필요
abstract class AuthRepository {
  /// 작성: 2026-07-04 17:07:21 · 박건준
  /// 변수: instance
  /// 목적: 앱 전역에서 쓰는 단일 인증 저장소 인스턴스. 항상
  ///       `LocalAuthRepository`(임시 구현체)를 가리킨다.
  static AuthRepository instance = LocalAuthRepository();

  /// 작성: 2026-08-19 10:35:09 · 박건준
  /// 함수: currentUserId
  /// 목적: 지금 로그인된 사용자의 식별자를 돌려준다. 로그인하지 않았으면 null
  String? get currentUserId;

  /// 작성: 2026-08-19 10:35:09 · 박건준
  /// 함수: logout
  /// 목적: 로그아웃 처리 후 저장된 로그인 정보를 지운다.
  Future<void> logout();
}

/// 작성: 2026-08-19 10:35:09 · 박건준
/// 클래스: LocalAuthRepository
/// 목적: `AuthRepository`의 임시 구현체. 서버 로그인이 아직 연동되지
///       않아, 실제 인증 없이 항상 성공·로그인된 것처럼 동작한다.
class LocalAuthRepository implements AuthRepository {
  /// 작성: 2026-08-19 10:35:09 · 박건준
  /// 함수: currentUserId
  /// 목적: 서버 로그인이 아직 연동되지 않아, 실제 로그인 여부와 관계없이
  ///       항상 같은 임시 아이디를 돌려준다
  /// 근거: 미정 — 로그인 화면이 빠지면서 임시 고정 아이디로 우회 중.
  ///       서버 로그인 API 연동 시 원복 필요
  @override
  String? get currentUserId => 'T00000';

  /// 작성: 2026-08-19 10:35:09 · 박건준
  /// 함수: logout
  /// 목적: 로그아웃 처리 후 저장된 로그인 정보를 지운다.
  /// 미구현: 저장 계층이 없어 본문이 비어 있다. 설정 화면이 이 함수를
  ///       부른 뒤 `/login`으로 이동시키지만, 그 경로 자체가
  ///       라우터(router.dart)에 등록돼 있지 않아 실제로는 아무 화면도
  ///       뜨지 않는다.
  @override
  Future<void> logout() async {}
}
