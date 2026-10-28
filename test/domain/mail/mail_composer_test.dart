import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/mail/mail_composer.dart';
import 'package:vibration_checker/domain/measurement/measurement_naming.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';

/// 작성: 2026-10-23 00:30:00 · 박건준
/// 함수: _result
/// 목적: 메일 문구에 넘길 측정 결과. 시계열은 비우고 머리 값만 채운다.
/// 반환: 시험용 측정 결과 (2026-01-14 11:03:59 한국 시각)
MeasurementResult _result() {
  return MeasurementResult(
    id: '20260114-110359',
    jobNo: 'J-1',
    siteName: '현장',
    bottomFloor: 1,
    topFloor: 8,
    direction: '상승',
    dateTime: DateTime.utc(2026, 1, 14, 2, 3, 59),
    xSeries: const <double>[],
    ySeries: const <double>[],
    zSeries: const <double>[],
    noiseSeries: const <double>[],
    positionSeries: const <double>[],
    speedSeries: const <double>[],
    accelSeries: const <double>[],
    jerkSeries: const <double>[],
  );
}

/// 작성: 2026-10-23 00:30:00 · 박건준
/// 수정: 2026-10-27 13:00:00 · 박건준
/// 함수: main
/// 목적: 메일 제목 · 본문 · 첨부 이름(`MailComposer`)을 글자 하나까지 본다.
///       이름 · 제목은 2026-10-27 방향 표시(up · dn) 규칙이다. 파일을 모으는 경로는
///       `send_email_sheet_test` 가 본다.
void main() {
  test('첨부 이름은 방향 · 종류 · 제번 · 측정 ID 이고 못 쓰는 글자는 _ 로 바꾼다', () {
    final item = _result().copyWith(jobNo: '2024F 1447/R01'); // 공백 · 빗금 제번
    expect(
      MailComposer.attachmentName(item, MeasurementFile.report),
      'up_REPORT_2024F_1447_R01_20260114-110359.pdf',
    );
    expect(
      MailComposer.attachmentName(_result(), MeasurementFile.raw),
      'up_RAW_J-1_20260114-110359.txt',
    );
    final down = _result().copyWith(direction: '하강'); // 하강 측정
    expect(
      MailComposer.attachmentName(down, MeasurementFile.noise),
      'dn_NOISE_J-1_20260114-110359.m4a',
    );
    expect(
      MailComposer.attachmentName(
        _result().copyWith(direction: '상부 → 하부'),
        MeasurementFile.report,
      ),
      startsWith('dn_'),
      reason: '예전 하강 표기',
    );
  });

  test('제목은 TUNE Summary Report-방향-제번 이고 날짜가 없다', () {
    expect(MailComposer.subject(_result()), 'TUNE Summary Report-up-J-1');
    expect(
      MailComposer.subject(_result().copyWith(direction: '하강')),
      'TUNE Summary Report-dn-J-1',
    );
  });

  test('첨부 · 누락 줄 문구', () {
    expect(
      MailComposer.attachmentLine('RAW_J-1_x.txt', MeasurementFile.raw),
      '- RAW_J-1_x.txt: 256Hz 원시값(EVIMP1, 축별 평균 제거 · 필터 없음)',
    );
    expect(
      MailComposer.attachmentLine('T.pdf', MeasurementFile.report),
      '- T.pdf: 앱 측정 결과(가공값)',
    );
    expect(
      MailComposer.attachmentLine('N.m4a', MeasurementFile.noise),
      '- N.m4a: 측정 중 현장 소음 녹음(AAC)',
    );
    expect(
      MailComposer.missingLine(MeasurementFile.report, 'up_REPORT_J-1_x.pdf'),
      '누락: up_REPORT_J-1_x.pdf — 리포트를 만들지 못했습니다',
    );
    expect(
      MailComposer.missingLine(MeasurementFile.raw, 'raw.txt'),
      '누락: raw.txt — 이 측정에는 로우 데이터 파일이 없습니다',
    );
    expect(
      MailComposer.missingLine(MeasurementFile.noise, 'noise.m4a'),
      '누락: noise.m4a — 이 측정에는 현장 소음 녹음이 없습니다',
    );
  });

  test('작업자 줄은 없는 값을 빼고, 성명이 없으면 줄째 뺀다', () {
    expect(MailComposer.workerLine(_result()), isNull);
    expect(
      MailComposer.workerLine(
        _result().copyWith(
          engineerName: '김철수',
          employeeId: '200001',
          company: '(주)시험승강기',
          team: '설치1팀',
        ),
      ),
      '작업자: 김철수 (200001) · (주)시험승강기 · 설치1팀',
    );
    expect(
      MailComposer.workerLine(
        _result().copyWith(engineerName: '김철수', employeeId: '200001'),
      ),
      '작업자: 김철수 (200001)',
    );
  });

  test('본문 차례: 첫 줄 → 작업자 → 참고사항 → 첨부 → 누락, 경고 줄은 없다', () {
    final result = _result().copyWith(
      engineerName: '김철수',
      employeeId: '200001',
      placement: 'faceDown',
      deviceManufacturer: 'samsung',
      deviceModel: 'SM-A536N',
      deviceCompensation: 'none',
      notes: '도어 소음 있음',
    ); // 모든 줄이 걸리고 거치 · 미보정도 실은 결과
    expect(
      MailComposer.body(
        result: result,
        attachmentLines: const <String>['- T.pdf: 앱 측정 결과(가공값)'],
        attachmentCount: 1,
        missing: const <String>['누락: raw.txt — 이 측정에는 로우 데이터 파일이 없습니다'],
      ),
      'OTIS 승강기 진동 측정 리포트입니다.\n'
      '작업자: 김철수 (200001)\n'
      '\n'
      '[참고사항]\n'
      '도어 소음 있음\n'
      '\n'
      '- T.pdf: 앱 측정 결과(가공값)\n'
      '\n'
      '※ 첨부 1개\n'
      '\n'
      '누락: raw.txt — 이 측정에는 로우 데이터 파일이 없습니다',
    );
  });

  test('예전 결과 본문은 작업자 · 참고사항 · 누락 줄이 없다', () {
    expect(
      MailComposer.body(
        result: _result(),
        attachmentLines: const <String>[],
        attachmentCount: 0,
        missing: const <String>[],
      ),
      'OTIS 승강기 진동 측정 리포트입니다.\n\n※ 첨부 0개',
    );
  });
}
