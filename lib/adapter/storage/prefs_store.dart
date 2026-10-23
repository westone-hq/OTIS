import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 작성: 2026-08-19 10:35:27 · 박건준
/// 수정: 2026-10-18 09:41:12 · 박건준
/// 클래스: PrefsStore
/// 목적: 앱 설정(수신 이메일 목록, 지난번 수신자, 로그인 사번, 마지막
///       현장 정보, 업데이트 "나중에" 기록)을 기기에 저장하고 불러오는
///       역할을 한다. 로그인 전에 설정에 손으로 적던 엔지니어 이름
///       (저장 키 "engineerName")은 2026-10-18 로그인 작업자 성명으로
///       바꾸며 읽지 않는다. 예전 빌드가 남긴 값은 지우지 않고 둔다.
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
  /// 수정: 2026-10-04 16:44:32 · 박건준
  /// 변수: _legacyEmailKey
  /// 목적: 수신 주소를 하나만 두던 때의 저장 키. 목록으로 바꾼 뒤에는
  ///       `loadEmails()` 가 처음 한 번 읽어 목록으로 옮길 때만 쓴다.
  static const String _legacyEmailKey = 'email';

  /// 작성: 2026-10-04 16:44:32 · 박건준
  /// 변수: _emailsKey
  /// 목적: 수신 이메일 목록의 저장 키.
  /// 근거: 미정 — 앱에 사용자 계정이 없어 기기 하나에 목록 하나를 둔다.
  ///       계정 체계가 정해지면 사용자별 키로 나눈다
  static const String _emailsKey = 'emails';

  /// 작성: 2026-10-04 16:44:32 · 박건준
  /// 변수: _lastRecipientsKey
  /// 목적: 지난번 메일을 보낸 수신자 목록의 저장 키. 메일 시트가 다음에
  ///       열릴 때 같은 주소를 미리 골라 둔다.
  static const String _lastRecipientsKey = 'lastRecipients';

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 수정: 2026-10-04 16:44:32 · 박건준
  /// 함수: loadEmails
  /// 목적: 저장된 수신 이메일 목록을 읽는다. 목록이 아직 없고 예전 한 칸
  ///       짜리 주소가 남아 있으면 그 주소 하나로 목록을 만들어 돌려준다.
  /// 반환: 저장된 차례대로의 주소 목록. 저장된 적이 없으면 빈 목록
  Future<List<String>> loadEmails() async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    final list = prefs.getStringList(_emailsKey); // 저장된 목록, 없으면 null
    if (list != null) return list;
    final legacy = prefs.getString(_legacyEmailKey); // 예전 한 칸 주소
    if (legacy == null || legacy.trim().isEmpty) return <String>[];
    return <String>[legacy];
  }

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 수정: 2026-10-04 16:44:32 · 박건준
  /// 함수: saveEmails
  /// 목적: 수신 이메일 목록을 통째로 저장한다. 예전 한 칸 주소는 목록으로
  ///       옮겨졌으므로 지운다.
  /// 인자: emails — 저장할 주소 목록. 형식 검사와 중복 제거는 호출부(설정
  ///       화면)에서 한다
  Future<void> saveEmails(List<String> emails) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    await prefs.setStringList(_emailsKey, emails);
    await prefs.remove(_legacyEmailKey);
  }

  /// 작성: 2026-10-04 16:44:32 · 박건준
  /// 함수: loadLastRecipients
  /// 목적: 지난번 메일을 보낸 수신자 목록을 읽는다.
  /// 반환: 주소 목록. 보낸 적이 없으면 빈 목록
  Future<List<String>> loadLastRecipients() async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    return prefs.getStringList(_lastRecipientsKey) ?? <String>[];
  }

  /// 작성: 2026-10-04 16:44:32 · 박건준
  /// 함수: saveLastRecipients
  /// 목적: 방금 메일을 보낸 수신자 목록을 저장한다. 이전 값은 덮어쓴다.
  /// 인자: recipients — 보낸 주소 목록
  Future<void> saveLastRecipients(List<String> recipients) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    await prefs.setStringList(_lastRecipientsKey, recipients);
  }

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 변수: _loginEmployeeIdKey
  /// 목적: 로그인한 작업자 사번의 저장 키. 앱을 다시 켤 때 로그인을 다시
  ///       받지 않으려고 둔다. 로그아웃하면 지운다.
  static const String _loginEmployeeIdKey = 'loginEmployeeId';

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: loadLoginEmployeeId
  /// 목적: 기기에 남은 로그인 사번을 읽는다.
  /// 반환: 사번. 로그인한 적이 없거나 로그아웃했으면 null
  Future<String?> loadLoginEmployeeId() async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    return prefs.getString(_loginEmployeeIdKey);
  }

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: saveLoginEmployeeId
  /// 목적: 로그인 사번을 저장하거나 지운다.
  /// 인자: employeeId — 저장할 사번. null 이면 지운다(로그아웃)
  Future<void> saveLoginEmployeeId(String? employeeId) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    if (employeeId == null) {
      await prefs.remove(_loginEmployeeIdKey);
    } else {
      await prefs.setString(_loginEmployeeIdKey, employeeId);
    }
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 변수: _updateSnoozeLatestKey
  /// 목적: 선택 업데이트 창에서 "나중에" 를 누른 최신 빌드 번호의 저장 키.
  static const String _updateSnoozeLatestKey = 'updateSnoozeLatest';

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 변수: _updateSnoozeAtKey
  /// 목적: "나중에" 를 누른 시각(1970-01-01 UTC 부터 밀리초)의 저장 키.
  static const String _updateSnoozeAtKey = 'updateSnoozeAtMs';

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: loadUpdateSnooze
  /// 목적: 선택 업데이트 창에서 마지막으로 "나중에" 를 누른 기록을 읽는다.
  ///       `UpdateChecker.check()` 가 같은 번호 창을 하루에 한 번만 띄우는
  ///       데 쓴다.
  /// 반환: (최신 빌드 번호, 누른 시각). 누른 적이 없거나 둘 중 하나가
  ///       없으면 null
  Future<(int, DateTime)?> loadUpdateSnooze() async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    final latest = prefs.getInt(_updateSnoozeLatestKey); // 미룬 최신 번호
    final atMs = prefs.getInt(_updateSnoozeAtKey); // 미룬 시각 (밀리초)
    if (latest == null || atMs == null) return null;
    return (latest, DateTime.fromMillisecondsSinceEpoch(atMs));
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: saveUpdateSnooze
  /// 목적: 선택 업데이트 창에서 "나중에" 를 누른 기록을 남긴다. 이전
  ///       기록은 덮어쓴다.
  /// 인자: latest — 그 창이 안내한 최신 빌드 번호
  ///       at — 누른 시각
  Future<void> saveUpdateSnooze(int latest, DateTime at) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    await prefs.setInt(_updateSnoozeLatestKey, latest);
    await prefs.setInt(_updateSnoozeAtKey, at.millisecondsSinceEpoch);
  }

  /// 작성: 2026-10-04 14:30:00 · 박건준
  /// 변수: _lastSiteKey
  /// 목적: 마지막 현장 정보의 저장 키. 값은 항목 표를 JSON 문자열로 바꿔
  ///       한 칸에 둔다.
  static const String _lastSiteKey = 'lastSite';

  /// 작성: 2026-08-19 10:35:27 · 박건준
  /// 수정: 2026-10-04 14:30:00 · 박건준
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
  /// 수정: 2026-10-04 14:30:00 · 박건준
  /// 함수: saveLastSite
  /// 목적: 가장 최근에 입력한 현장 정보를 다음 측정 · 다음 앱 실행 때
  ///       다시 채울 수 있도록 저장한다. 이전 값은 덮어쓴다.
  /// 인자: siteMap — 항목 이름을 열쇠로 하는 현장 정보 표
  Future<void> saveLastSite(Map<String, String?> siteMap) async {
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소 접근 객체
    await prefs.setString(_lastSiteKey, jsonEncode(siteMap));
  }
}
