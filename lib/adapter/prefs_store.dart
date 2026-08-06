/// 목적: 앱 설정(자동 로그인 정보, 이메일 주소, 마지막 현장 정보 등)을 기기에 저장하고 불러오는 역할을 한다.
///       에러가 나도 앱이 죽지 않고 측정이 가능하도록, 아직 기능이 없어도 무조건 빈 값을 반환하게 뼈대만 만들어두었다.
class PrefsStore {
  static final PrefsStore instance = PrefsStore._();
  PrefsStore._();

  /// 목적: 기기에 저장된 자동 로그인 아이디를 불러온다. (현재는 항상 빈 값 반환)
  Future<String?> loadAutoLoginId() async => null;

  /// 목적: 로그인에 성공한 아이디를 자동 로그인을 위해 기기에 저장한다.
  Future<void> saveAutoLoginId(String id) async {}

  /// 목적: 로그아웃 시 저장되어 있던 자동 로그인 아이디를 지운다.
  Future<void> removeAutoLoginId() async {}

  /// 목적: 사용자가 이전에 리포트를 보냈던 이메일 주소를 불러온다.
  Future<String?> loadEmail(String id) async => null;

  /// 목적: 사용자가 입력한 이메일 주소를 다음에도 쓸 수 있게 저장한다.
  Future<void> saveEmail(String id, String email) async {}

  /// 목적: 이전에 측정했던 현장 이름, 엘리베이터 층수 등의 정보를 불러와서 다음 측정 시 입력창을 자동으로 채워준다.
  Future<Map<String, String?>> loadLastSite() async => {};

  /// 목적: 방금 측정한 현장 정보를 다음 측정 때 재사용할 수 있도록 저장한다.
  Future<void> saveLastSite(Map<String, String?> siteMap) async {}
}
