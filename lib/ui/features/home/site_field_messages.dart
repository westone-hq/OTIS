import 'package:vibration_checker/domain/session/site_info.dart';

/// 작성: 2026-10-22 23:10:00 · 박건준
/// 함수: jobNoErrorMessage
/// 목적: 제번 검사에 걸렸으면 안내 문구를 돌려준다.
/// 인자: errors — `SiteInfo.validate()` 가 돌려준 목록
/// 반환: 제번 오류 문구. 문제가 없으면 null
String? jobNoErrorMessage(List<SiteFieldError> errors) =>
    errors.contains(SiteFieldError.jobNoMissing) ? '제번을 입력하세요' : null;

/// 작성: 2026-10-22 23:10:00 · 박건준
/// 함수: siteNameErrorMessage
/// 목적: 현장명 검사에 걸렸으면 안내 문구를 돌려준다.
/// 인자: errors — `SiteInfo.validate()` 가 돌려준 목록
/// 반환: 현장명 오류 문구. 문제가 없으면 null
String? siteNameErrorMessage(List<SiteFieldError> errors) =>
    errors.contains(SiteFieldError.siteNameMissing) ? '현장명을 입력하세요' : null;

/// 작성: 2026-10-04 13:35:26 · 박건준
/// 수정: 2026-10-27 11:00:00 · 박건준
/// 함수: floorErrorMessage
/// 목적: 층수 검사에 걸린 항목을 안내 문구로 바꾼다. 층수 오류는 한 번에
///       하나만 나온다.
/// 인자: errors — `SiteInfo.validate()` 가 돌려준 목록
/// 반환: 층수 오류 문구. 층수에 문제가 없으면 null
String? floorErrorMessage(List<SiteFieldError> errors) {
  if (errors.contains(SiteFieldError.floorMissing)) {
    return '최하층과 최상층을 모두 입력하세요';
  }
  if (errors.contains(SiteFieldError.floorNotNumber)) {
    return '층수는 1 이상 숫자로, 지하층은 ${SiteInfo.basementPrefix}1 처럼 '
        '입력하세요';
  }
  if (errors.contains(SiteFieldError.floorNotAscending)) {
    return '최상층이 최하층보다 커야 합니다';
  }
  return null;
}

/// 작성: 2026-10-11 17:28:28 · 박건준
/// 수정: 2026-10-22 23:10:00 · 박건준
/// 함수: loadErrorMessage
/// 목적: 하중 검사에 걸린 항목을 안내 문구로 바꾼다. 하중 오류는 한 번에
///       하나만 나온다.
/// 인자: errors — `SiteInfo.validate()` 가 돌려준 목록
/// 반환: 하중 오류 문구. 하중에 문제가 없으면 null
String? loadErrorMessage(List<SiteFieldError> errors) {
  if (errors.contains(SiteFieldError.loadMissing)) return '하중을 입력하세요';
  if (errors.contains(SiteFieldError.loadNotNumber)) {
    return '하중은 0 보다 큰 숫자로 입력하세요';
  }
  return null;
}
