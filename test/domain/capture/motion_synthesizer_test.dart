/// 목적: 가속도 센서와 중력 센서의 데이터가 들어왔을 때, 가속도에서 중력을 빼서 순수한 진동(Motion) 값을 정확히 계산해 내는지 검증한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/motion_synthesizer.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

NativeEvent _event(
  NativeEventType type,
  int tsUs, {
  double x = 0,
  double y = 0,
  double z = 0,
}) {
  return NativeEvent(type: type, tsUs: tsUs, xMg: x, yMg: y, zMg: z, dtUs: 0);
}

void main() {
  group('MotionSynthesizer', () {
    test('motion = raw − gravity 를 축별로 정확히 계산한다', () {
      final synth = MotionSynthesizer();
      synth.onEvent(
        _event(NativeEventType.gravity, 100, x: 10, y: -20, z: 1000),
        noiseDba: 0,
      );
      final sample = synth.onEvent(
        _event(NativeEventType.accel, 105, x: 12.5, y: -18, z: 1003.25),
        noiseDba: 45.5,
      );
      expect(sample, isNotNull);
      expect(sample!.tsUs, 105);
      expect(sample.x, 2.5);
      expect(sample.y, 2.0);
      expect(sample.z, 3.25);
      expect(sample.rawX, 12.5);
      expect(sample.gravityZ, 1000);
      expect(sample.noiseDba, 45.5);
    });

    test('gravity 확보 전 raw 는 폐기하고 집계한다', () {
      final synth = MotionSynthesizer();
      final sample = synth.onEvent(
        _event(NativeEventType.accel, 100),
        noiseDba: 0,
      );
      expect(sample, isNull);
      expect(synth.droppedNoGravityCount, 1);
    });

    test('gravity 는 새 값이 올 때까지 유지된다 (영점 유지)', () {
      final synth = MotionSynthesizer();
      synth.onEvent(
        _event(NativeEventType.gravity, 100, z: 1000),
        noiseDba: 0,
      );
      final first = synth.onEvent(
        _event(NativeEventType.accel, 105, z: 1001),
        noiseDba: 0,
      );
      final second = synth.onEvent(
        _event(NativeEventType.accel, 110, z: 1002),
        noiseDba: 0,
      );
      expect(first!.z, 1);
      expect(second!.z, 2);
      synth.onEvent(
        _event(NativeEventType.gravity, 112, z: 1001),
        noiseDba: 0,
      );
      final third = synth.onEvent(
        _event(NativeEventType.accel, 115, z: 1002),
        noiseDba: 0,
      );
      expect(third!.z, 1);
    });

    test('linear 이벤트는 무시하고 상태에도 영향을 주지 않는다', () {
      final synth = MotionSynthesizer();
      synth.onEvent(
        _event(NativeEventType.gravity, 100, z: 1000),
        noiseDba: 0,
      );
      final linear = synth.onEvent(
        _event(NativeEventType.linear, 102, z: 999),
        noiseDba: 0,
      );
      expect(linear, isNull);
      final sample = synth.onEvent(
        _event(NativeEventType.accel, 105, z: 1001),
        noiseDba: 0,
      );
      expect(sample!.z, 1);
      expect(synth.droppedNoGravityCount, 0);
    });

    test('reset 후에는 gravity 를 다시 확보해야 한다', () {
      final synth = MotionSynthesizer();
      synth.onEvent(
        _event(NativeEventType.gravity, 100, z: 1000),
        noiseDba: 0,
      );
      synth.reset();
      final sample = synth.onEvent(
        _event(NativeEventType.accel, 105, z: 1001),
        noiseDba: 0,
      );
      expect(sample, isNull);
      expect(synth.droppedNoGravityCount, 1);
    });
  });

  group('NativeEvent.fromChannelMap', () {
    test('정상 Map 을 판독하고 여분 키는 무시한다', () {
      final event = NativeEvent.fromChannelMap({
        'type': 'accel',
        'tsUs': 12345,
        'xMg': 1.5,
        'yMg': -2,
        'zMg': 1000.25,
        'dtUs': 3900,
        'noiseDba': 45.2,
      });
      expect(event, isNotNull);
      expect(event!.type, NativeEventType.accel);
      expect(event.tsUs, 12345);
      expect(event.yMg, -2.0);
      expect(event.dtUs, 3900);
    });

    test('필수 키 누락·형식 불일치는 null (0값 대체 금지)', () {
      expect(NativeEvent.fromChannelMap({'type': 'accel'}), isNull);
      expect(
        NativeEvent.fromChannelMap({
          'type': 'unknown',
          'tsUs': 1,
          'xMg': 0,
          'yMg': 0,
          'zMg': 0,
          'dtUs': 0,
        }),
        isNull,
      );
      expect(
        NativeEvent.fromChannelMap({
          'type': 'accel',
          'tsUs': '문자열',
          'xMg': 0,
          'yMg': 0,
          'zMg': 0,
          'dtUs': 0,
        }),
        isNull,
      );
    });
  });
}
