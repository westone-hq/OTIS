import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

void main() {
  group('NativeEvent 왕복', () {
    test('기록 후 판독하면 모든 값이 보존된다', () {
      const original = NativeEvent(
        type: NativeEventType.linear,
        tsUs: 123456789,
        xMg: -1.5,
        yMg: 0.25,
        zMg: 1001.75,
        dtUs: 3921,
      );
      final restored = NativeEvent.fromRecordLine(original.toRecordLine());
      expect(restored, isNotNull);
      expect(restored!.type, original.type);
      expect(restored.tsUs, original.tsUs);
      expect(restored.xMg, original.xMg);
      expect(restored.yMg, original.yMg);
      expect(restored.zMg, original.zMg);
      expect(restored.dtUs, original.dtUs);
    });

    test('encode 후 decode 하면 개수와 순서가 보존된다', () {
      const events = [
        NativeEvent(
          type: NativeEventType.accel,
          tsUs: 100,
          xMg: 1.0,
          yMg: 2.0,
          zMg: 3.0,
          dtUs: 0,
        ),
        NativeEvent(
          type: NativeEventType.gravity,
          tsUs: 103,
          xMg: 0.0,
          yMg: 0.0,
          zMg: 1000.0,
          dtUs: 0,
        ),
        NativeEvent(
          type: NativeEventType.linear,
          tsUs: 105,
          xMg: -0.5,
          yMg: 0.5,
          zMg: 1.5,
          dtUs: 0,
        ),
      ];
      final text = NativeEventRecord.encode(events, targetSampleRateHz: 256);
      final result = NativeEventRecord.decode(text);
      expect(result.skippedLineCount, 0);
      expect(result.events.length, 3);
      expect(result.events[0].type, NativeEventType.accel);
      expect(result.events[1].type, NativeEventType.gravity);
      expect(result.events[2].type, NativeEventType.linear);
      expect(result.events[2].tsUs, 105);
    });
  });

  group('NativeEventRecord.decode 방어', () {
    test('주석과 빈 줄은 폐기 집계에 넣지 않는다', () {
      const text = '# 주석\n\nlinear 100 1.0 2.0 3.0 0\n# 또 주석\n';
      final result = NativeEventRecord.decode(text);
      expect(result.events.length, 1);
      expect(result.skippedLineCount, 0);
    });

    test('형식 불일치 줄은 폐기하고 집계하며 0값으로 채우지 않는다', () {
      const text =
          'linear 100 1.0 2.0 3.0 0\n'
          '깨진 줄\n'
          'linear abc 1.0 2.0 3.0 0\n'
          'linear 200 1.0 2.0 3.0 0\n';
      final result = NativeEventRecord.decode(text);
      expect(result.events.length, 2);
      expect(result.skippedLineCount, 2);
      expect(result.events[0].tsUs, 100);
      expect(result.events[1].tsUs, 200);
    });

    test('develop 브랜치 실제 머리말 형식을 판독할 수 있다', () {
      const text =
          '# OTIS raw_native.txt · 보간 전 센서 이벤트 (samplingPeriodUs=3000)\n'
          '# 256Hz 리샘플 이전의 실제 콜백. 요청은 1~3ms이며 실제 간격은 기기/OS에 따라 불규칙할 수 있음.\n'
          '# columns: type tsUs x_mg y_mg z_mg dtUs\n'
          '# type: accel | gravity | linear\n'
          'accel 1000 -0.929 0.919 -1.267 0\n'
          'accel 4921 -0.155 0.342 0.036 3921\n';
      final result = NativeEventRecord.decode(text);
      expect(result.events.length, 2);
      expect(result.skippedLineCount, 0);
      expect(result.events[1].dtUs, 3921);
    });
  });
}
