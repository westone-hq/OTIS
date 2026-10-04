import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

/// 작성: 2026-08-06 14:47:52 · 박건준
/// 수정: 2026-10-04 14:30:00 · nada
/// 함수: main
/// 목적: 안드로이드가 채널로 보낸 표를 `NativeEvent` 로 바꿀 때 값이
///       보존되고, 형식이 맞지 않는 표는 0 으로 채우지 않고 버리는지
///       시험한다.
void main() {
  group('NativeEvent.fromChannelMap', () {
    test('정상 Map 을 판독하고 noiseDba 를 담는다', () {
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
      expect(event.noiseDba, 45.2);
    });

    test('noiseDba 가 없어도 필수 키만 있으면 판독한다', () {
      final event = NativeEvent.fromChannelMap({
        'type': 'accel',
        'tsUs': 1,
        'xMg': 0,
        'yMg': 0,
        'zMg': 0,
        'dtUs': 0,
      });
      expect(event, isNotNull);
      expect(event!.noiseDba, isNull);
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
