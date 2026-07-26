import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/axis_integration_export.dart';
import 'package:vibration_checker/domain/measure/sensor_sample.dart';

void main() {
  group('AxisIntegrationExport', () {
    test('첫 샘플 velocity/distance=0, motion=raw-gravity', () {
      const samples = [
        SensorSample(
          tsUs: 0,
          x: 0,
          y: 0,
          z: 0,
          noiseDba: 50,
          rawX: 10,
          rawY: 20,
          rawZ: 1010,
          gravityX: 8,
          gravityY: 18,
          gravityZ: 1000,
        ),
      ];

      final rows = AxisIntegrationExport.compute(samples);
      expect(rows.length, 1);
      expect(rows[0].motionX, 2);
      expect(rows[0].motionY, 2);
      expect(rows[0].motionZ, 10);
      expect(rows[0].velocityX, 0);
      expect(rows[0].distanceZ, 0);
    });

    test('사다리꼴 적분으로 velocity/distance 누적', () {
      const samples = [
        SensorSample(
          tsUs: 0,
          x: 0,
          y: 0,
          z: 0,
          noiseDba: 50,
          rawZ: 1000,
          gravityZ: 1000,
        ),
        SensorSample(
          tsUs: 1000000 ~/ 256,
          x: 0,
          y: 0,
          z: 0,
          noiseDba: 50,
          rawZ: 1100,
          gravityZ: 1000,
        ),
      ];

      final rows = AxisIntegrationExport.compute(samples);
      expect(rows[1].motionZ, 100);
      expect(rows[1].velocityZ, greaterThan(0));
      expect(rows[1].distanceZ, greaterThanOrEqualTo(0));
    });

    test('dt<=0 이면 velocity/distance 이전 값 유지', () {
      const samples = [
        SensorSample(
          tsUs: 1000,
          x: 1,
          y: 0,
          z: 0,
          noiseDba: 0,
          rawZ: 1100,
          gravityZ: 1000,
        ),
        SensorSample(
          tsUs: 1000,
          x: 1,
          y: 0,
          z: 0,
          noiseDba: 0,
          rawZ: 1200,
          gravityZ: 1000,
        ),
      ];

      final rows = AxisIntegrationExport.compute(samples);
      expect(rows[1].velocityZ, rows[0].velocityZ);
      expect(rows[1].distanceZ, rows[0].distanceZ);
    });
  });
}
