import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measurement/measurement_naming.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';

/// 작성: 2026-10-27 13:00:00 · 박건준
/// 함수: _result
/// 목적: 이름 규칙에 넘길 측정 결과. 시계열은 비운다.
/// 인자: direction — 운전 방향
/// 반환: 시험용 측정 결과
MeasurementResult _result(String direction) => MeasurementResult(
  id: '20261027-130000',
  jobNo: '2025F 1234R01',
  siteName: '현장',
  bottomFloor: 1,
  topFloor: 8,
  direction: direction,
  dateTime: DateTime(2026, 10, 27, 13),
  xSeries: const <double>[],
  ySeries: const <double>[],
  zSeries: const <double>[],
  noiseSeries: const <double>[],
  positionSeries: const <double>[],
  speedSeries: const <double>[],
  accelSeries: const <double>[],
  jerkSeries: const <double>[],
);

/// 작성: 2026-10-27 13:00:00 · 박건준
/// 함수: main
/// 목적: 측정 이름 · 산출물 파일 이름(`MeasurementNaming`)이 2026-10-27 사용자
///       지시 형식(up · dn 맨 앞, 종류 REPORT · RAW · NOISE)인지 본다.
void main() {
  test('사람이 보는 이름은 방향_제번 이다', () {
    expect(MeasurementNaming.title(_result('상승')), 'up_2025F 1234R01');
    expect(MeasurementNaming.title(_result('하강')), 'dn_2025F 1234R01');
    expect(
      MeasurementNaming.title(_result('상부 → 하부')),
      'dn_2025F 1234R01',
      reason: '예전 하강 표기',
    );
  });

  test('파일 이름은 방향_종류_제번_측정ID 이고 제번의 공백은 _ 다', () {
    expect(
      MeasurementNaming.fileNameOf(_result('하강'), MeasurementFile.report),
      'dn_REPORT_2025F_1234R01_20261027-130000.pdf',
    );
    expect(
      MeasurementNaming.fileName(
        MeasurementFile.raw,
        direction: '상승',
        jobNo: ' J/1 ',
        id: 'id',
      ),
      'up_RAW_J_1_id.txt',
    );
    expect(
      MeasurementNaming.fileNameOf(_result('상승'), MeasurementFile.noise),
      endsWith('.m4a'),
    );
  });

  test('예전 이름은 2026-10-27 전 측정 폴더의 고정 이름이다', () {
    expect(MeasurementFile.values.map((f) => f.legacyName), <String>[
      'report.pdf',
      'raw.txt',
      'noise.m4a',
    ]);
  });
}
