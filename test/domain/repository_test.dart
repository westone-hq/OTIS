import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/native_readable_export.dart';
import 'package:vibration_checker/domain/measure/sensor_sample.dart';
import 'package:vibration_checker/domain/models/measurement_result.dart';
import 'package:vibration_checker/domain/repository/measurement_repository.dart';

void main() {
  group('P13 · MeasurementRepository', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('otis_test_repo_');
      MeasurementRepository.instance.overrideBaseDir = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('save() - raw.txt + 3to7/1to3 초별 + pdf', () async {
      final native3 = File('${tempDir.path}/n3.txt');
      final native1 = File('${tempDir.path}/n1.txt');
      await native3.writeAsString(
        'raw 0 1 0 0 0\nraw 5000 2 0 0 5000\n',
      );
      await native1.writeAsString(
        'raw 0 1 0 0 0\nraw 2000 2 0 0 2000\nraw 4000 3 0 0 2000\n',
      );

      final mockResult = MeasurementResult.mock.copyWith(
        id: 'SAVE_DUAL_NATIVE',
        rawSamples: [
          const SensorSample(tsUs: 0, x: 1.0, y: 2.0, z: 3.0, noiseDba: 40.0),
          const SensorSample(tsUs: 3906, x: 1.5, y: 2.5, z: 3.5, noiseDba: 41.0),
        ],
      );

      final dir = await MeasurementRepository.instance.save(
        mockResult,
        nativeRawPaths: {
          'native3to7': native3.path,
          'native1to3': native1.path,
        },
      );

      expect(await File('${dir.path}/raw.txt').exists(), isTrue);
      expect(await File('${dir.path}/$kRaw3to7BySecondFileName').exists(), isTrue);
      expect(await File('${dir.path}/$kRaw1to3BySecondFileName').exists(), isTrue);
      expect(await File('${dir.path}/report.pdf').exists(), isTrue);
      expect(await File('${dir.path}/meta.json').exists(), isTrue);

      final t3 = await File('${dir.path}/$kRaw3to7BySecondFileName').readAsString();
      final t1 = await File('${dir.path}/$kRaw1to3BySecondFileName').readAsString();
      expect(t3, contains('3~7ms'));
      expect(t1, contains('1~3ms'));
      expect(t3, contains('======== 1초'));
      expect(t1, contains('======== 1초'));
    });
  });
}
