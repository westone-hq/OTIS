import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 접근을 단일 지점으로 캡슐화하는 저장소
/// - 현장 정보, 이메일, 자동 로그인 등 영구 저장되는 모든 키와 접근 로직을 관리
/// - 기존 키 문자열 및 저장 포맷 불변 유지
class PrefsStore {
  static final PrefsStore instance = PrefsStore._();
  PrefsStore._();

  /// 자동 로그인 사번 저장 키
  static const String kAutoLoginId = 'auto_login_id';

  /// 마지막 입력 현장 정보 저장 키
  static const String kPrefJobNo = 'pref_jobNo';
  static const String kPrefSiteName = 'pref_siteName';
  static const String kPrefBottomFloor = 'pref_bottomFloor';
  static const String kPrefTopFloor = 'pref_topFloor';
  static const String kPrefDirection = 'pref_direction';
  static const String kPrefModel = 'pref_model';

  /// 센서 부착 안내 시트 확인 여부 (Phase 7 예정)
  static const String kHasSeenPlacementSheet = 'has_seen_placement_sheet';

  /// 사용자별 이메일 저장 키 생성 (`email_{id}`)
  static String getEmailKey(String id) => 'email_$id';

  // --- 1. 자동 로그인 관리 ---

  /// 저장된 자동 로그인 ID 조회
  Future<String?> loadAutoLoginId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kAutoLoginId);
  }

  /// 자동 로그인 ID 저장
  Future<void> saveAutoLoginId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAutoLoginId, id);
  }

  /// 자동 로그인 ID 삭제 (로그아웃 시)
  Future<void> removeAutoLoginId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kAutoLoginId);
  }

  // --- 2. 이메일 관리 ---

  /// 사용자 ID별 저장된 이메일 조회
  Future<String?> loadEmail(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(getEmailKey(id));
  }

  /// 사용자 ID별 이메일 저장
  Future<void> saveEmail(String id, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(getEmailKey(id), email);
  }

  // --- 3. 현장 정보(Last Site Info) 관리 ---

  /// 마지막으로 입력한 현장 정보 조회
  Future<Map<String, String?>> loadLastSite() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'jobNo': prefs.getString(kPrefJobNo),
      'siteName': prefs.getString(kPrefSiteName),
      'bottomFloor': prefs.getString(kPrefBottomFloor),
      'topFloor': prefs.getString(kPrefTopFloor),
      'direction': prefs.getString(kPrefDirection),
      'model': prefs.getString(kPrefModel),
    };
  }

  /// 현장 정보 저장
  Future<void> saveLastSite(Map<String, String?> siteMap) async {
    final prefs = await SharedPreferences.getInstance();
    final jobNo = siteMap['jobNo'];
    final siteName = siteMap['siteName'];
    final bottomFloor = siteMap['bottomFloor'];
    final topFloor = siteMap['topFloor'];
    final direction = siteMap['direction'];
    final model = siteMap['model'];

    if (jobNo != null) await prefs.setString(kPrefJobNo, jobNo);
    if (siteName != null) await prefs.setString(kPrefSiteName, siteName);
    if (bottomFloor != null) await prefs.setString(kPrefBottomFloor, bottomFloor);
    if (topFloor != null) await prefs.setString(kPrefTopFloor, topFloor);
    if (direction != null) await prefs.setString(kPrefDirection, direction);
    if (model != null) await prefs.setString(kPrefModel, model);
  }

  // --- 4. 센서 부착 안내 시트 확인 여부 (Phase 7 예정) ---

  Future<bool> loadHasSeenPlacementSheet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kHasSeenPlacementSheet) ?? false;
  }

  Future<void> saveHasSeenPlacementSheet(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasSeenPlacementSheet, seen);
  }
}
