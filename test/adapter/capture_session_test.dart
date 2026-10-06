import 'dart:async';
import 'dart:io';

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

  /// 수집 정지 때 안드로이드가 원본 기록을 저장했다고 알릴 경로. null 이면
  /// 저장하지 않은 것으로 둔다
  String? recordPathOnStop;

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
  /// 수정: 2026-10-07 03:30:18 · nada
  /// 함수: stopCapture
  /// 목적: 수집 정지 요청을 기록하고, 안드로이드처럼 원본 기록 경로를
  ///       알린다(`recordPathOnStop`).
  @override
  Future<void> stopCapture() async {
    calls.add('stop');
    lastRecordPath = recordPathOnStop;
  }

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
/// 수정: 2026-10-07 03:30:18 · nada
/// 함수: main
/// 목적: 수집 시작 도중에 정지가 끼어도 정지 뒤에 수집 · 볼륨키 가로채기가
///       켜진 채 남지 않는지, 정지를 두 번 불러도 같은 요청을 두 번 보내지
///       않는지, 저장하지 않는 중단(`discard()`)만 안드로이드 원본을
///       지우는지 시험한다.
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

  group('저장하지 않는 중단의 안드로이드 원본', () {
    late Directory temp; // 원본 기록을 둘 임시 폴더

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('otis_capture_test');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    /// 작성: 2026-10-07 03:30:18 · nada
    /// 함수: startedSession
    /// 목적: 원본 기록 파일을 남기는 센서 통로로 수집을 켠 상태를 만든다.
    /// 인자: native — 정지 때 안드로이드가 저장했다고 알릴 원본 파일
    /// 반환: 수집이 켜진 측정
    Future<CaptureSession> startedSession(File native) async {
      final sensors = _FakeSensors()..recordPathOnStop = native.path; // 통로
      sensors.availableReply.complete(true);
      final session = CaptureSession(sensorManager: sensors); // 시험할 수집
      await session.start(onVolumeKey: () {}, onNoResponse: () {});
      return session;
    }

    test('중단(discard)하면 원본 기록 파일을 지운다', () async {
      final native = File('${temp.path}/raw_native_1.txt'); // 원본 자리
      await native.writeAsString('accel 1 0 0 1000 3906\n');
      final session = await startedSession(native); // 켜진 수집

      await session.discard();
      await session.discard();

      expect(await native.exists(), isFalse, reason: '쓰지 않는 원본이 쌓인다');
    });

    test('저장하는 마무리(stop)는 원본을 남긴다', () async {
      final native = File('${temp.path}/raw_native_2.txt'); // 원본 자리
      await native.writeAsString('accel 1 0 0 1000 3906\n');
      final session = await startedSession(native); // 켜진 수집

      await session.stop();

      expect(await native.exists(), isTrue, reason: '저장 절차가 옮겨야 한다');
      expect(session.nativeRecordPath, native.path);
    });
  });
}
