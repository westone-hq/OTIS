import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:vibration_checker/adapter/sensor_channel.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/capture/noise_offset.dart';

/// 작성: 2026-10-04 13:29:41 · nada
/// 클래스: CaptureSession
/// 목적: 측정 한 번의 센서 수집을 켜고 끄는 절차를 맡는다. 측정 화면
///       (measuring_screen.dart)이 화면 모양과 상관없이 같은 순서로
///       수집하도록, 순서가 중요한 단계를 이 클래스 하나에 모은다.
///       - `start()` — 화면 꺼짐 방지, 마이크 권한, 센서 구독, 볼륨키
///         가로채기, 무응답 감시를 차례로 건다
///       - `stop()` — 건 것을 거꾸로 푼다. 여러 번 불러도 안전하다
///       수집한 이벤트는 `resampler` 에 쌓이고, 저장은
///       `MeasurementRecorder`(measurement_recorder.dart)가 한다.
class CaptureSession {
  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: CaptureSession
  /// 목적: 수집 한 번에 쓸 센서 통로와 격자(일정한 시간 간격으로 줄 세운
  ///       표의 각 행) 환산기를 준비한다.
  /// 인자: sensorManager — 안드로이드 센서와 주고받는 통로. null 이면
  ///       새로 만든다. 다른 구현을 끼워 넣을 때만 넘긴다
  CaptureSession({SensorChannelManager? sensorManager})
    : _sensorManager = sensorManager ?? SensorChannelManager();

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 변수: noResponseTimeout
  /// 목적: 수집을 시작한 뒤 이 시간 안에 센서 값이 하나도 안 오면 무응답
  ///       으로 본다.
  /// 근거: 미확인 — 3초를 고른 근거가 코드 · 문서에 없다
  static const Duration noResponseTimeout = Duration(seconds: 3);

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 변수: _flushWait
  /// 목적: 수집 정지를 요청한 뒤 구독을 끊기 전까지 기다리는 시간.
  ///       안드로이드는 남은 묶음을 정지 요청의 응답 뒤에 메인 스레드로
  ///       보내므로, 기다리지 않고 끊으면 측정 끝부분이 사라진다.
  /// 근거: 미확인 — 300ms 를 고른 근거가 코드 · 문서에 없다
  static const Duration _flushWait = Duration(milliseconds: 300);

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 변수: _slowStepLimit
  /// 목적: 정리 단계 하나를 기다리는 한도. 넘기면 포기하고 다음 단계로
  ///       간다 — 안드로이드 응답이 늦어 화면 나가기가 멈추면 안 된다.
  /// 근거: 미확인 — 500ms 를 고른 근거가 코드 · 문서에 없다
  static const Duration _slowStepLimit = Duration(milliseconds: 500);

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 변수: _wakelockOnLimit
  /// 목적: 화면 꺼짐 방지를 켤 때 기다리는 한도. 넘기면 켜졌는지와
  ///       상관없이 수집을 시작한다 — 화면 꺼짐 방지 때문에 측정이
  ///       늦어지면 안 된다.
  /// 근거: 미확인 — 100ms 를 고른 근거가 코드 · 문서에 없다
  static const Duration _wakelockOnLimit = Duration(milliseconds: 100);

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 변수: _wakelockOffLimit
  /// 목적: 화면 꺼짐 방지를 끌 때 기다리는 한도.
  /// 근거: 미확인 — 200ms 를 고른 근거가 코드 · 문서에 없다
  static const Duration _wakelockOffLimit = Duration(milliseconds: 200);

  /// 안드로이드 센서와 주고받는 통로
  final SensorChannelManager _sensorManager;

  /// 받은 센서 이벤트를 쌓아 두었다가 측정이 끝나면 격자로 환산한다.
  /// `start()` 의 구독이 채우고, `MeasurementRecorder.record()` 가 읽는다
  final GridResampler resampler = GridResampler(config: const CaptureConfig());

  /// 센서 이벤트 구독. `start()` 가 센서가 있을 때만 만들고 `stop()` 이
  /// 끊는다. 구독 중이 아니면 null
  StreamSubscription<NativeEvent>? _sensorSub;

  /// 볼륨키 눌림 구독. `start()` 가 센서가 있을 때 만들고 `stop()` 이
  /// 끊는다. 구독 중이 아니면 null
  StreamSubscription<void>? _volumeKeySub;

  /// 무응답 감시 타이머. `start()` 가 걸고, 기한 전에 `stop()` 이
  /// 불리면 취소된다. 감시 중이 아니면 null
  Timer? _noResponseTimer;

  /// 센서 이벤트를 한 번이라도 받았는지. 무응답 감시가 이 값을 본다
  bool _receivedSample = false;

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: lastCaptureError
  /// 목적: 수집 시작 요청이 실패했을 때 화면에 보여줄 원인 문구. 실패가
  ///       없었으면 null.
  String? get lastCaptureError => _sensorManager.lastCaptureError;

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: nativeRecordPath
  /// 목적: 안드로이드가 `stop()` 때 저장한 원본 기록 파일 경로. 저장하지
  ///       못했거나 아직 멈추기 전이면 null.
  String? get nativeRecordPath => _sensorManager.lastRecordPath;

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: start
  /// 목적: 수집을 시작한다. 순서대로 진행한다. 마이크 권한은 여기서
  ///       요청하지 않는다 — 측정 중에 권한 창이 뜨면 뒤집어 놓은 휴대폰에서
  ///       누를 수 없으므로 시작 화면이 미리 받는다(`ensureMicPermission()`).
  ///       권한이 없으면 소음 수집 쪽이 0 으로 대신한다.
  ///       1. 화면 꺼짐 방지를 켠다. 한도 안에 응답이 없어도 넘어간다
  ///       2. 센서가 있으면 수집을 시작하고 이벤트를 `resampler` 에
  ///          쌓는다. 측정은 볼륨키로 끝내므로 볼륨키도 가로챈다
  ///       3. 센서 유무와 상관없이 무응답 감시를 건다. 센서가 없으면
  ///          값이 오지 않으므로 감시가 그 경우도 잡는다
  /// 인자: onVolumeKey — 볼륨키가 눌릴 때마다 부를 함수
  ///       onNoResponse — `noResponseTimeout` 안에 값이 하나도 안 오면
  ///       한 번 부를 함수
  Future<void> start({
    required void Function() onVolumeKey,
    required void Function() onNoResponse,
  }) async {
    try {
      await WakelockPlus.enable().timeout(_wakelockOnLimit);
    } catch (_) {}

    // → 로직 이동: SensorChannelManager.checkSensorsAvailable()
    final available = await _sensorManager.checkSensorsAvailable(); // 센서 유무
    if (available) {
      // → 로직 이동: SensorChannelManager.startCapture()
      await _sensorManager.startCapture(
        calibrationOffsetDba: 0.0,
        micDbfsToDbaOffset: kDefaultMicDbfsToDbaOffset,
      );
      _sensorSub = _sensorManager.nativeEventStream.listen((event) {
        _receivedSample = true;
        resampler.onEvent(event); // → 로직 이동: GridResampler.onEvent()
      });
      // → 로직 이동: SensorChannelManager.setVolumeKeyCaptureEnabled()
      await _sensorManager.setVolumeKeyCaptureEnabled(true);
      _volumeKeySub = _sensorManager.volumeKeyPresses.listen(
        (_) => onVolumeKey(),
      );
    }

    _noResponseTimer = Timer(noResponseTimeout, () {
      if (!_receivedSample) onNoResponse();
    });
  }

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: stop
  /// 목적: `start()` 가 건 것을 거꾸로 푼다. 측정을 끝낼 때, 중단할 때,
  ///       화면이 사라질 때 모두 부르므로 두 번 불러도 안전해야 한다 —
  ///       그래서 각 구독을 끊기 전에 먼저 필드를 비운다.
  ///       - 수집 정지 요청을 구독 끊기보다 먼저 보낸다. 정지 요청이
  ///         안드로이드에 남은 묶음을 내보내게 하는데, 구독을 먼저 끊으면
  ///         안드로이드가 보낼 통로를 닫아 남은 묶음이 버려진다
  ///       - 정지 응답 뒤에도 남은 묶음이 도착하므로 `_flushWait` 만큼
  ///         기다린 뒤 구독을 끊는다
  ///       - 안드로이드 응답이 늦거나 실패해도 한도가 지나면 다음 단계로
  ///         간다
  Future<void> stop() async {
    _noResponseTimer?.cancel();
    _noResponseTimer = null;

    final volumeKeySub = _volumeKeySub; // 끊기 전에 옮겨 두는 구독, 없으면 null
    _volumeKeySub = null;
    // → 로직 이동: SensorChannelManager.setVolumeKeyCaptureEnabled()
    await _limit(_sensorManager.setVolumeKeyCaptureEnabled(false));
    if (volumeKeySub != null) await _limit(volumeKeySub.cancel());

    final sensorSub = _sensorSub; // 끊기 전에 옮겨 두는 구독, 없으면 null
    _sensorSub = null;
    // → 로직 이동: SensorChannelManager.stopCapture()
    await _limit(_sensorManager.stopCapture());
    await Future<void>.delayed(_flushWait);
    if (sensorSub != null) await _limit(sensorSub.cancel());

    try {
      await WakelockPlus.disable().timeout(_wakelockOffLimit);
    } catch (_) {}
  }

  /// 작성: 2026-10-04 13:29:41 · nada
  /// 함수: _limit
  /// 목적: 정리 단계 하나를 `_slowStepLimit` 까지만 기다린다. 늦거나
  ///       실패해도 오류를 올리지 않는다 — 정리가 막혀 화면을 못 나가는
  ///       것이 더 나쁘다.
  /// 인자: step — 기다릴 정리 단계 (정지 요청, 구독 끊기 등)
  Future<void> _limit(Future<void> step) async {
    try {
      await step.timeout(_slowStepLimit);
    } catch (_) {}
  }
}
