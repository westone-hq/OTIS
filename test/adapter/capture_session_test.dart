import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/capture_session.dart';
import 'package:vibration_checker/adapter/sensor_channel.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

/// 작성: 2026-10-05 10:00:11 · nada
/// 클래스: _FakeSensors
/// 목적: 안드로이드 대신 요청을 기록하는 센서 통로. 센서 확인 응답을 시험이
///       원하는 때 돌려줄 수 있게 붙잡아 둔다.
class _FakeSensors extends SensorChannelManager {
  /// 받은 요청 이름을 차례대로 쌓는다
  final List<String> calls = <String>[];

  /// 센서 확인 응답을 붙잡아 두는 자리. 시험이 `complete(true)` 로 풀어 준다
  final Completer<bool> availableReply = Completer<bool>();

  /// 볼륨키 가로채기가 지금 켜져 있는지 (마지막 요청 기준)
  bool volumeKeyOn = false;

  /// 작성: 2026-10-05 10:00:11 · nada
  /// 함수: checkSensorsAvailable
  /// 목적: 시험이 풀어 줄 때까지 응답을 미룬다.
  @override
  Future<bool> checkSensorsAvailable() {
    calls.add('check');
    return availableReply.future;
  }

  /// 작성: 2026-10-05 10:00:11 · nada
  /// 함수: startCapture
  /// 목적: 수집 시작 요청을 기록한다.
  @override
  Future<void> startCapture({
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 0.0,
  }) async => calls.add('start');

  /// 작성: 2026-10-05 10:00:11 · nada
  /// 함수: stopCapture
  /// 목적: 수집 정지 요청을 기록한다.
  @override
  Future<void> stopCapture() async => calls.add('stop');

  /// 작성: 2026-10-05 10:00:11 · nada
  /// 함수: setVolumeKeyCaptureEnabled
  /// 목적: 볼륨키 가로채기 요청을 기록하고 상태를 바꾼다.
  @override
  Future<void> setVolumeKeyCaptureEnabled(bool enabled) async {
    calls.add('volume:$enabled');
    volumeKeyOn = enabled;
  }

  /// 작성: 2026-10-05 10:00:11 · nada
  /// 함수: nativeEventStream
  /// 목적: 값이 오지 않는 빈 이벤트 흐름을 준다.
  @override
  Stream<NativeEvent> get nativeEventStream =>
      const Stream<NativeEvent>.empty();
}

/// 작성: 2026-10-05 10:00:11 · nada
/// 함수: main
/// 목적: 수집 시작 도중에 정지가 끼어도 정지 뒤에 수집 · 볼륨키 가로채기가
///       켜진 채 남지 않는지, 정지를 두 번 불러도 같은 요청을 두 번 보내지
///       않는지 시험한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('센서 확인을 기다리는 사이 정지되면 수집을 켜지 않는다', () async {
    final sensors = _FakeSensors(); // 요청을 기록하는 센서 통로
    final session = CaptureSession(sensorManager: sensors); // 시험할 수집

    final starting = session.start(
      onVolumeKey: () {},
      onNoResponse: () {},
    ); // 센서 확인에서 멈춰 있는 시작
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await session.stop();
    sensors.availableReply.complete(true);
    await starting;

    expect(sensors.calls, isNot(contains('start')));
    expect(sensors.volumeKeyOn, isFalse);
  });

  test('정상으로 켠 수집은 정지 때 한 번씩만 되돌린다', () async {
    final sensors = _FakeSensors(); // 요청을 기록하는 센서 통로
    final session = CaptureSession(sensorManager: sensors); // 시험할 수집
    sensors.availableReply.complete(true);

    await session.start(onVolumeKey: () {}, onNoResponse: () {});
    expect(sensors.volumeKeyOn, isTrue);

    await session.stop();
    await session.stop();

    expect(sensors.volumeKeyOn, isFalse);
    expect(sensors.calls.where((c) => c == 'stop').length, 1);
    expect(sensors.calls.where((c) => c == 'volume:false').length, 1);
  });
}
