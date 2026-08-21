import 'package:shared_preferences/shared_preferences.dart';

/// 작성: 2026-08-19 10:35:27 · 박건준
/// 클래스: PrefsStore
/// 목적: 앱 설정(이메일 주소, 마지막 현장 정보 등)을 기기에 저장하고
///       불러오는 역할을 한다.
/// 현재 상태: `loadEmail()`과 `saveEmail()`만 실제로 저장·조회한다.
///       나머지(최근 현장 정보를 다루는 `loadLastSite()`,
///       `saveLastSite()`)는 예외를 던지지 않고 null 또는 빈 값을
///       그대로 돌려준다 — 저장한 것처럼 보이지만 실제로는 저장되지
///       않는다. 호출하는 곳에서 실패 여부를 알 수 없으므로, 구현
///       전까지 그 값을 신뢰하면 안 된다.
class PrefsStore {
  static final PrefsStore instance = PrefsStore._();
  PrefsStore._();

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 변수: _emailKeyPrefix
  /// 목적: 메일 주소 저장 키의 접두사. 다른 항목과 충돌하지 않게 분리한다.
  static const String _emailKeyPrefix = 'email:';

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 함수: loadEmail
  /// 목적: 사용자별로 저장된 메일 수신 주소를 읽어온다.
  /// 인자: id — 사용자 식별자. 사용자별로 키를 분리해 섞이지 않게 한다
  /// 반환: 저장된 주소. 저장된 적이 없으면 null
  Future<String?> loadEmail(String id) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    return prefs.getString('$_emailKeyPrefix$id');
  }

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 함수: saveEmail
  /// 목적: 사용자별 메일 수신 주소를 저장한다.
  /// 인자: id — 사용자 식별자
  ///       email — 저장할 주소. 형식 검증은 호출부(설정 화면)에서 한다
  Future<void> saveEmail(String id, String email) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    await prefs.setString('$_emailKeyPrefix$id', email);
  }

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 함수: loadLastSite
  /// 목적: 이전에 측정했던 현장 이름, 엘리베이터 층수 등의 정보를 불러와서 다음 측정 시 입력창을 자동으로 채워준다.
  /// 미구현: 저장 계층이 없어 예외 없이 항상 빈 Map을 돌려준다. 홈
  ///       화면(home_screen.dart)의 `_loadSavedInputs()`가 이 값을
  ///       불러 각 입력창에 채우는데, 늘 비어 있어 저장된 적이
  ///       없는 것처럼 항상 기본값 상태로 남는다.
  Future<Map<String, String?>> loadLastSite() async => {};

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 함수: saveLastSite
  /// 목적: 방금 측정한 현장 정보를 다음 측정 때 재사용할 수 있도록 저장한다.
  /// 미구현: 저장 계층이 없어 본문이 비어 있다. 홈 화면이 측정 시작
  ///       시 이 함수를 불러 저장한 것처럼 동작하지만 실제로는 아무
  ///       것도 기록되지 않는다.
  Future<void> saveLastSite(Map<String, String?> siteMap) async {}
}
