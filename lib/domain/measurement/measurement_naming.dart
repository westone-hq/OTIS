import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/session/site_info.dart';

/// 작성: 2026-10-23 00:20:00 · 박건준
/// 수정: 2026-10-27 13:00:00 · 박건준
/// 클래스: MeasurementFile
/// 목적: 측정 한 건이 남기는 산출물 가운데 이름에 운전 방향 · 제번 · 측정
///       ID 를 붙이는 세 가지와, 그 이름의 종류 글자 · 확장자 · 예전 이름.
///       기기 측정 폴더 안 이름과 메일 첨부 이름이 같다(2026-10-27, 예전에는
///       폴더 안 `report.pdf` 를 메일에만 `TUNE_…` 으로 바꿔 붙였다).
///       - `report` — PDF 리포트
///       - `raw` — 로우 데이터(EVIMP1)
///       - `noise` — 현장 소음 녹음(M4A)
///       결과 파일 · 목록 캐시 · 진단 기록 · 안드로이드 원본은 앱만 읽어 이름이
///       고정이다(`MeasurementRepository`).
enum MeasurementFile {
  report('REPORT', 'pdf', 'report.pdf'),
  raw('RAW', 'txt', 'raw.txt'),
  noise('NOISE', 'm4a', 'noise.m4a');

  /// 작성: 2026-10-23 00:20:00 · 박건준
  /// 수정: 2026-10-27 13:00:00 · 박건준
  /// 함수: MeasurementFile
  /// 목적: 종류마다 이름 글자 · 확장자 · 예전 이름을 담는다.
  /// 인자: kind — 이름에 넣는 종류 글자
  ///       extension — 확장자 (점 없이)
  ///       legacyName — 2026-10-27 전 측정 폴더 안 이름. 그 전 측정을 읽을 때
  ///       찾는다
  const MeasurementFile(this.kind, this.extension, this.legacyName);

  /// 이름에 넣는 종류 글자 (`REPORT` · `RAW` · `NOISE`)
  final String kind;

  /// 확장자 (점 없이)
  final String extension;

  /// 2026-10-27 전 측정 폴더 안 이름 (`report.pdf` 등)
  final String legacyName;
}

/// 작성: 2026-10-27 13:00:00 · 박건준
/// 클래스: MeasurementNaming
/// 목적: 사람이 보는 측정 이름과 산출물 파일 이름을 만든다. 맨 앞에 운전
///       방향(상승 `up` · 하강 `dn`)을 붙여 같은 제번의 상승 · 하강을
///       가른다. 기기 저장 파일 · 메일 첨부 · 저장 결과 목록 · 결과 화면 ·
///       메일 제목이 이 한 곳을 쓴다.
/// 근거: 인용 — 2026-10-27 사용자 지시 "산출되는 파일명에 up, dn 을 맨 앞에
///       표기해서 상승 하강 구분(up_제번), Tune 문구는 삭제, 앱 내 저장에도
///       반영", "RAW NOISE 처럼 pdf 도 REPORT 로"
abstract final class MeasurementNaming {
  /// 작성: 2026-10-27 13:00:00 · 박건준
  /// 변수: upTag
  /// 목적: 상승 측정 표시.
  static const String upTag = 'up';

  /// 작성: 2026-10-27 13:00:00 · 박건준
  /// 변수: downTag
  /// 목적: 하강 측정 표시.
  static const String downTag = 'dn';

  /// 작성: 2026-10-27 13:00:00 · 박건준
  /// 함수: directionTag
  /// 목적: 운전 방향을 이름 앞 표시로 바꾼다. 예전 표기("상부 → 하부")도
  ///       하강으로 읽는다(`SiteInfo.isDownward()`).
  /// 인자: direction — 저장된 운전 방향
  /// 반환: `upTag` 또는 `downTag`
  static String directionTag(String direction) =>
      // → 로직 이동: SiteInfo.isDownward()
      SiteInfo.isDownward(direction) ? downTag : upTag;

  /// 작성: 2026-10-27 13:00:00 · 박건준
  /// 함수: title
  /// 목적: 사람이 보는 측정 이름을 만든다. 저장 결과 목록 · 결과 화면 머리 ·
  ///       비교 줄이 제번 대신 쓴다.
  /// 인자: result — 측정 결과
  /// 반환: "up_제번" 꼴 이름
  static String title(MeasurementResult result) =>
      // → 로직 이동: directionTag()
      '${directionTag(result.direction)}_${result.jobNo}';

  /// 작성: 2026-10-27 13:00:00 · 박건준
  /// 함수: fileName
  /// 목적: 산출물 파일 이름을 만든다. 측정 폴더 안 이름과 메일 첨부 이름이
  ///       같다 — 폴더 안 이름이 모든 측정에서 같으면 받는 쪽이 여러 현장
  ///       파일을 모아 두었을 때 가를 수 없다. 저장할 때는 결과를 만들기 전이라
  ///       결과 대신 세 값을 받는다. 제번 속 파일 이름에 쓸 수 없는 글자는
  ///       `_` 로 바꾼다.
  /// 인자: file — 산출물 종류
  ///       direction — 운전 방향
  ///       jobNo — 제번
  ///       id — 측정 ID
  /// 반환: "up_REPORT_제번_측정ID.pdf" 꼴 이름
  static String fileName(
    MeasurementFile file, {
    required String direction,
    required String jobNo,
    required String id,
  }) {
    final safeJobNo = jobNo.trim().replaceAll(
      RegExp(r'[^0-9A-Za-z가-힣_-]+'),
      '_',
    ); // 파일 이름에 쓸 수 있게 다듬은 제번
    // → 로직 이동: directionTag()
    return '${directionTag(direction)}_${file.kind}_${safeJobNo}_$id'
        '.${file.extension}';
  }

  /// 작성: 2026-10-27 13:00:00 · 박건준
  /// 함수: fileNameOf
  /// 목적: 저장된 측정 결과의 산출물 파일 이름을 만든다(`fileName()`).
  /// 인자: result — 측정 결과
  ///       file — 산출물 종류
  /// 반환: "up_REPORT_제번_측정ID.pdf" 꼴 이름
  static String fileNameOf(MeasurementResult result, MeasurementFile file) =>
      // → 로직 이동: fileName()
      fileName(
        file,
        direction: result.direction,
        jobNo: result.jobNo,
        id: result.id,
      );
}
