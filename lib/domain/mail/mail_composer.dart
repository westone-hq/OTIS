import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/time/korea_time.dart';

/// 작성: 2026-10-23 00:20:00 · 박건준
/// 클래스: MailItem
/// 목적: 메일에 붙일 수 있는 자료의 종류와, 첨부 이름에 쓰는 머리말 ·
///       확장자. 안드로이드 원본(`native_raw.txt`, 2026-10-08 결정)과 소음
///       진단 산출물(2026-10-15 결정)은 보내지 않아 종류에 없다.
///       - `report` — PDF 리포트
///       - `raw` — 로우 데이터(`raw.txt`)
///       - `noise` — 현장 소음 녹음(`noise.m4a`)
enum MailItem {
  report('TUNE', 'pdf'),
  raw('RAW', 'txt'),
  noise('NOISE', 'm4a');

  /// 작성: 2026-10-23 00:20:00 · 박건준
  /// 함수: MailItem
  /// 목적: 종류마다 첨부 이름 머리말과 확장자를 담는다.
  /// 인자: prefix — 첨부 이름 머리말
  ///       extension — 확장자 (점 없이)
  const MailItem(this.prefix, this.extension);

  /// 첨부 이름 머리말 (`TUNE` · `RAW` · `NOISE`)
  final String prefix;

  /// 첨부 이름 확장자 (점 없이)
  final String extension;
}

/// 작성: 2026-10-23 00:20:00 · 박건준
/// 클래스: MailComposer
/// 목적: 리포트 메일의 제목 · 본문 · 첨부 이름을 만든다. 파일을 찾거나
///       복사하지 않는 순수 계산이라, 문구를 화면 없이 시험할 수 있다.
///       파일을 모아 메일 앱에 넘기는 일은 `MailService` 가 한다.
abstract final class MailComposer {
  /// 작성: 2026-10-05 10:03:35 · 박건준
  /// 수정: 2026-10-23 00:20:00 · 박건준
  /// 함수: attachmentName
  /// 목적: 메일에 붙일 파일 이름을 정한다. 측정 폴더 안 이름(`report.pdf`
  ///       등)은 모든 측정이 같아, 받는 쪽에서 여러 현장 메일을 모아 두면
  ///       구분할 수 없다. 제번 속 파일 이름에 쓸 수 없는 글자는 `_` 로
  ///       바꾼다.
  /// 인자: result — 첨부할 측정 결과
  ///       item — 자료 종류(머리말 · 확장자)
  /// 반환: "머리말_제번_측정ID.확장자" 꼴 이름
  static String attachmentName(MeasurementResult result, MailItem item) {
    final safeJobNo = result.jobNo.trim().replaceAll(
      RegExp(r'[^0-9A-Za-z가-힣_-]+'),
      '_',
    ); // 파일 이름에 쓸 수 있게 다듬은 제번
    return '${item.prefix}_${safeJobNo}_${result.id}.${item.extension}';
  }

  /// 작성: 2026-10-23 00:20:00 · 박건준
  /// 함수: attachmentLine
  /// 목적: 본문 첨부 목록에 적을 한 줄을 만든다.
  /// 인자: name — 첨부 이름 (`attachmentName()`)
  ///       item — 자료 종류
  /// 반환: "- 이름: 설명" 꼴 한 줄
  static String attachmentLine(String name, MailItem item) {
    final description = switch (item) {
      MailItem.report => '앱 측정 결과(가공값)',
      MailItem.raw => '256Hz 원시값(EVIMP1, 축별 평균 제거 · 필터 없음)',
      MailItem.noise => '측정 중 현장 소음 녹음(AAC)',
    }; // 자료 설명
    return '- $name: $description';
  }

  /// 작성: 2026-10-23 00:20:00 · 박건준
  /// 함수: missingLine
  /// 목적: 보내기로 했는데 없는 자료를 본문 끝에 밝히는 한 줄을 만든다.
  ///       빠진 채로 조용히 나가면 받는 쪽이 한참 뒤에야 안다.
  /// 인자: item — 자료 종류
  ///       fileName — 측정 폴더 안 파일 이름 (`report.pdf` 등)
  /// 반환: "누락: 파일 이름 — 사유" 꼴 한 줄
  static String missingLine(MailItem item, String fileName) {
    final reason = switch (item) {
      MailItem.report => '리포트를 만들지 못했습니다',
      MailItem.raw => '이 측정에는 로우 데이터 파일이 없습니다',
      MailItem.noise => '이 측정에는 현장 소음 녹음이 없습니다',
    }; // 없는 사유
    return '누락: $fileName — $reason';
  }

  /// 작성: 2026-10-23 00:20:00 · 박건준
  /// 함수: subject
  /// 목적: 메일 제목을 만든다. 날짜는 한국 시각이다.
  /// 인자: result — 보낼 측정 결과
  /// 반환: "TUNE Summary Report - 제번 - yyyy-MM-dd HH:mm"
  static String subject(MeasurementResult result) {
    // → 로직 이동: KoreaTime.minuteLabel()
    final dateStr = KoreaTime.minuteLabel(result.dateTime); // 메일 제목 날짜
    return 'TUNE Summary Report - ${result.jobNo} - $dateStr';
  }

  /// 작성: 2026-10-18 09:41:12 · 박건준
  /// 수정: 2026-10-23 00:20:00 · 박건준
  /// 함수: workerLine
  /// 목적: 메일 본문에 적을 작업자 줄을 만든다. 성명 뒤 괄호에 사번,
  ///       그 뒤에 업체명 · 관리팀을 가운뎃점으로 잇는다. 결과에 없는
  ///       값(로그인 전 결과의 사번, OTIS 직원의 업체)은 그 자리째 뺀다.
  ///       지금 로그인한 사람이 아니라 결과에 실린 사람이다 — 다른 사람이
  ///       예전 결과를 보내도 측정한 사람이 남는다.
  /// 인자: result — 보낼 측정 결과
  /// 반환: 예 "작업자: 홍길동 (T00001) · (주)시험승강기 · 설치1팀". 성명이
  ///       없으면(설정에 이름을 적지 않던 예전 결과) null
  static String? workerLine(MeasurementResult result) {
    final name = result.engineerName; // 성명, 없으면 null
    if (name == null) return null;
    final id = result.employeeId; // 사번, 없으면 null
    final parts = <String>[
      id == null ? name : '$name ($id)',
      ?result.company,
      ?result.team,
    ]; // 가운뎃점으로 이을 조각
    return '작업자: ${parts.join(' · ')}';
  }

  /// 작성: 2026-10-23 00:20:00 · 박건준
  /// 수정: 2026-10-27 12:00:00 · 박건준
  /// 함수: body
  /// 목적: 메일 본문을 만든다. 차례는 다음과 같다. 거치 · 미보정 기종 줄은
  ///       2026-10-27 사용자 지시("메일 본문에는 경고 띄우는 거 다 없애")로
  ///       뺐다.
  ///       1. 첫 줄 "OTIS 승강기 진동 측정 리포트입니다."
  ///       2. 작업자 줄(`workerLine()`) — 성명이 없으면 뺀다
  ///       3. 추가 참고사항이 있으면 "[참고사항]" 머리줄과 함께 적은
  ///          그대로. 참고사항은 리포트에 칸이 없어 메일 본문으로만 전한다
  ///       4. 첨부 목록, 첨부 개수
  ///       5. 없는 자료가 있으면 "누락:" 줄
  /// 인자: result — 보낼 측정 결과
  ///       attachmentLines — 첨부 목록 줄 (`attachmentLine()`)
  ///       attachmentCount — 실제로 붙인 파일 수
  ///       missing — 누락 줄 (`missingLine()`)
  /// 반환: 줄바꿈으로 이은 본문
  static String body({
    required MeasurementResult result,
    required List<String> attachmentLines,
    required int attachmentCount,
    required List<String> missing,
  }) {
    final notes = result.notes; // 추가 참고사항, 없으면 null
    final bodyLines = <String>[
      'OTIS 승강기 진동 측정 리포트입니다.',
      ?workerLine(result), // → 로직 이동: workerLine()
      if (notes != null) ...['', '[참고사항]', notes, ''],
      ...attachmentLines,
      '',
      '※ 첨부 $attachmentCount개',
      if (missing.isNotEmpty) ...['', ...missing],
    ]; // 메일 본문 줄 목록
    return bodyLines.join('\n');
  }
}
