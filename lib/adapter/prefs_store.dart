import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 작성: 2026-08-19 10:35:27 · 박건준
/// 수정: 2026-10-04 14:30:00 · nada
/// 클래스: PrefsStore
/// 목적: 앱 설정(수신 이메일 주소, 마지막 현장 정보)을 기기에 저장하고
///       불러오는 역할을 한다.
class PrefsStore {
  /// 작성: 2026-07-05 08:15:28 · 박건준
  /// 변수: instance
  /// 목적: 앱 전역에서 공유하는 단일 저장소 인스턴스.
  static final PrefsStore instance = PrefsStore._();

  /// 작성: 2026-07-05 08:15:28 · 박건준
  /// 함수: PrefsStore._
  /// 목적: 외부에서 직접 생성하지 못하게 막는 전용 생성자. `instance`
  ///       하나만 쓰도록 강제한다.
  PrefsStore._();

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 수정: 2026-10-04 13:26:44 · nada
  /// 변수: _emailKey
  /// 목적: 메일 수신 주소의 저장 키.
  /// 근거: 미정 — 앱에 사용자 계정이 없어 기기 하나에 주소 하나만 둔다.
  ///       계정 체계가 정해지면 사용자별 키로 나눈다
  static const String _emailKey = 'email';

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 수정: 2026-10-04 13:26:44 · nada
  /// 함수: loadEmail
  /// 목적: 저장된 메일 수신 주소를 읽어온다.
  /// 반환: 저장된 주소. 저장된 적이 없으면 null
  Future<String?> loadEmail() async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    return prefs.getString(_emailKey);
  }

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 수정: 2026-10-04 13:26:44 · nada
  /// 함수: saveEmail
  /// 목적: 메일 수신 주소를 저장한다.
  /// 인자: email — 저장할 주소. 형식 검증은 호출부(설정 화면)에서 한다
  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    await prefs.setString(_emailKey, email);
  }

  /// 작성: 2026-10-04 14:30:00 · nada
  /// 변수: _lastSiteKey
  /// 목적: 마지막 현장 정보의 저장 키. 값은 항목 표를 JSON 문자열로 바꿔
  ///       한 칸에 둔다.
  static const String _lastSiteKey = 'lastSite';

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 수정: 2026-10-04 14:30:00 · nada
  /// 함수: loadLastSite
  /// 목적: 지난번 측정의 현장 정보를 불러온다. 홈 화면이 입력창을 미리
  ///       채우는 데 쓴다. 저장된 값이 깨져 있으면 저장된 적이 없는 것과
  ///       똑같이 빈 표를 돌려준다 — 미리 채우기는 편의 기능이라, 못
  ///       채워도 사용자가 다시 입력하면 된다.
  /// 반환: 항목 이름을 열쇠로 하는 저장값 표. 저장된 적이 없으면 빈 표
  Future<Map<String, String?>> loadLastSite() async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    final raw = prefs.getString(_lastSiteKey); // 저장된 JSON, 없으면 null
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw); // 되읽은 값. 표가 아니면 깨진 것
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString()),
      );
    } on FormatException {
      return {};
    }
  }

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 수정: 2026-10-04 14:30:00 · nada
  /// 함수: saveLastSite
  /// 목적: 방금 측정을 시작한 현장 정보를 다음 측정 때 다시 채울 수 있도록
  ///       저장한다. 이전 값은 덮어쓴다.
  /// 인자: siteMap — 항목 이름을 열쇠로 하는 현장 정보 표
  Future<void> saveLastSite(Map<String, String?> siteMap) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    await prefs.setString(_lastSiteKey, jsonEncode(siteMap));
  }
}
