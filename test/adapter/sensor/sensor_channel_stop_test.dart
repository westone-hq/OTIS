import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/sensor/sensor_channel.dart';

/// 작성: 2026-10-22 12:00:00 · nada
/// 수정: 2026-10-22 23:30:00 · nada
/// 변수: _channel
/// 목적: 안드로이드 `SensorMethodHandler.METHOD_CHANNEL` 과 같은 통로 이름.
const MethodChannel _channel = MethodChannel(
  'com.otis.vibration_checker/sensors_method',
);

/// 작성: 2026-10-22 12:00:00 · nada
/// 함수: main
/// 목적: 수집 정지 응답(`stopCapture`)에서 원본 · 녹음 경로와 소음 마이크
///       표본 속도(2026-10-22)를 읽는지, 응답이 없으면 모두 비우는지 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = // 시험용 통로
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('정지 응답의 두 경로와 소음 표본 속도를 담는다', () async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'stopCapture') {
        return <String, Object?>{
          'recordPath': '/r.txt',
          'audioPath': '/n.m4a',
          'noiseSampleRate': 48000,
          'deviceManufacturer': 'samsung',
          'deviceModel': 'SM-S901N',
        };
      }
      return null;
    });
    final manager = SensorChannelManager(); // 시험할 통로
    await manager.stopCapture();
    expect(manager.lastRecordPath, '/r.txt');
    expect(manager.lastAudioPath, '/n.m4a');
    expect(manager.lastNoiseSampleRateHz, 48000);
    expect(manager.lastDeviceManufacturer, 'samsung');
    expect(manager.lastDeviceModel, 'SM-S901N');
  });

  test('마이크를 못 열었으면 표본 속도가 null 이다', () async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      return <String, Object?>{
        'recordPath': '/r.txt',
        'audioPath': null,
        'noiseSampleRate': null,
      };
    });
    final manager = SensorChannelManager(); // 시험할 통로
    await manager.stopCapture();
    expect(manager.lastAudioPath, isNull);
    expect(manager.lastNoiseSampleRateHz, isNull);
  });

  test('정지 요청이 실패하면 모두 비운다', () async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      throw PlatformException(code: 'x');
    });
    final manager = SensorChannelManager()
      ..lastNoiseSampleRateHz = 44100
      ..lastDeviceModel = 'SM-S901N'; // 앞 측정 값이 남은 통로
    await manager.stopCapture();
    expect(manager.lastRecordPath, isNull);
    expect(manager.lastNoiseSampleRateHz, isNull);
    expect(manager.lastDeviceModel, isNull);
  });
}
