/// 목적: 앱 내의 로그인, 로그아웃, 사용자 세션 관리 등 인증 관련 기능을 정의하는 인터페이스(설계도)
///       현재는 서버 연동이 미정이라 임시로 항상 로그인된 것처럼 우회 처리되어 있다.
/// 근거: 미정 — 서버 로그인 API 연동 방식이 정해지면 원복 및 재작성 필요
abstract class AuthRepository {
  static AuthRepository instance = LocalAuthRepository();

  String? get currentUserId;

  /// 목적: 앱을 켰을 때 이전에 로그인한 기록(자동 로그인)이 남아있는지 확인하고 아이디를 가져온다.
  Future<String?> getAutoLoginId();

  /// 목적: 입력받은 아이디와 비밀번호로 로그인을 시도한다.
  Future<bool> login(String id, String pw);

  /// 목적: 해당 사용자 아이디가 현재 사용 정지(비활성화) 상태가 아닌지 서버에 물어본다.
  Future<bool> isEnabled(String id);

  /// 목적: 로그아웃 처리 후 저장된 로그인 정보를 지운다.
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
    // 서버 연동 전이므로 임시로 무조건 활성화(true) 상태로 넘긴다.
    return true;
  }

  @override
  Future<void> logout() async {
  }
}
