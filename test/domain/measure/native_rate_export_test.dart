import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/native_rate_export.dart';
import 'package:vibration_checker/domain/measure/sensor_sample.dart';

void main() {
  test('원본 초당 개수 요약 — 256 제한 없이 셈 + 리샘플 256과 비교', () {
    const native = '''
accel 0 1 0 0 0
accel 1000 1 0 0 1000
accel 2000 1 0 0 1000
accel 1000000 1 0 0 998000
gravity 0 0 0 1000 0
linear 0 0 0 0 0
''';
    final resampled = List<SensorSample>.generate(
      512,
      (i) => SensorSample(tsUs: i * 3906, x: 0, y: 0, z: 0, noiseDba: 0),
    );
    final text = buildCollectionRateSummaryText(
      nativeText: native,
      resampledSamples: resampled,
    );
    expect(text, contains('256개 제한 없음'));
    expect(text, contains('resampled_256개'));
    expect(text, contains('원본 raw 평균'));
    // 1초 구간에 raw 3개
    expect(text, contains('1\t3\t'));
  });

  test('native_by_second 엑셀 — 초당 256 초과 허용', () {
    final buf = StringBuffer();
    for (int i = 0; i < 300; i++) {
      buf.writeln('raw ${i * 3000} 1 0 0 ${i == 0 ? 0 : 3000}');
    }
    final bytes = buildNativeBySecondExcelBytes(buf.toString());
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.containsKey('요약'), isTrue);
    expect(book.tables.containsKey('1초'), isTrue);
    final sheet = book['1초']!;
    // raw 개수 셀 (1,1) — 300개 근처 (1초 안)
    final countCell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1));
    expect(countCell.value, isA<IntCellValue>());
    final n = (countCell.value as IntCellValue).value;
    expect(n, greaterThan(256));
  });
}
