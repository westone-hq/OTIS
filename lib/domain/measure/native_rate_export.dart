import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'dense_interpolated_export.dart';
import 'sensor_sample.dart';

/// 수집 주기 비교 요약 파일명
const String kCollectionRateSummaryFileName = 'collection_rate_summary.txt';

/// 1~3ms 요청 원본을 초별로 모은 엑셀 (256개 제한 없음)
const String kNativeBySecondExcelFileName = 'native_by_second_원본_제한없음.xlsx';

/// raw_native 기준 초당 수집 개수 요약 + 256Hz 리샘플 비교 텍스트
String buildCollectionRateSummaryText({
  required String nativeText,
  required List<SensorSample> resampledSamples,
  double resampleRateHz = 256.0,
}) {
  final events = parseRawNativeText(nativeText);
  final buf = StringBuffer();
  buf.writeln('[OTIS collection_rate_summary.txt]');
  buf.writeln('목적: 1초에 실제로 몇 개를 모았는지 비교 (256개로 자르지 않은 원본 vs 분석용 리샘플)');
  buf.writeln('');
  buf.writeln('A) 센서 원본 (raw_native.txt)');
  buf.writeln('   - 요청: samplingPeriodUs=3000 (1~3ms 힌트)');
  buf.writeln('   - 256개 제한 없음. 기기/OS가 준 콜백을 그대로 셈');
  buf.writeln('B) 분석용 리샘플 (raw.txt / EVIMP1 초별 엑셀 256)');
  buf.writeln('   - 기존 파이프라인: 불규칙 원본(과거 FASTEST≈3~7ms)을 1/256초 격자로 보간');
  final rateLabel = resampleRateHz.round();
  buf.writeln('   - 초당 항상 $rateLabel개로 맞춤 (거리·속도·진동 계산용)');
  buf.writeln('');

  if (events.isEmpty) {
    buf.writeln('원본 이벤트 없음.');
    return buf.toString();
  }

  final t0 = events.first.tsUs;
  final bySec = <int, _SecCounts>{};
  for (final e in events) {
    final sec = ((e.tsUs - t0) / 1000000.0).floor();
    final c = bySec.putIfAbsent(sec, _SecCounts.new);
    if (e.type == 'raw') {
      c.accel++;
    } else if (e.type == 'gravity') {
      c.gravity++;
    } else if (e.type == 'linear') {
      c.linear++;
    }
  }

  final rate = resampleRateHz > 0 ? resampleRateHz.round() : 256;
  final resampleSeconds = resampledSamples.isEmpty
      ? 0
      : ((resampledSamples.length + rate - 1) ~/ rate);

  buf.writeln('--- 초별 개수 ---');
  buf.writeln(
    '초\tnative_raw\tnative_gravity\tnative_linear\tnative_총합'
    '\tnative_대략Hz(raw)\tresampled_256개',
  );

  final maxSec = [
    if (bySec.isNotEmpty) bySec.keys.reduce((a, b) => a > b ? a : b),
    if (resampleSeconds > 0) resampleSeconds - 1,
  ].reduce((a, b) => a > b ? a : b);

  var sumAccel = 0;
  for (int sec = 0; sec <= maxSec; sec++) {
    final c = bySec[sec] ?? _SecCounts();
    sumAccel += c.accel;
    final resampleCount = _resampleCountInSecond(
      resampledSamples.length,
      rate,
      sec,
    );
    buf.writeln(
      '${sec + 1}\t${c.accel}\t${c.gravity}\t${c.linear}\t${c.total}'
      '\t${c.accel}\t$resampleCount',
    );
  }

  final nativeSecCount = bySec.length;
  final avgAccel =
      nativeSecCount > 0 ? (sumAccel / nativeSecCount).toStringAsFixed(1) : '0';
  buf.writeln('');
  buf.writeln('요약');
  buf.writeln('- 원본 raw 평균(초당): $avgAccel 개  ← 256 제한 없음');
  buf.writeln('- 분석용 리샘플: 매 초 $rate개 고정');
  buf.writeln('- 원본 총 이벤트: ${events.length} (raw+gravity+linear)');
  buf.writeln('- 리샘플 총 샘플: ${resampledSamples.length}');
  return buf.toString();
}

/// raw_native 이벤트를 초별 시트로 나눈 xlsx (개수 제한 없음)
Uint8List buildNativeBySecondExcelBytes(String nativeText) {
  final events = parseRawNativeText(nativeText);
  final excel = Excel.createExcel();

  if (events.isEmpty) {
    final sheet = excel['요약'];
    _setText(sheet, 0, 0, '원본 이벤트 없음');
    if (excel.tables.containsKey('Sheet1')) excel.delete('Sheet1');
    return Uint8List.fromList(excel.encode() ?? []);
  }

  final t0 = events.first.tsUs;
  final bySec = <int, List<NativeSensorEvent>>{};
  for (final e in events) {
    final sec = ((e.tsUs - t0) / 1000000.0).floor();
    bySec.putIfAbsent(sec, () => <NativeSensorEvent>[]).add(e);
  }

  final summary = excel['요약'];
  _setText(summary, 0, 0, '센서 원본 초별 수집 (256개 제한 없음)');
  _setText(summary, 1, 0, '요청 samplingPeriodUs=3000 (1~3ms 힌트)');
  _setText(summary, 2, 0, '분석용 256Hz 리샘플과 별개 · 실제 콜백 전부');
  _setText(summary, 4, 0, '초');
  _setText(summary, 4, 1, 'raw');
  _setText(summary, 4, 2, 'gravity');
  _setText(summary, 4, 3, 'linear');
  _setText(summary, 4, 4, '총합');
  _setText(summary, 4, 5, 'raw≈Hz');

  final secs = bySec.keys.toList()..sort();
  for (int i = 0; i < secs.length; i++) {
    final sec = secs[i];
    final list = bySec[sec]!;
    final rawN = list.where((e) => e.type == 'raw').length;
    final gravity = list.where((e) => e.type == 'gravity').length;
    final linear = list.where((e) => e.type == 'linear').length;
    _setInt(summary, 5 + i, 0, sec + 1);
    _setInt(summary, 5 + i, 1, rawN);
    _setInt(summary, 5 + i, 2, gravity);
    _setInt(summary, 5 + i, 3, linear);
    _setInt(summary, 5 + i, 4, list.length);
    _setInt(summary, 5 + i, 5, rawN);
  }

  for (final sec in secs) {
    final list = bySec[sec]!;
    final rawN = list.where((e) => e.type == 'raw').length;
    final sheet = excel['${sec + 1}초'];
    _setText(sheet, 0, 0, '원본 센서 이벤트 — ${sec + 1}초 구간 (제한 없음)');
    _setText(sheet, 1, 0, 'raw 개수');
    _setInt(sheet, 1, 1, rawN);
    _setText(sheet, 1, 2, '총 이벤트');
    _setInt(sheet, 1, 3, list.length);
    _setText(sheet, 1, 4, '※ 256으로 자르지 않음');
    _setText(sheet, 2, 0, '요청');
    _setText(sheet, 2, 1, 'samplingPeriodUs=3000 (1~3ms)');

    const headers = [
      '순번',
      'type',
      'tsUs',
      'x_mg',
      'y_mg',
      'z_mg',
      'dtUs(같은type)',
    ];
    for (int c = 0; c < headers.length; c++) {
      _setText(sheet, 4, c, headers[c]);
    }

    final lastTs = <String, int>{};
    for (int i = 0; i < list.length; i++) {
      final e = list[i];
      final prev = lastTs[e.type];
      final dt = (prev != null && e.tsUs > prev) ? e.tsUs - prev : 0;
      lastTs[e.type] = e.tsUs;
      final row = 5 + i;
      _setInt(sheet, row, 0, i + 1);
      _setText(sheet, row, 1, e.type);
      _setInt(sheet, row, 2, e.tsUs);
      _setNum(sheet, row, 3, e.xMg);
      _setNum(sheet, row, 4, e.yMg);
      _setNum(sheet, row, 5, e.zMg);
      _setInt(sheet, row, 6, dt);
    }
  }

  if (excel.tables.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }
  return Uint8List.fromList(excel.encode() ?? []);
}

int _resampleCountInSecond(int totalSamples, int rate, int secIndex) {
  final start = secIndex * rate;
  if (start >= totalSamples) return 0;
  final end = (start + rate).clamp(0, totalSamples);
  return end - start;
}

class _SecCounts {
  int accel = 0;
  int gravity = 0;
  int linear = 0;
  int get total => accel + gravity + linear;
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
