/// [연결] 설정 저장 어댑터. UI 계약 시그니처만 유지한다.
///
/// 다른 어댑터와 달리 예외를 던지지 않고 무해한 빈값을 돌려준다 —
/// 홈 화면 진입 시 loadLastSite 가 호출되므로, 여기서 예외가 나면
/// 측정 화면까지 도달할 수 없어 수집 실측 자체가 불가능해지기 때문이다.
/// 실제 저장은 저장·출력 계층 리빌딩에서 구현한다. 기존 구현: main 브랜치 git 이력.
class PrefsStore {
  static final PrefsStore instance = PrefsStore._();
  PrefsStore._();

  /// 목적: 저장된 자동 로그인 ID — 미구현, 항상 null
  Future<String?> loadAutoLoginId() async => null;

  /// 목적: 자동 로그인 ID 저장 — 미구현, 아무 동작 없음
  Future<void> saveAutoLoginId(String id) async {}

  /// 목적: 자동 로그인 ID 삭제 — 미구현, 아무 동작 없음
  Future<void> removeAutoLoginId() async {}

  /// 목적: 저장된 수신 이메일 — 미구현, 항상 null
  Future<String?> loadEmail(String id) async => null;

  /// 목적: 수신 이메일 저장 — 미구현, 아무 동작 없음
  Future<void> saveEmail(String id, String email) async {}

  /// 목적: 마지막 현장 정보 — 미구현, 항상 빈 값 (홈 화면은 빈칸으로 시작)
  Future<Map<String, String?>> loadLastSite() async => {};

  /// 목적: 현장 정보 저장 — 미구현, 아무 동작 없음
  Future<void> saveLastSite(Map<String, String?> siteMap) async {}
}
