import 'package:shared_preferences/shared_preferences.dart';

/// 목적: 앱 설정(자동 로그인 정보, 이메일 주소, 마지막 현장 정보 등)을 기기에 저장하고 불러오는 역할을 한다.
///       메일 주소 저장/조회만 구현되어 있다. 나머지는 저장·출력 계층 리빌딩 대상이며
///       에러가 나도 앱이 죽지 않도록 무조건 빈 값을 반환하는 목업 상태다.
class PrefsStore {
  static final PrefsStore instance = PrefsStore._();
  PrefsStore._();

  /// 목적: 메일 주소 저장 키의 접두사. 다른 항목과 충돌하지 않게 분리한다.
  static const String _emailKeyPrefix = 'email:';

  /// 저장·출력 계층 리빌딩 대상. 현재는 동작하지 않는다.
  /// 목적: 기기에 저장된 자동 로그인 아이디를 불러온다. (현재는 항상 빈 값 반환)
  Future<String?> loadAutoLoginId() async => null;

  /// 저장·출력 계층 리빌딩 대상. 현재는 동작하지 않는다.
  /// 목적: 로그인에 성공한 아이디를 자동 로그인을 위해 기기에 저장한다.
  Future<void> saveAutoLoginId(String id) async {}

  /// 저장·출력 계층 리빌딩 대상. 현재는 동작하지 않는다.
  /// 목적: 로그아웃 시 저장되어 있던 자동 로그인 아이디를 지운다.
  Future<void> removeAutoLoginId() async {}

  /// 목적: 사용자별로 저장된 메일 수신 주소를 읽어온다.
  /// 인자: id — 사용자 식별자. 사용자별로 키를 분리해 섞이지 않게 한다
  /// 반환: 저장된 주소. 저장된 적이 없으면 null
  Future<String?> loadEmail(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_emailKeyPrefix$id');
  }

  /// 목적: 사용자별 메일 수신 주소를 저장한다.
  /// 인자: id — 사용자 식별자
  ///       email — 저장할 주소. 형식 검증은 호출부(설정 화면)에서 한다
  /// 반환: 없음
  Future<void> saveEmail(String id, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_emailKeyPrefix$id', email);
  }

  /// 저장·출력 계층 리빌딩 대상. 현재는 동작하지 않는다.
  /// 목적: 이전에 측정했던 현장 이름, 엘리베이터 층수 등의 정보를 불러와서 다음 측정 시 입력창을 자동으로 채워준다.
  Future<Map<String, String?>> loadLastSite() async => {};

  /// 저장·출력 계층 리빌딩 대상. 현재는 동작하지 않는다.
  /// 목적: 방금 측정한 현장 정보를 다음 측정 때 재사용할 수 있도록 저장한다.
  Future<void> saveLastSite(Map<String, String?> siteMap) async {}
}
