import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/raw_readable_export.dart';
import 'package:vibration_checker/domain/measure/sensor_sample.dart';

void main() {
  group('RawReadableExport', () {
    test('256Hz 샘플 간격 ≈ 0.003906초', () {
      expect(
        RawReadableExport.samplePeriodSec(256),
        closeTo(1 / 256, 0.000001),
      );
    });
  });

  group('ReadableSensorIntegrator', () {
    test('첫 샘플 적분값·적분적분값 = 0', () {
      const samples = [
        SensorSample(
          tsUs: 0,
          x: 1,
          y: 2,
          z: 3,
          noiseDba: 0,
          rawX: 10,
          rawY: 20,
          rawZ: 1000,
          gravityX: 8,
          gravityY: 18,
          gravityZ: 990,
        ),
      ];
      final rows = ReadableSensorIntegrator.compute(samples);
      expect(rows[0].rawX, 10);
      expect(rows[0].motionX, 2);
      expect(rows[0].rawIntegral1X, 0);
      expect(rows[0].motionIntegral2Z, 0);
    });
  });

  group('writeRawReadableText', () {
    test('전체 샘플 출력 · 원초+중력보정 · 블록 수 = 샘플 수', () {
      final samples = List<SensorSample>.generate(256, (i) {
        return SensorSample(
          tsUs: i * (1000000 ~/ 256),
          x: -1.69,
          y: 1.28,
          z: -6.75,
          noiseDba: 50,
          rawX: -2.68,
          rawY: 19.03,
          rawZ: 993.32,
          gravityX: 0,
          gravityY: 0,
          gravityZ: 990,
        );
      });

      final text = writeRawReadableText(samples, sampleRateHz: 256);

      expect(text, contains('출력: 전체 샘플 (다운샘플 없음'));
      expect(text, contains('출력된 블록 수: 256'));
      expect(text, contains('(#1/256)'));
      expect(text, contains('(#256/256)'));

      expect(text, contains('[X축 · 원초]'));
      expect(text, contains('기초 센서값     : -2.68 mg'));
      expect(text, contains('[X축 · 중력보정]'));
      expect(text, contains('중력보정값      : -2.68 mg'));

      expect(text, contains('[Z축 · 중력보정]'));
      expect(text, contains('중력보정값      : 3.32 mg'));
    });

    test('빈 샘플은 0건 메타만 출력', () {
      final text = writeRawReadableText([]);
      expect(text, contains('원본 샘플 수: 0'));
      expect(text, contains('출력된 블록 수: 0'));
      expect(text, isNot(contains('시간 :')));
    });
  });
}
