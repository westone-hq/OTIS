import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/raw_excel_export.dart';
import 'package:vibration_checker/domain/measure/sensor_sample.dart';

void main() {
  List<SensorSample> makeSamples(int n) {
    return List<SensorSample>.generate(n, (i) {
      return SensorSample(
        tsUs: i * 3906,
        x: i.toDouble(),
        y: 0,
        z: 0,
        noiseDba: 0,
        rawX: 10,
        rawY: 11,
        rawZ: 1000,
        gravityX: 9,
        gravityY: 10,
        gravityZ: 990,
      );
    });
  }

  test('256Hz 엑셀 — 초당 256행', () {
    final samples = makeSamples(300);
    final bytes = buildRawBySecondExcelBytes(
      samples,
      sampleRateHz: 256,
      exportRateHz: 256,
    );
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.containsKey('1초'), isTrue);
    expect(book.tables.containsKey('2초'), isTrue);
    final sheet1 = book['1초']!;
    expect(
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value,
      IntCellValue(256),
    );
    expect(
      rawBySecondExcelFileName(samples, exportRateHz: 256),
      'EVIMP1_전체1초_초별분리_센서값_256.xlsx',
    );
  });

  test('128Hz·64Hz 엑셀 — 초당 128/64행 (간헐 추출)', () {
    final samples = makeSamples(256);
    final bytes128 = buildRawBySecondExcelBytes(
      samples,
      sampleRateHz: 256,
      exportRateHz: 128,
    );
    final book128 = Excel.decodeBytes(bytes128);
    expect(
      book128['1초']!
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1))
          .value,
      IntCellValue(128),
    );

    final bytes64 = buildRawBySecondExcelBytes(
      samples,
      sampleRateHz: 256,
      exportRateHz: 64,
    );
    final book64 = Excel.decodeBytes(bytes64);
    expect(
      book64['1초']!
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1))
          .value,
      IntCellValue(64),
    );

    expect(
      rawBySecondExcelFileName(samples, exportRateHz: 128),
      'EVIMP1_전체1초_초별분리_센서값_128.xlsx',
    );
    expect(
      rawBySecondExcelFileName(samples, exportRateHz: 64),
      'EVIMP1_전체1초_초별분리_센서값_64.xlsx',
    );
  });
}
