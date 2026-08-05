import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'axis_integration_export.dart';
import 'sensor_sample.dart';

/// 메일/저장용 초별 엑셀 export rate (초당 샘플 수)
const List<int> kRawExcelExportRatesHz = [256, 128, 64];

/// EVIMP1 raw 샘플을 1초 단위 시트로 나눈 xlsx 바이트 생성
///
/// [sampleRateHz]: 원본 수집 주파수(보통 256)
/// [exportRateHz]: 시트에 넣을 초당 샘플 수(256 / 128 / 64)
/// - 128·64는 원본 256Hz에서 균등 간헐 추출 (2샘플마다 1개 / 4샘플마다 1개)
///
/// 시트: `1초` … `N초` + `열 설명`
Uint8List buildRawBySecondExcelBytes(
  List<SensorSample> samples, {
  double sampleRateHz = 256.0,
  int exportRateHz = 256,
}) {
  final sourceRate = sampleRateHz > 0 ? sampleRateHz.round() : 256;
  final exportRate = _normalizeExportRate(exportRateHz, sourceRate);
  final step = sourceRate ~/ exportRate;
  final integrationRows = AxisIntegrationExport.compute(samples);
  final excel = Excel.createExcel();

  final total = samples.length;
  final secondCount = total == 0 ? 0 : ((total + sourceRate - 1) ~/ sourceRate);

  for (int sec = 0; sec < secondCount; sec++) {
    final start = sec * sourceRate;
    final end = (start + sourceRate).clamp(0, total);
    final indices = <int>[];
    for (int i = start; i < end; i += step) {
      indices.add(i);
    }
    final count = indices.length;
    final sheetName = '${sec + 1}초';
    final sheet = excel[sheetName];

    _setText(
      sheet,
      0,
      0,
      '분석용 리샘플 — ${sec + 1}초 구간 (${exportRate}Hz, 초당 $exportRate개 고정)',
    );
    _setText(sheet, 1, 0, '구간');
    _setText(sheet, 1, 1, '${sec + 1}초');
    _setText(sheet, 1, 2, '원본 순번');
    _setText(
      sheet,
      1,
      3,
      indices.isEmpty ? '-' : '${indices.first + 1}~${indices.last + 1}',
    );
    _setText(sheet, 1, 4, '샘플 수');
    _setInt(sheet, 1, 5, count);

    _setText(sheet, 2, 0, '출력');
    _setText(sheet, 2, 1, '${exportRate}Hz');
    _setText(sheet, 2, 2, '리샘플격자');
    _setText(sheet, 2, 3, '${sourceRate}Hz');
    _setText(sheet, 2, 4, '추출');
    _setText(
      sheet,
      2,
      5,
      step == 1
          ? '보간본(기존≈3~7ms 원본→256격자)'
          : '$step샘플마다 1개',
    );

    const headers = <String>[
      '번호',
      'tsUs',
      'linearX (mg)',
      'linearY (mg)',
      'linearZ (mg)',
      'noiseDba (dBA)',
      'rawX (mg)',
      'rawY (mg)',
      'rawZ (mg)',
      'gravityX (mg)',
      'gravityY (mg)',
      'gravityZ (mg)',
      'motionX (mg)',
      'motionY (mg)',
      'motionZ (mg)',
      'velocityX (m/s)',
      'velocityY (m/s)',
      'velocityZ (m/s)',
      'distanceX (m)',
      'distanceY (m)',
      'distanceZ (m)',
    ];
    for (int c = 0; c < headers.length; c++) {
      _setText(sheet, 4, c, headers[c]);
    }

    for (int r = 0; r < indices.length; r++) {
      final i = indices[r];
      final row = 5 + r;
      final s = samples[i];
      final integ = i < integrationRows.length
          ? integrationRows[i]
          : AxisIntegrationRow.zero;

      _setInt(sheet, row, 0, i + 1);
      _setInt(sheet, row, 1, s.tsUs);
      _setNum(sheet, row, 2, s.x);
      _setNum(sheet, row, 3, s.y);
      _setNum(sheet, row, 4, s.z);
      _setNum(sheet, row, 5, s.noiseDba);
      _setNullableNum(sheet, row, 6, s.rawX);
      _setNullableNum(sheet, row, 7, s.rawY);
      _setNullableNum(sheet, row, 8, s.rawZ);
      _setNullableNum(sheet, row, 9, s.gravityX);
      _setNullableNum(sheet, row, 10, s.gravityY);
      _setNullableNum(sheet, row, 11, s.gravityZ);
      _setNum(sheet, row, 12, integ.motionX);
      _setNum(sheet, row, 13, integ.motionY);
      _setNum(sheet, row, 14, integ.motionZ);
      _setNum(sheet, row, 15, integ.velocityX);
      _setNum(sheet, row, 16, integ.velocityY);
      _setNum(sheet, row, 17, integ.velocityZ);
      _setNum(sheet, row, 18, integ.distanceX);
      _setNum(sheet, row, 19, integ.distanceY);
      _setNum(sheet, row, 20, integ.distanceZ);
    }
  }

  _writeColumnGuideSheet(
    excel,
    totalSamples: total,
    sourceRateHz: sourceRate,
    exportRateHz: exportRate,
    step: step,
  );

  if (excel.tables.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }

  final encoded = excel.encode();
  if (encoded == null) {
    return Uint8List(0);
  }
  return Uint8List.fromList(encoded);
}

/// 측정 폴더에 저장할 xlsx 파일명 (exportRateHz별)
String rawBySecondExcelFileName(
  List<SensorSample> samples, {
  double sampleRateHz = 256.0,
  int exportRateHz = 256,
}) {
  final sourceRate = sampleRateHz > 0 ? sampleRateHz.round() : 256;
  final exportRate = _normalizeExportRate(exportRateHz, sourceRate);
  final fullSeconds = samples.isEmpty ? 0 : samples.length ~/ sourceRate;
  final label = fullSeconds > 0 ? fullSeconds : (samples.isEmpty ? 0 : 1);
  return 'EVIMP1_전체$label초_초별분리_센서값_$exportRate.xlsx';
}

bool isRawBySecondExcelPath(String path) {
  final name = path.replaceAll('\\', '/').split('/').last;
  return name.startsWith('EVIMP1_') &&
      name.contains('_초별분리_센서값') &&
      name.endsWith('.xlsx');
}

int _normalizeExportRate(int exportRateHz, int sourceRate) {
  if (exportRateHz <= 0) return sourceRate;
  if (sourceRate % exportRateHz != 0) return sourceRate;
  return exportRateHz;
}

void _writeColumnGuideSheet(
  Excel excel, {
  required int totalSamples,
  required int sourceRateHz,
  required int exportRateHz,
  required int step,
}) {
  final sheet = excel['열 설명'];
  _setText(sheet, 0, 0, 'raw.txt 열 설명');
  _setText(
    sheet,
    1,
    0,
    '이 파일: ${exportRateHz}Hz (원본 ${sourceRateHz}Hz'
    '${step == 1 ? ', 전 샘플' : ', $step샘플마다 1개'})',
  );
  _setText(sheet, 3, 0, '구분');
  _setText(sheet, 3, 1, '원본 열');
  _setText(sheet, 3, 2, '단위');
  _setText(sheet, 3, 3, '설명');

  final totalLabel = totalSamples.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  final rows = <List<String>>[
    ['번호', '-', '-', '원본 ${sourceRateHz}Hz 전체 $totalLabel개 샘플 기준 순번'],
    ['시간', 'tsUs', 'μs', '각 센서 샘플의 타임스탬프'],
    ['선형가속도', 'linearX/Y/Z', 'mg', '진동 분석에 사용하는 X/Y/Z 가속도'],
    ['소음', 'noiseDba', 'dBA', '각 시점의 소음 측정값'],
    ['원시가속도', 'rawX/Y/Z', 'mg', '중력이 포함된 원시 가속도'],
    ['중력', 'gravityX/Y/Z', 'mg', '센서가 추정한 중력 성분'],
    ['이동가속도', 'motionX/Y/Z', 'mg', 'raw - gravity로 만든 이동 가속도'],
    ['축별 속도', 'velocityX/Y/Z', 'm/s', 'motion을 1차 적분한 누적 속도'],
    ['축별 거리', 'distanceX/Y/Z', 'm', 'velocity를 다시 적분한 누적 거리'],
  ];

  for (int i = 0; i < rows.length; i++) {
    for (int c = 0; c < rows[i].length; c++) {
      _setText(sheet, 4 + i, c, rows[i][c]);
    }
  }
}

void _setText(Sheet sheet, int row, int col, String value) {
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value = TextCellValue(value);
}

void _setInt(Sheet sheet, int row, int col, int value) {
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value = IntCellValue(value);
}

void _setNum(Sheet sheet, int row, int col, double value) {
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value = DoubleCellValue(value);
}

void _setNullableNum(Sheet sheet, int row, int col, double? value) {
  if (value == null) {
    _setText(sheet, row, col, 'null');
  } else {
    _setNum(sheet, row, col, value);
  }
}
