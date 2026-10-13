/// 작성: 2026-10-13 14:18:51 · nada
/// 클래스: UpdateConfig
/// 목적: 앱 안 업데이트 안내에 쓰는 주소 · 시간 값을 이 파일에서만
///       정한다. 배포 서버는 GitHub Releases 다(구글 플레이를 쓰지 않는다).
///       절차는 docs/release.md 의 "배포" 를 본다.
class UpdateConfig {
  /// 작성: 2026-10-13 14:18:51 · nada
  /// 함수: UpdateConfig._
  /// 목적: 상수만 두는 클래스라 객체를 만들지 못하게 막는다.
  UpdateConfig._();

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 변수: releaseRepository
  /// 목적: 배포 전용 공개 저장소("주인/이름"). 소스는 올리지 않고 릴리스
  ///       자산(APK · version.json)만 둔다.
  /// 근거: 미정 — 배포 저장소 주인(westone / OTIS)이 정해지지 않았다
  ///       (docs/pending_checks.md). 정해지면 이 값 하나만 바꾼다. 지금
  ///       값으로는 version.json 을 받지 못해 안내가 뜨지 않는다
  static const String releaseRepository = 'westone-hq/otis-vcheck-release';

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 변수: versionJsonUrl
  /// 목적: 앱이 읽는 버전 안내 파일 주소. GitHub 가 `latest` 를 가장 최근
  ///       릴리스로 넘겨 주므로 릴리스마다 주소를 바꾸지 않는다.
  /// 근거: 표준 — GitHub 문서 "Linking to releases" 의
  ///       `/releases/latest/download/<자산 이름>` 주소 규칙
  static const String versionJsonUrl =
      'https://github.com/$releaseRepository/releases/latest/download/'
      'version.json';

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 변수: checkTimeout
  /// 목적: version.json 을 기다리는 한도. 넘으면 확인을 그만두고 앱을
  ///       그대로 쓴다 — 기계실처럼 인터넷이 약한 곳에서 측정을 막지
  ///       않는다.
  /// 근거: 인용 — 2026-10-13 개선 지시 ③ "한도 3초"
  static const Duration checkTimeout = Duration(seconds: 3);

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 변수: snoozeDuration
  /// 목적: 선택 업데이트 창에서 "나중에" 를 누른 뒤, 같은 최신 번호로는
  ///       창을 다시 띄우지 않는 기간. 필수 업데이트에는 쓰지 않는다.
  /// 근거: 인용 — 2026-10-13 개선 지시 ③ "하루에 한 번만"
  static const Duration snoozeDuration = Duration(days: 1);
}
