import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/dense_interpolated_export.dart';

void main() {
  test('raw_native → dense CSV header marks visualization only', () {
    const native = '''
# OTIS raw_native.txt
accel 0 10 0 0 0
accel 4000 20 0 0 4000
gravity 0 0 0 1000 0
gravity 4000 0 0 1000 4000
linear 0 1 0 0 0
linear 4000 2 0 0 4000
''';
    final files = buildAllDenseInterpolatedCsv(native);
    expect(files.keys, containsAll(kDenseInterpolatedSpecs.keys));

    final csv512 = files['dense_interpolated_512.csv']!;
    expect(csv512, contains('INTERPOLATED'));
    expect(csv512, contains('VISUALIZATION ONLY'));
    expect(csv512, contains('NOT MEASURED SAMPLE'));
    expect(csv512, contains('target_rate_hz: 512'));

    final csv50 = files['dense_interpolated_50x.csv']!;
    expect(csv50, contains('target_rate_hz: 12800'));

    final csv100 = files['dense_interpolated_100x.csv']!;
    expect(csv100, contains('target_rate_hz: 25600'));

    // 0~0.004s @ 512Hz → 약 3점 이상
    final dataLines = csv512
        .split('\n')
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .skip(1)
        .toList();
    expect(dataLines.length, greaterThanOrEqualTo(3));
  });

  test('선형 보간 중간값', () {
    final events = parseRawNativeText('''
accel 0 10 0 0 0
accel 4000 20 0 0 4000
''');
    final csv = buildDenseInterpolatedCsv(
      events,
      targetHz: 500,
      fileLabel: 'test.csv',
    );
    // t=0.002s → x=15
    expect(csv, contains('0.002,15,'));
  });
}
