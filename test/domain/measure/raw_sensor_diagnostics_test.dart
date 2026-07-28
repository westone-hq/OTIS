import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measure/raw_sensor_diagnostics.dart';
import 'package:vibration_checker/domain/measure/sensor_sample.dart';

void main() {
  group('RawSensorDiagnostics', () {
    test('확장 raw 샘플에서 채널 통계 및 미리보기 추출', () {
      const samples = [
        SensorSample(
          tsUs: 1000,
          x: 1.0,
          y: 2.0,
          z: 3.0,
          noiseDba: 50.0,
          rawX: 10.0,
          rawY: 20.0,
          rawZ: 1010.0,
          gravityX: 9.0,
          gravityY: 19.0,
          gravityZ: 1000.0,
        ),
        SensorSample(
          tsUs: 4906,
          x: -1.0,
          y: 4.0,
          z: 5.0,
          noiseDba: 55.0,
          rawX: 8.0,
          rawY: 22.0,
          rawZ: 1005.0,
          gravityX: 9.5,
          gravityY: 18.0,
          gravityZ: 999.0,
        ),
      ];

      final diag = RawSensorDiagnostics.fromSamples(samples, sampleRateHz: 256);
      expect(diag.hasExtendedRaw, isTrue);
      expect(diag.sampleCount, 2);
      expect(diag.linearX.peakToPeak, 2.0);
      expect(diag.rawZ.min, 1005.0);
      expect(diag.motionZ.available, isTrue);

      final preview = selectRawPreviewSamples(samples, edgeCount: 1);
      expect(preview.length, 2);
      expect(
        formatRawSampleLine(preview.first, extended: true),
        contains('1000'),
      );
    });
  });
}
