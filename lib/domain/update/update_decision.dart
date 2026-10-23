import 'package:vibration_checker/domain/update/update_info.dart';

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: UpdateDecision
/// 목적: 지금 설치된 빌드와 배포 서버의 버전 정보를 견주어 업데이트
///       안내를 어떻게 띄울지 고른다.
///       - `none` — 안내하지 않는다(최신이거나 확인하지 못함)
///       - `optional` — 새 버전이 있다. "나중에" 를 고를 수 있다
///       - `required` — 이 빌드는 더 쓸 수 없다. 업데이트해야 쓴다
enum UpdateDecision {
  none,
  optional,
  required;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: decide
  /// 목적: 내 빌드 번호와 버전 정보로 안내 종류를 고른다. `minimum` 보다
  ///       낮으면 `required`, 그렇지 않고 `latest` 보다 낮으면 `optional`.
  ///       서버보다 높은 빌드(개발 중 빌드)는 `none` 이다.
  /// 인자: currentBuild — 설치된 앱의 빌드 번호
  ///       info — 배포 서버의 버전 정보
  /// 반환: 안내 종류
  static UpdateDecision decide(int currentBuild, UpdateInfo info) {
    if (currentBuild < info.minimum) return UpdateDecision.required;
    if (currentBuild < info.latest) return UpdateDecision.optional;
    return UpdateDecision.none;
  }
}
