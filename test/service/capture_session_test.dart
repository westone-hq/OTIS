import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/sensor/sensor_channel.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/capture/placement.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/service/capture_session.dart';

/// 작성: 2026-10-05 10:00:11 · 박건준
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

  /// 수집 정지 때 안드로이드가 현장 소음 녹음을 닫았다고 알릴 경로. null
  /// 이면 녹음하지 않은 것으로 둔다
  String? audioPathOnStop;

  /// 작성: 2026-10-05 10:00:11 · 박건준
  /// 함수: checkSensorsAvailable
  /// 목적: 시험이 풀어 줄 때까지 응답을 미룬다.
  @override
  Future<bool> checkSensorsAvailable() {
    calls.add('check');
    return availableReply.future;
  }

  /// 작성: 2026-10-05 10:00:11 · 박건준
  /// 함수: startCapture
  /// 목적: 수집 시작 요청을 기록한다.
  @override
  Future<void> startCapture({
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 0.0,
  }) async => calls.add('start');

  /// 작성: 2026-10-05 10:00:11 · 박건준
  /// 수정: 2026-10-18 10:12:30 · 박건준
  /// 함수: stopCapture
  /// 목적: 수집 정지 요청을 기록하고, 안드로이드처럼 원본 기록 · 현장 소음
  ///       녹음 경로를 알린다(`recordPathOnStop`, `audioPathOnStop`).
  @override
  Future<void> stopCapture() async {
    calls.add('stop');
    lastRecordPath = recordPathOnStop;
    lastAudioPath = audioPathOnStop;
  }

  /// 작성: 2026-10-05 10:00:11 · 박건준
  /// 함수: setVolumeKeyCaptureEnabled
  /// 목적: 볼륨키 가로채기 요청을 기록하고 상태를 바꾼다.
  @override
  Future<void> setVolumeKeyCaptureEnabled(bool enabled) async {
    calls.add('volume:$enabled');
    volumeKeyOn = enabled;
  }

  /// 작성: 2026-10-22 09:30:00 · 박건준
  /// 수정: 2026-10-27 12:00:00 · 박건준
  /// 함수: playBeep
  /// 목적: 시작 · 종료 알림음 요청을 기록한다.
  @override
  Future<void> playBeep() async => calls.add('beep');

  /// 수집 중 흘려보낼 이벤트. 비어 있으면 값이 오지 않는다
  List<NativeEvent> events = const <NativeEvent>[];

  /// 작성: 2026-10-05 10:00:11 · 박건준
  /// 수정: 2026-10-15 22:32:44 · 박건준
  /// 함수: nativeEventStream
  /// 목적: `events` 를 차례로 흘려보낸다. 비어 있으면 값이 오지 않는다.
  @override
  Stream<NativeEvent> get nativeEventStream =>
      Stream<NativeEvent>.fromIterable(events);
}

/// 작성: 2026-10-05 10:00:11 · 박건준
/// 수정: 2026-10-27 12:00:00 · 박건준
/// 함수: main
/// 목적: 수집 시작 도중에 정지가 끼어도 정지 뒤에 수집 · 볼륨키 가로채기가
///       켜진 채 남지 않는지, 정지를 두 번 불러도 같은 요청을 두 번 보내지
///       않는지, 저장하지 않는 중단(`discard()`)만 안드로이드 원본을
///       지우는지, 측정 중 속도를 정한 간격으로 내보내는지, 거치 판정이
///       알림음 없이 기록만 되는지, 시작 · 종료 알림음 시점을 시험한다.
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

  test('측정 중 속도를 어림해 250ms 마다 한 번씩 내보낸다', () async {
    final sensors = _FakeSensors(); // 요청을 기록하는 센서 통로
    // 4ms 간격으로 정지 1.2초 → 100 mg 로 1초 가속. 화면을 아래로 놓아
    // 중력 Z 가 −1000 이고, 위로 가속하면 raw Z 가 −1000 − 100 이다
    NativeEvent raw(int i, double zMg) => NativeEvent(
      type: NativeEventType.accel,
      tsUs: i * 4000,
      xMg: 1,
      yMg: 0,
      zMg: zMg,
      dtUs: 4000,
    );
    sensors.events = <NativeEvent>[
      const NativeEvent(
        type: NativeEventType.gravity,
        tsUs: 0,
        xMg: 0,
        yMg: 0,
        zMg: -1000,
        dtUs: 0,
      ),
      for (var i = 1; i <= 300; i++) raw(i, -1000),
      for (var i = 301; i <= 550; i++) raw(i, -1100),
    ];
    final session = CaptureSession(sensorManager: sensors); // 시험할 수집
    final published = <double?>[]; // 내보낸 속도
    session.liveSpeedMps.addListener(
      () => published.add(session.liveSpeedMps.value),
    );
    sensors.availableReply.complete(true);

    await session.start(onVolumeKey: () {}, onNoResponse: () {});
    await Future<void>.delayed(Duration.zero);
    await session.stop();

    // 2.2초 동안 250ms 마다 한 번 — 첫 이벤트 포함 9번을 넘지 않는다
    expect(published.length, lessThanOrEqualTo(9));
    // 마지막으로 내보낸 2.0초는 가속 0.8초 째다. 0.98 m/s² × 0.8초 =
    // 0.78 m/s 에서 저역 지연(0.25초)만큼 덜 오른다
    expect(session.liveSpeedMps.value, inInclusiveRange(0.45, 0.78));
  });

  group('거치 방향 (2026-10-22, 경고는 2026-10-27 에 없앰)', () {
    // 4ms 간격 중력 · 가속도 2.4초. 중력 Z 가 거치 방향을 정한다
    List<NativeEvent> placed(double gravityZ) => <NativeEvent>[
      for (var i = 1; i <= 600; i++) ...[
        NativeEvent(
          type: NativeEventType.gravity,
          tsUs: i * 4000,
          xMg: 0,
          yMg: 0,
          zMg: gravityZ,
          dtUs: 4000,
        ),
        NativeEvent(
          type: NativeEventType.accel,
          tsUs: i * 4000 + 1,
          xMg: 1,
          yMg: 0,
          zMg: gravityZ,
          dtUs: 4000,
        ),
      ],
    ];

    Future<(_FakeSensors, CaptureSession)> run(double gravityZ) async {
      final sensors = _FakeSensors()..events = placed(gravityZ);
      final session = CaptureSession(sensorManager: sensors); // 시험할 수집
      sensors.availableReply.complete(true);
      await session.start(onVolumeKey: () {}, onNoResponse: () {});
      await Future<void>.delayed(Duration.zero);
      await session.stop();
      return (sensors, session);
    }

    test('화면 위 · 기울어짐 · 화면 아래를 판정만 하고 알림음은 울리지 않는다', () async {
      for (final (gravityZ, expected) in <(double, Placement)>[
        (1000, Placement.faceUp),
        (-700, Placement.tilted),
        (-998, Placement.faceDown),
      ]) {
        final (sensors, session) = await run(gravityZ);
        expect(session.placement!.placement, expected, reason: '$gravityZ');
        expect(
          sensors.calls,
          isNot(contains('beep')),
          reason: '측정 중 거치 경고음 · 진동은 없앴다',
        );
        expect(sensors.calls, contains('stop'));
      }
    });
  });

  group('시작 · 종료 알림음 (2026-10-27)', () {
    test('시작음은 요청 즉시 한 번 울린다', () async {
      final sensors = _FakeSensors(); // 요청을 기록하는 센서 통로
      final session = CaptureSession(sensorManager: sensors); // 시험할 수집

      await session.playStartBeep();

      expect(sensors.calls, <String>['beep']);
    });

    test('종료음은 종료를 누른 뒤 0.5초를 채워 울린다', () async {
      final sensors = _FakeSensors(); // 요청을 기록하는 센서 통로
      final session = CaptureSession(sensorManager: sensors); // 시험할 수집
      sensors.availableReply.complete(true);
      await session.start(onVolumeKey: () {}, onNoResponse: () {});
      await session.stop();

      final watch = Stopwatch()..start(); // 종료음까지 걸린 시간
      await session.playEndBeep(elapsed: const Duration(milliseconds: 100));

      expect(sensors.calls.last, 'beep');
      expect(
        watch.elapsedMilliseconds,
        greaterThanOrEqualTo(CaptureConfig.endBeepDelayMs - 100 - 20),
      );
    });

    test('정지가 0.5초보다 오래 걸렸으면 기다리지 않고 바로 울린다', () async {
      final sensors = _FakeSensors(); // 요청을 기록하는 센서 통로
      final session = CaptureSession(sensorManager: sensors); // 시험할 수집
      await session.stop();

      final watch = Stopwatch()..start(); // 종료음까지 걸린 시간
      await session.playEndBeep(elapsed: const Duration(seconds: 1));

      expect(sensors.calls.last, 'beep');
      expect(watch.elapsedMilliseconds, lessThan(200));
    });

    test('알림음 앞뒤 길이는 지시대로 0.5초다', () {
      expect(CaptureConfig.startBeepLeadMs, 500);
      expect(CaptureConfig.endBeepDelayMs, 500);
    });
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

    /// 작성: 2026-10-07 03:30:18 · 박건준
    /// 수정: 2026-10-18 10:12:30 · 박건준
    /// 함수: startedSession
    /// 목적: 원본 기록 파일(과 현장 소음 녹음)을 남기는 센서 통로로 수집을
    ///       켠 상태를 만든다.
    /// 인자: native — 정지 때 안드로이드가 저장했다고 알릴 원본 파일
    ///       audio — 정지 때 닫았다고 알릴 녹음 파일. 없으면 녹음 없음
    /// 반환: 수집이 켜진 측정
    Future<CaptureSession> startedSession(File native, [File? audio]) async {
      final sensors = _FakeSensors()
        ..recordPathOnStop = native.path
        ..audioPathOnStop = audio?.path; // 요청을 기록하는 센서 통로
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

    test('중단(discard)하면 현장 소음 녹음도 지운다', () async {
      final native = File('${temp.path}/raw_native_3.txt'); // 원본 자리
      await native.writeAsString('accel 1 0 0 1000 3906\n');
      final audio = File('${temp.path}/noise_native_3.m4a'); // 녹음 자리
      await audio.writeAsBytes(const <int>[0, 0, 0, 24]);
      final session = await startedSession(native, audio); // 켜진 수집

      await session.discard();

      expect(await audio.exists(), isFalse, reason: '쓰지 않는 녹음이 쌓인다');
    });

    test('저장하는 마무리(stop)는 원본을 남긴다', () async {
      final native = File('${temp.path}/raw_native_2.txt'); // 원본 자리
      await native.writeAsString('accel 1 0 0 1000 3906\n');
      final session = await startedSession(native); // 켜진 수집

      await session.stop();

      expect(await native.exists(), isTrue, reason: '저장 절차가 옮겨야 한다');
      expect(session.nativeRecordPath, native.path);
    });

    test('저장하는 마무리(stop)는 현장 소음 녹음 경로를 넘겨 준다', () async {
      final native = File('${temp.path}/raw_native_4.txt'); // 원본 자리
      await native.writeAsString('accel 1 0 0 1000 3906\n');
      final audio = File('${temp.path}/noise_native_4.m4a'); // 녹음 자리
      await audio.writeAsBytes(const <int>[0, 0, 0, 24]);
      final session = await startedSession(native, audio); // 켜진 수집

      await session.stop();

      expect(await audio.exists(), isTrue, reason: '저장 절차가 옮겨야 한다');
      expect(session.noiseAudioPath, audio.path);
    });
  });
}
