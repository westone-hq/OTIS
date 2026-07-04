import 'package:shared_preferences/shared_preferences.dart';

/// P5 · 인증 레포지토리 인터페이스 및 구현
/// - 사번 6자리 (숫자 6자리) 또는 T사번 (T + 숫자 5자리, 대소문자 무관) 검증
/// - PW == ID 검증 (D11, FR-2)
/// - 관리자 활성/비활성 여부 확인 (OI-2: 서버 확정 대기이므로 Local 은 항상 true 반환)
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
  static final _idPattern = RegExp(r'^(\d{6}|[Tt]\d{5})$');
  static const _kAutoLoginKey = 'auto_login_id';

  String? _currentUserId;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<String?> getAutoLoginId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kAutoLoginKey);
    if (savedId != null && _idPattern.hasMatch(savedId)) {
      _currentUserId = savedId;
      return _currentUserId;
    }
    return null;
  }

  @override
  Future<bool> login(String id, String pw) async {
    final trimmedId = id.trim();
    final trimmedPw = pw.trim();

    if (!_idPattern.hasMatch(trimmedId)) {
      throw const FormatException('아이디 형식을 확인하세요.\n사번 6자리 또는 T+숫자 5자리입니다.');
    }
    if (trimmedPw != trimmedId) {
      throw const FormatException('아이디 또는 비밀번호를 확인하세요.');
    }

    final enabled = await isEnabled(trimmedId);
    if (!enabled) {
      throw const FormatException('비활성화된 계정입니다. 관리자에게 문의하세요.');
    }

    _currentUserId = trimmedId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAutoLoginKey, _currentUserId!);
    return true;
  }

  @override
  Future<bool> isEnabled(String id) async {
    // TODO(OI-2): 서버 연동 확정 시 실제 API 또는 관리자 DB 조회로 교체.
    // 현재 LocalAuthRepository 는 항상 enabled(true) 반환.
    return true;
  }

  @override
  Future<void> logout() async {
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAutoLoginKey);
  }
}
