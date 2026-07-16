import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/sensor_sample.dart';
import 'package:vibration_checker/domain/models/measurement_result.dart';
import 'package:vibration_checker/domain/repository/measurement_repository.dart';

void main() {
  group('P13 · MeasurementRepository 유닛 테스트 (Phase 4-A)', () {
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

    test('save() - raw.txt, meta.json, report.pdf 3개 파일 정상 생성 및 저장 검증', () async {
      final mockResult = MeasurementResult.mock.copyWith(
        id: '2024F1447R01_20260704_120000',
        rawSamples: [
          const SensorSample(tsUs: 0, x: 1.0, y: 2.0, z: 3.0, noiseDba: 40.0),
          const SensorSample(tsUs: 3906, x: 1.5, y: 2.5, z: 3.5, noiseDba: 41.0),
        ],
      );

      final dir = await MeasurementRepository.instance.save(mockResult);
      expect(await dir.exists(), isTrue);

      final metaFile = File('${dir.path}/meta.json');
      final rawFile = File('${dir.path}/raw.txt');
      final pdfFile = File('${dir.path}/report.pdf');

      expect(await metaFile.exists(), isTrue);
      expect(await rawFile.exists(), isTrue);
      expect(await pdfFile.exists(), isTrue);

      final rawContent = await rawFile.readAsString();
      expect(rawContent, contains('EVIMP1'));
      expect(rawContent, contains('256'));
      expect(
        rawContent,
        contains(
          '# columns: tsUs linearX linearY linearZ noiseDba rawX rawY rawZ gravityX gravityY gravityZ',
        ),
      );
      expect(rawContent, contains('0 1 2 3 40'));
      expect(rawContent, contains('3906 1.5 2.5 3.5 41'));
    });

    test('list() - 여러 측정 결과 저장 시 최신 일시 순(내림차순)으로 정렬하여 반환 검증', () async {
      final res1 = MeasurementResult.mock.copyWith(
        id: 'JOB1_20260704_100000',
        dateTime: DateTime(2026, 7, 4, 10, 0),
      );
      final res2 = MeasurementResult.mock.copyWith(
        id: 'JOB2_20260704_120000',
        dateTime: DateTime(2026, 7, 4, 12, 0),
      );

      await MeasurementRepository.instance.save(res1);
      await MeasurementRepository.instance.save(res2);

      final list = await MeasurementRepository.instance.list();
      expect(list.length, 2);
      expect(list[0].id, 'JOB2_20260704_120000'); // 더 최신 결과가 먼저
      expect(list[1].id, 'JOB1_20260704_100000');
    });

    test('load() - 저장된 meta.json과 raw.txt를 합성하여 완벽한 MeasurementResult 복원 검증', () async {
      final original = MeasurementResult.mock.copyWith(
        id: 'LOAD_TEST_ID',
        jobNo: '2024F 9999R99',
        siteName: '테스트 빌딩',
        rawSamples: [
          const SensorSample(tsUs: 0, x: 5.0, y: 6.0, z: 7.0, noiseDba: 55.0),
        ],
      );

      await MeasurementRepository.instance.save(original);
      final loaded = await MeasurementRepository.instance.load('LOAD_TEST_ID');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'LOAD_TEST_ID');
      expect(loaded.jobNo, '2024F 9999R99');
      expect(loaded.siteName, '테스트 빌딩');
      expect(loaded.rawSamples, isNotNull);
      expect(loaded.rawSamples!.length, 1);
      expect(loaded.rawSamples![0].noiseDba, 55.0);
    });

    test('delete() - 저장된 폴더 및 파일 전체 정상 삭제 검증', () async {
      final target = MeasurementResult.mock.copyWith(id: 'DELETE_TEST_ID');
      final dir = await MeasurementRepository.instance.save(target);
      expect(await dir.exists(), isTrue);

      final deleted = await MeasurementRepository.instance.delete('DELETE_TEST_ID');
      expect(deleted, isTrue);
      expect(await dir.exists(), isFalse);
    });
  });
}
