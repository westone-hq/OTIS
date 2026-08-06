/// P5 · 인증 레포지토리 인터페이스 및 구현
/// - 사번 6자리 (숫자 6자리) 또는 T사번 (T + 숫자 5자리, 대소문자 무관) 검증
/// - PW == ID 검증 (D11, FR-2)
/// - 관리자 활성/비활성 여부 확인 (OI-2: 서버 확정 대기이므로 Local 은 항상 true 반환)
///
/// [우회] 인증 미구현 상태의 임시 처리.
/// 고정 사용자 T00000 으로 항상 로그인 상태를 반환한다.
/// 인증 기능 착수 시 이 파일 전체를 원복해야 한다.
/// 근거: 미정 — 서버 인증 연동 방침 확정 후 재작성
abstract class AuthRepository {
  static AuthRepository instance = LocalAuthRepository();

  String? get currentUserId;

  /// 자동 로그인 상태를 복원하고 유효한 ID가 있으면 반환
  Future<String?> getAutoLoginId();

  /// 로그인 시도 (성공 시 ID 반환 및 영속화, 실패 시 예외 또는 null 반환)
  Future<bool> login(String id, String pw);

  /// 관리자 ID 활성/비활성 여부 조회 (Req.2-③, OI-2)
  Future<bool> isEnabled(String id);

  /// 로그아웃 및 세션 초기화
  Future<void> logout();
}

class LocalAuthRepository implements AuthRepository {
  @override
  String? get currentUserId => 'T00000';

  @override
  Future<String?> getAutoLoginId() async {
    return 'T00000';
  }

  @override
  Future<bool> login(String id, String pw) async {
    return true;
  }

  @override
  Future<bool> isEnabled(String id) async {
    // OI-2: 서버 연동 확정 시 실제 API 또는 관리자 DB 조회로 교체.
    // 현재 LocalAuthRepository 는 항상 enabled(true) 반환.
    return true;
  }

  @override
  Future<void> logout() async {
  }
}
