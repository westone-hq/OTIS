import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme.dart';
import 'package:vibration_checker/adapter/sensor_channel.dart';
import 'package:vibration_checker/adapter/vibration_file_writer.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import '../shared/measurement_session.dart';
import '../shared/send_email_sheet.dart';
import '../../core/widgets/app_dialog.dart';

/// 작성: 2026-08-18 18:17:48 · 박건준
/// 클래스: MeasuringScreen
/// 목적: 측정이 진행되는 동안 보여주는 라이브 화면.
///       - 멀리서도 보이게 경과 시간을 크게 표시한다
///       - 어르신도 잘 보이도록 어두운 남색 배경에 밝은 글자, 72sp
///         크기의 속도 표시, 56dp 이상의 확인 버튼을 쓴다
class MeasuringScreen extends StatefulWidget {
  /// 테스트에서 가짜(mock) 센서 관리자를 주입하기 위한 값. null이면
  /// 화면이 실제 `SensorChannelManager`(안드로이드 쪽 센서와 주고받는
  /// 통신을 담당하는 클래스)를 새로 만들어 쓴다
  final SensorChannelManager? sensorManager;
  const MeasuringScreen({super.key, this.sensorManager});

  @override
  State<MeasuringScreen> createState() => _MeasuringScreenState();
}

/// 클래스: _CaptureGateResult
/// 목적: 측정을 저장해도 되는지 판정한 결과. ok(저장 가능),
///       siteInvalid(현장 정보 누락 · 오류), noSamples(유효 샘플 부족)
enum _CaptureGateResult { ok, siteInvalid, noSamples }

/// 작성: 2026-08-18 18:17:48 · 박건준
/// 클래스: _MeasuringScreenState
/// 목적: 라이브 측정 화면의 상태를 관리한다. 센서 데이터 수집, 경과
///       시간 · 카운트다운 타이머, 앱이 백그라운드로 전환됐을 때의
///       중단 처리를 담당한다.
class _MeasuringScreenState extends State<MeasuringScreen>
    with WidgetsBindingObserver {
  /// 실제로 센서와 통신할 때 쓰는 관리자. 화면을 만들 때
  /// `widget.sensorManager`로 테스트용 가짜 객체를 넣어줬으면 그것을,
  /// 안 넣어줬으면(실제 앱 실행 시) 새로 만든 진짜 객체를 쓴다
  late final SensorChannelManager _sensorManager =
      widget.sensorManager ?? SensorChannelManager();

  /// 경과 시간(`_elapsedSeconds`)을 1초마다 하나씩 올리는 타이머.
  /// `_initCaptureAndTimers()`가 만들고, `_cleanup()`이 멈춘 뒤 비운다.
  /// 아직 시작 전이거나 이미 정리됐으면 null
  Timer? _timeTimer;

  /// 센서 응답이 3초 안에 오는지 감시하는 타이머. `_initCaptureAndTimers()`
  /// 가 만든다. 3초 뒤에도 `_receivedRealSample`이 false면(센서 응답이
  /// 한 번도 없었으면) 이 타이머가 측정을 중단시킨다. 그 전에 응답이
  /// 오거나 `_cleanup()`이 불리면 실행되지 않고 취소된다. 감시 중이
  /// 아니면 null
  Timer? _releaseTimeoutTimer;

  /// 센서가 보내는 원본 데이터를 받아오는 구독. `_initCaptureAndTimers()`
  /// 가 실제 센서가 있을 때만 만들고, 데이터가 올 때마다
  /// `_receivedRealSample`을 true로 바꾸고 `_resampler`에 쌓는다.
  /// `_cleanup()`이 끊는다. 구독 중이 아니면 null
  StreamSubscription<NativeEvent>? _sensorSub;

  /// 측정이 시작된 뒤 지난 시간(초). `_timeTimer`가 1초마다 1씩
  /// 올리고, 화면에는 "분:초" 형태로 바꿔 보여준다
  int _elapsedSeconds = 0;

  /// 센서로부터 실제 데이터를 한 번이라도 받았는지 여부. `_sensorSub`가
  /// 데이터를 받을 때마다 true로 바뀐다. `_releaseTimeoutTimer`가 3초
  /// 뒤 이 값을 보고, 여전히 false면 센서 무응답으로 판단해 측정을
  /// 중단시킨다
  bool _receivedRealSample = false;

  /// 격자(일정한 시간 간격으로 줄 세운 표의 각 행)로 환산할 때 쓸
  /// 설정값. `_resampler`를 만들 때 한 번만 쓰인다
  static const CaptureConfig _captureConfig = CaptureConfig();

  /// 수신한 센서 이벤트를 모아뒀다가, 측정이 끝나면 격자로 환산하는
  /// 객체. `_sensorSub`가 데이터를 받을 때마다 이벤트가 쌓이고,
  /// `_finishMeasurement()`에서 `resample()`을 불러 최종 환산한다
  final GridResampler _resampler = GridResampler(config: _captureConfig);

  /// 화면에 보여줄, 남은 카운트다운 시간(초). `_startCountdown()`이
  /// 1초마다 하나씩 줄인다
  int _countdownSec = 0;

  /// 지금 카운트다운 화면을 보여주는 중인지 여부. true면 `build()`가
  /// 숫자가 줄어드는 카운트다운 화면을, false면 실제 측정 진행
  /// 화면을 그린다
  bool _isCountingDown = false;

  /// 카운트다운 숫자를 1초마다 줄이는 타이머. `_startCountdown()`이
  /// 만들고, 0에 도달하면 스스로 멈춘다. 진행 중이 아니면 null
  Timer? _countdownTimer;

  /// 앱이 백그라운드로 전환되어(전화 수신 등) 측정이 중단됐는지 여부.
  /// `didChangeAppLifecycleState()`가 true로 표시하고, 앱이 다시
  /// 돌아오면 이 값을 보고 중단 안내 대화상자를 띄운다
  bool _measurementAborted = false;

  /// 측정이 끝났는지 여부. 저장에 성공했을 때(`_finishMeasurement()`),
  /// 3초간 무응답으로 중단됐을 때, 사용자가 뒤로가기로 중단했을 때
  /// (`_confirmAndExit()`) 전부 true가 된다.
  /// `didChangeAppLifecycleState()`가 이 값을 보고, 이미 끝난 측정을
  /// 앱 전환 때 또 정리하지 않도록 막는다
  bool _isFinished = false;

  /// "테스트 완료" 버튼을 눌러 마무리 처리가 진행 중인지 여부.
  /// `_finishMeasurement()`가 시작할 때 true로 바꾸고, 이 값이 true인
  /// 동안 버튼을 비활성화해 중복 실행을 막는다
  bool _isFinishing = false;

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: initState
  /// 목적: 이 화면이 새로 만들어질 때 한 번만 실행된다.
  ///       - 전화가 오는 등 앱이 화면 밖으로 밀려나는 순간을 이 화면이
  ///         알아챌 수 있도록 미리 준비해둔다
  ///       - 시작 전 대기 시간이 있으면 카운트다운부터 시작하고, 없으면
  ///         곧바로 센서 수집을 시작한다
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // `MeasurementSession`(화면 간에 공유하는, 이번 측정 하나에 대한
    // 정보 저장소)에서 시작 전 대기 시간을 읽는다
    final delay = MeasurementSession.instance.delaySec; // 초 단위
    if (delay > 0) {
      _countdownSec = delay;
      _isCountingDown = true;
      _startCountdown(); // → 로직 이동: _startCountdown()
    } else {
      _initCaptureAndTimers(); // → 로직 이동: _initCaptureAndTimers()
    }
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _startCountdown
  /// 목적: 1초마다 카운트다운 숫자를 하나씩 줄이는 타이머를 시작한다.
  ///       0에 도달하면 타이머를 멈추고 실제 측정 준비로 넘어간다. 화면이
  ///       이미 사라졌으면(`mounted`가 false) 그대로 타이머만 멈춘다.
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSec > 1) {
          _countdownSec--;
        } else {
          _countdownSec = 0;
          _isCountingDown = false;
          timer.cancel();
          _initCaptureAndTimers(); // → 로직 이동: _initCaptureAndTimers()
        }
      });
    });
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _initCaptureAndTimers
  /// 목적: 카운트다운이 끝난 뒤(또는 대기 시간이 없으면 곧바로) 실제
  ///       측정을 준비하고 시작한다. 순서대로 네 단계를 거친다.
  ///       1. 화면이 꺼지지 않도록 화면 꺼짐 방지를 켠다. 100ms 안에
  ///          응답이 없어도 무시하고 진행한다 — 느려도 측정 자체를
  ///          막지 않는다
  ///       2. 1초마다 경과 시간을 올리는 타이머를 시작한다
  ///       3. 센서가 실제로 있는지 확인하고, 있으면 측정을 시작해
  ///          센서 데이터를 구독한다
  ///       4. 3초 안에 센서 데이터가 하나도 안 오면 측정을 중단하고
  ///          실패 안내를 띄운다. 개발용 빌드와 실제 배포판이 똑같이
  ///          동작해야, 이 문제를 개발 중에 미리 발견할 수 있다
  Future<void> _initCaptureAndTimers() async {
    try {
      await WakelockPlus.enable()
          .timeout(const Duration(milliseconds: 100))
          .catchError((_) {});
    } catch (_) {}

    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });

    // → 로직 이동: SensorChannelManager.checkSensorsAvailable()
    final bool available = await _sensorManager.checkSensorsAvailable(); // 센서 가용 여부
    if (available) {
      // → 로직 이동: SensorChannelManager.startCapture()
      await _sensorManager.startCapture();
      _sensorSub = _sensorManager.nativeEventStream.listen((event) {
        _receivedRealSample = true;
        // → 로직 이동: GridResampler.onEvent()
        _resampler.onEvent(event);
      });
    }

    // 이 3초 안에 사용자가 뒤로가기를 눌러 측정을 중단하면(확인 대화
    // 상자에서 "중단하기" 선택 → _cleanup() 호출), 이 타이머도 함께
    // 취소되어 아래 실패 안내는 뜨지 않는다.
    _releaseTimeoutTimer = Timer(const Duration(seconds: 3), () async {
      if (mounted && !_receivedRealSample) {
        _isFinished = true;
        await _cleanup(); // → 로직 이동: _cleanup()
        final cause = _sensorManager.lastCaptureError; // 실패 원인 문구, 없으면 null
        // 대화상자에 보여줄 안내 문구. 원인이 있으면 뒤에 덧붙인다
        final message = cause == null
            ? '센서 응답이 없습니다. 측정을 중단합니다.'
            : '센서 응답이 없습니다. 측정을 중단합니다.\n$cause';
        await _showMeasureFailDialog(
          message,
        ); // → 로직 이동: _showMeasureFailDialog()
      }
    });
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _cleanup
  /// 목적: 진행 중이던 타이머, 센서 구독, 화면 꺼짐 방지를 전부
  ///       정리한다. 측정을 중단하거나 끝낼 때, 화면이 사라질 때 등
  ///       여러 곳에서 공통으로 부른다.
  ///       - 타이머 3개(경과 시간, 카운트다운, 3초 무수신 감시)를
  ///         멈추고 비운다
  ///       - 안드로이드에 "그만 보내" 요청(`stopCapture`)을 먼저
  ///         보내고, 0.3초 기다린 뒤에야 구독을 끊는다. 순서를 바꾸면
  ///         안 된다 — 안드로이드가 마지막 남은 데이터를 이 요청의
  ///         응답 이후에도 조금 더 보내는데, 구독을 먼저 끊으면 그
  ///         마지막 데이터를 놓친다
  ///       - 화면 꺼짐 방지를 끈다
  ///       - 안드로이드 쪽 응답이 늦거나 오류가 나도(정지 요청, 구독
  ///         끊기, 화면 꺼짐 방지 해제 전부) 무시하고 넘어간다. 화면을
  ///         나가는 절차 자체가 거기서 막히면 안 되기 때문이다
  Future<void> _cleanup() async {
    _timeTimer?.cancel();
    _countdownTimer?.cancel();
    _releaseTimeoutTimer?.cancel();
    _timeTimer = null;
    _countdownTimer = null;
    _releaseTimeoutTimer = null;
    final sensorSub = _sensorSub; // 끊기 전에 잠시 옮겨두는 구독, 없으면 null
    _sensorSub = null;
    // 순서 고정: stopCapture 가 네이티브 잔여 배치를 flush 하므로 먼저 부른다.
    // 구독을 먼저 끊으면 onCancel 이 eventSink 를 비워 잔여분이 버려진다.
    // → 로직 이동: SensorChannelManager.stopCapture()
    await _ignoreSlowCleanup(_sensorManager.stopCapture());
    // 잔여 배치는 안드로이드 메인 스레드에 예약되어 stopCapture 응답 이후 도착한다.
    // 도착 대기 없이 구독을 끊으면 같은 유실이 재발한다.
    await Future.delayed(const Duration(milliseconds: 300));
    if (sensorSub != null) {
      await _ignoreSlowCleanup(sensorSub.cancel());
    }
    try {
      await WakelockPlus.disable().timeout(const Duration(milliseconds: 200));
    } catch (_) {}
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _ignoreSlowCleanup
  /// 목적: 정리 작업이 0.5초 안에 안 끝나거나 오류가 나도 무시하고
  ///       넘어간다. 응답이 늦어 화면 나가기가 멈추는 걸 막는다.
  /// 인자: future — 기다릴 정리 작업 (예: 센서 정지 요청, 구독 끊기)
  Future<void> _ignoreSlowCleanup(Future<void> future) async {
    try {
      await future.timeout(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: dispose
  /// 목적: 이 화면이 완전히 사라질 때 한 번만 실행된다.
  ///       - `initState`에서 걸어둔 앱 상태 감시(`WidgetsBinding`이
  ///         화면이 보이는지 안 보이는지를 이 화면에 알려주는 장치)를
  ///         해제한다
  ///       - `_cleanup()`으로 타이머 · 센서를 정리한다. `dispose`는
  ///         결과를 기다려줄 수 없어 시켜만 두고 먼저 끝나는데,
  ///         `_cleanup()`은 화면 없이도 안전하게 뒤에서 계속
  ///         실행된다. `unawaited(...)`는 그걸 일부러 안 기다린다는
  ///         표시이다
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cleanup()); // → 로직 이동: _cleanup()
    super.dispose();
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: didChangeAppLifecycleState
  /// 목적: 앱이 화면 밖으로 밀려나거나(전화 수신, 홈 버튼 등) 다시
  ///       돌아올 때 Flutter가 불러주는 함수다. 측정 중 앱이 밀려나면
  ///       측정을 중단하고, 다시 돌아오면 중단됐었다는 안내를 띄운다.
  ///       - `paused`(화면이 안 보이게 됨) 상태고, 아직 측정이 끝나지도
  ///         이미 중단되지도 않았으면 측정을 정리하고 중단 상태로 표시한다
  ///       - `resumed`(다시 화면에 보임) 상태고 중단된 적이 있으면,
  ///         중단 안내 대화상자를 띄운다
  /// 인자: state — 앱이 지금 어떤 상태로 바뀌었는지 (화면에 보임 ·
  ///       안 보임 등)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused &&
        !_isFinished &&
        !_measurementAborted) {
      unawaited(_cleanup()); // → 로직 이동: _cleanup()
      _measurementAborted = true;
    } else if (state == AppLifecycleState.resumed && _measurementAborted) {
      _showAbortedDialog(); // → 로직 이동: _showAbortedDialog()
    }
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _showAbortedDialog
  /// 목적: 측정 중 전화가 오는 등 앱이 화면 밖으로 밀려나면 측정이
  ///       중단된다. 앱으로 다시 돌아왔을 때, 이 대화상자로 측정이
  ///       중단됐었다는 사실을 알려준다(`didChangeAppLifecycleState`
  ///       에서 부름). "확인"을 누르면 `/start` 화면으로 돌아간다.
  ///       화면이 이미 사라졌으면(`mounted`가 false) 아무것도 하지
  ///       않는다.
  Future<void> _showAbortedDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('측정이 중단되었습니다'),
        content: const Text(
          '측정 중 앱이 백그라운드로 전환되어(전화 수신 등) 측정을 중단했습니다. 처음부터 다시 측정해 주세요.',
        ),
        actions: [
          AppDialogButton(
            label: '확인',
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.go('/start');
            },
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _hasValidSite
  /// 목적: 지금 저장된 현장 정보(`MeasurementSession`)가 있고, 시작 ·
  ///       도착 층이 숫자로 제대로 들어있는지 확인한다.
  /// 반환: 유효하면 true
  bool _hasValidSite() {
    final site = MeasurementSession.instance.currentSite; // 저장된 현장 정보, 없으면 null
    if (site == null) return false;
    return int.tryParse(site.bottomFloor) != null &&
        int.tryParse(site.topFloor) != null;
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _evaluateCaptureGate
  /// 목적: 측정을 저장해도 되는 상태인지 판정한다.
  /// 반환: 진행 가능하면 ok, 현장 정보 누락이면 siteInvalid,
  ///       raw 또는 gravity 유효 샘플이 2개 미만이면 noSamples
  _CaptureGateResult _evaluateCaptureGate() {
    if (!_hasValidSite()) return _CaptureGateResult.siteInvalid;
    if (_resampler.rawCount < 2 || _resampler.gravityCount < 2) {
      return _CaptureGateResult.noSamples;
    }
    return _CaptureGateResult.ok;
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _showMeasureFailDialog
  /// 목적: 측정 실패를 알리는 대화상자를 띄운다. "확인"을 누르면
  ///       `/start` 화면으로 돌아간다. 화면이 이미 사라졌으면
  ///       (`mounted`가 false) 아무것도 하지 않는다.
  /// 인자: message — 실패 사유를 보여줄 문구
  Future<void> _showMeasureFailDialog(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('측정 실패'),
        content: Text(message),
        actions: [
          AppDialogButton(
            label: '확인',
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.go('/start');
            },
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _resolveCaptureDirectory
  /// 목적: 이번 측정 산출물을 저장할 디렉터리를 확보한다.
  ///       `MeasurementRepository.getBaseDirectory()`가 기기의 외장
  ///       저장소(없으면 앱 전용 문서 폴더) 아래 `captures` 폴더를
  ///       찾아, 없으면 만들어서 돌려준다.
  /// 반환: 생성이 보장된 저장 디렉터리
  Future<Directory> _resolveCaptureDirectory() async {
    // → 로직 이동: MeasurementRepository.getBaseDirectory()
    return MeasurementRepository.instance.getBaseDirectory();
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _finishMeasurement
  /// 목적: "테스트 완료" 버튼을 눌렀을 때 측정을 마무리한다. 순서대로
  ///       진행한다.
  ///       1. 이미 마무리 중이거나 끝났으면 다시 실행하지 않는다
  ///          (중복 탭 방지)
  ///       2. 마무리 중 상태로 표시하고, `_cleanup()`으로 타이머를
  ///          멈추고 센서에게 그만 보내라고 요청한 뒤 화면 꺼짐
  ///          방지를 끈다
  ///       3. 저장해도 되는 상태인지 확인한다 — 현장 정보(제번 · 층수
  ///          등)가 유효하게 들어있고, 가속도 · 중력 값이 각각 2개
  ///          이상 모였는지 본다. 둘 중 하나라도 아니면 실패 안내를
  ///          띄우고 멈춘다
  ///       4. 시간 간격이 일정하지 않은 원본을 일정한 간격의 표
  ///          (격자)로 정리하고, 각 줄의 진동값(가속도 − 중력)을
  ///          구한다
  ///       5. 결과 파일(집계 · 값 · 원본 사본)을 저장하고, 완료 요약
  ///          대화상자를 띄운다
  ///       6. 저장 중 예상 못 한 오류가 나면 원인을 로그로 남기고
  ///          실패 안내를 띄운다
  Future<void> _finishMeasurement() async {
    if (_isFinishing || _isFinished) return; // 이미 진행 중이면 중복 실행 방지

    if (mounted) {
      setState(() => _isFinishing = true);
    } else {
      _isFinishing = true;
    }
    _isFinished = true;

    await _cleanup(); // → 로직 이동: _cleanup()

    final preGate = _evaluateCaptureGate(); // 저장해도 되는 상태인지
    if (preGate == _CaptureGateResult.siteInvalid) {
      await _showMeasureFailDialog('현장 정보가 없습니다. 홈에서 다시 시작해 주세요.');
      return;
    }
    if (preGate == _CaptureGateResult.noSamples) {
      await _showMeasureFailDialog(
        '센서 데이터가 수집되지 않았습니다.\n기기 지원 여부를 확인한 뒤 다시 측정해 주세요.',
      );
      return;
    }

    final stamp = DateFormat(
      'yyyyMMdd-HHmmss',
    ).format(DateTime.now()); // 파일명에 쓸 시각 문자열
    // → 로직 이동: GridResampler.resample()
    final result = _resampler.resample(); // 격자로 환산한 결과

    try {
      // → 로직 이동: _resolveCaptureDirectory()
      final baseDir = await _resolveCaptureDirectory(); // 저장할 폴더
      final metaPath = '${baseDir.path}/${stamp}_meta.txt'; // 집계 파일 경로

      try {
        // → 로직 이동: VibrationFileWriter.writeMeta()
        await VibrationFileWriter.writeMeta(metaPath, result);
      } catch (e, st) {
        // 집계 파일은 참고용이라 실패해도 저장 자체는 계속 진행한다
        debugPrint('집계 파일 기록 실패: $e\n$st');
      }

      if (!result.isSuccess) {
        await _showMeasureFailDialog(
          '측정 파일 생성에 실패했습니다.\n사유: ${result.failureReason}',
        );
        return;
      }

      final valuePath = '${baseDir.path}/$stamp.txt'; // 값 파일 경로
      // → 로직 이동: VibrationFileWriter.write()
      await VibrationFileWriter.write(valuePath, result);

      // 안드로이드가 저장해둔 원본은 여기와 다른 위치에 자체 시각
      // 이름으로 있다. 이번 측정의 다른 결과 파일(집계 · 값)과 한
      // 폴더에 같은 시각 이름으로 모아두기 위해 복사한다. 원본이
      // 없으면(레코딩 실패 등) 그 사실만 집계 파일에 남겨둔다
      final rawPath =
          _sensorManager.lastRecordPath; // 안드로이드가 저장한 원본 경로, 없으면 null
      final rawCopyPath = '${baseDir.path}/${stamp}_raw.txt'; // 원본 사본 경로
      String? savedRawPath; // 복사해 저장한 원본 경로, 복사 못 했으면 null
      if (rawPath != null) {
        await File(rawPath).copy(rawCopyPath);
        savedRawPath = rawCopyPath;
      } else {
        await File(
          metaPath,
        ).writeAsString('rawRecordPath: null\n', mode: FileMode.append);
      }

      // → 로직 이동: _showCaptureSummaryDialog()
      await _showCaptureSummaryDialog(
        result: result,
        dirPath: baseDir.path,
        valuePath: valuePath,
        metaPath: metaPath,
        rawPath: savedRawPath,
      );
    } catch (e, st) {
      debugPrint('측정 저장 실패: $e\n$st');
      await _showMeasureFailDialog('측정 저장 중 오류가 발생했습니다.\n$e');
    }
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _showCaptureSummaryDialog
  /// 목적: 측정이 끝난 뒤 저장 위치 · 파일 목록과 환산 집계 수치를
  ///       보여주는 대화상자를 띄운다.
  ///       - "메일로 보내기"를 누르면 저장된 파일을 첨부해 메일 작성
  ///         화면을 띄운 뒤 `/start`로 돌아간다
  ///       - "닫기"를 누르면 곧바로 `/start`로 돌아간다
  /// 인자: result — 격자 환산 결과와 집계 수치
  ///       dirPath — 파일이 저장된 폴더 경로
  ///       valuePath — 값 파일 경로
  ///       metaPath — 집계(메타) 파일 경로
  ///       rawPath — 원본 사본 경로, 없으면 null
  Future<void> _showCaptureSummaryDialog({
    required GridResampleResult result,
    required String dirPath,
    required String valuePath,
    required String metaPath,
    required String? rawPath,
  }) async {
    if (!mounted) return;
    final savedFiles = <String>[valuePath, metaPath, ?rawPath]; // 메일 첨부용 전체 경로
    final fileNames = savedFiles
        .map((p) => p.split('/').last)
        .toList(); // 화면 표시용 파일명만
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('측정 완료'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('저장 위치'),
              Text(dirPath, style: AppText.caption),
              const SizedBox(height: AppDims.gap),
              const Text('저장된 파일'),
              for (final name in fileNames) Text('- $name'),
              const SizedBox(height: AppDims.gap),
              Text('행 수: ${result.rowCount}'),
              Text('측정시간(초): ${result.durationSec.toStringAsFixed(1)}'),
              Text('raw 사용 수: ${result.rawUsedCount}'),
              Text('gravity 사용 수: ${result.gravityUsedCount}'),
              Text(
                '폐기(0값, 시각역행): '
                '${result.droppedZeroCount}, ${result.droppedBackwardCount}',
              ),
              Text(
                '잘린 행(시작, 끝): '
                '${result.headTrimmedRows}, ${result.tailTrimmedRows}',
              ),
              Text(
                '최대 간격(raw, gravity): '
                '${result.rawMaxSpanNs ~/ 1000}us, '
                '${result.gravityMaxSpanNs ~/ 1000}us',
              ),
            ],
          ),
        ),
        actions: [
          AppDialogButton(
            label: '메일로 보내기',
            onPressed: () async {
              Navigator.of(ctx).pop();
              // → 로직 이동: showSendEmailSheet()
              await showSendEmailSheet(context, attachmentPaths: savedFiles);
              if (mounted) context.go('/start');
            },
            primary: false,
          ),
          AppDialogButton(
            label: '닫기',
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.go('/start');
            },
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _showExitDialog
  /// 목적: "측정을 중단할까요?" 확인 대화상자를 띄운다. 저장 없이
  ///       중단된다는 것을 함께 알린다.
  /// 반환: 사용자 선택. "중단하기"면 true, "계속 측정"이면 false,
  ///       대화상자 밖을 눌러 닫으면 null
  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('측정 중단', style: AppText.subhead),
        content: Text(
          '측정을 중단할까요?\n진행 중인 측정 데이터는 저장되지 않습니다.',
          style: AppText.body,
        ),
        actions: [
          AppDialogButton(
            label: '계속 측정',
            onPressed: () => Navigator.of(ctx).pop(false),
            primary: false,
          ),
          AppDialogButton(
            label: '중단하기',
            onPressed: () => Navigator.of(ctx).pop(true),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: _confirmAndExit
  /// 목적: 기기 뒤로가기(제스처 · 버튼)를 눌렀을 때와 앱바의 뒤로가기
  ///       버튼을 눌렀을 때, 둘 다 이 함수가 실행된다.
  ///       "측정을 중단할까요?" 확인 대화상자(`_showExitDialog`)를
  ///       띄우고, "중단하기"를 선택하면 타이머를 멈추고 센서 수집을
  ///       끄는 정리(`_cleanup()`)를 한 뒤 이 화면에서 나가 이전
  ///       화면으로 돌아간다.
  Future<void> _confirmAndExit() async {
    final confirm = await _showExitDialog(); // 사용자 선택. true면 중단
    if (confirm == true && context.mounted) {
      _isFinished = true;
      await _cleanup(); // → 로직 이동: _cleanup()
      if (context.mounted) context.pop();
    }
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: build
  /// 목적: 측정 화면을 그린다. 카운트다운 중이면 큰 숫자 카운트다운
  ///       화면을, 아니면 경과 시간과 "테스트 완료" 버튼이 있는 실제
  ///       측정 진행 화면을 보여준다.
  @override
  Widget build(BuildContext context) {
    if (_isCountingDown) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_countdownSec',
                  style: AppText.bigNumber.copyWith(
                    color: AppColors.blue,
                    fontSize: 120,
                  ),
                ),
                const SizedBox(height: AppDims.gap3),
                Text(
                  '잠시 후 측정이 시작됩니다...',
                  style: AppText.subhead.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.text,
                    minimumSize: const Size(200, 64),
                  ),
                  onPressed: () {
                    _countdownTimer?.cancel();
                    if (mounted) {
                      setState(() {
                        _isCountingDown = false;
                      });
                      _initCaptureAndTimers();
                    }
                  },
                  child: const Text('건너뛰기 / 즉시 시작'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final minutes = _elapsedSeconds ~/ 60; // 경과 시간의 분
    final seconds = _elapsedSeconds % 60; // 경과 시간의 나머지 초
    final timeFormatted =
        '$minutes:${seconds.toString().padLeft(2, '0')}'; // 화면에 보여줄 "분:초"

    return PopScope(
      // `PopScope`(기기 뒤로가기 제스처·버튼을 가로채는 위젯(widget,
      // 화면을 이루는 구성 요소 하나하나를 부르는 말))로, 확인 없이
      // 곧바로 화면을 나가지 못하게 막는다
      canPop: false, // 기본 뒤로가기 동작을 막는다 — 직접 처리해야 나갈 수 있다
      onPopInvokedWithResult: (didPop, _) async {
        // 기기 뒤로가기를 눌렀을 때 실행된다. didPop이 이미 true면
        // (다른 경로로 이미 나간 뒤라는 뜻) 더 할 일이 없다
        if (didPop) return;
        // 앱바의 뒤로가기 버튼(아래 `leading`)도 같은 함수를 부른다
        // → 로직 이동: _confirmAndExit()
        await _confirmAndExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.navy,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: Semantics(
            button: true,
            label: '뒤로가기',
            child: SizedBox(
              width: AppDims.touchMin,
              height: AppDims.touchMin,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: Colors.white,
                ),
                onPressed: _confirmAndExit, // → 로직 이동: _confirmAndExit()
              ),
            ),
          ),
          title: Text(
            '테스트 진행 중...',
            style: AppText.subhead.copyWith(color: Colors.white),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDims.screenPad,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '측정 중',
                          style: AppText.bodyBold.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // 걸린 시간 섹션
                        Text(
                          '걸린 시간',
                          style: AppText.bodyBold.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: AppDims.gap),
                        Text(
                          timeFormatted,
                          style: AppText.bigNumber.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 경고 배너 (빨간 배경 + 손 모양 아이콘 + 안내 문구)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDims.screenPad,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppDims.gap2),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(AppDims.radius),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.front_hand_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: AppDims.gap2),
                      Expanded(
                        child: Text(
                          '테스트가 진행되는 동안 휴대폰을 들어 올리지 마세요',
                          style: AppText.bodyBold.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDims.gap2),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDims.screenPad),
            child: ElevatedButton(
              onPressed: _isFinishing ? null : _finishMeasurement,
              child: Text(_isFinishing ? '종료 중...' : '테스트 완료'),
            ),
          ),
        ),
      ),
    );
  }
}
