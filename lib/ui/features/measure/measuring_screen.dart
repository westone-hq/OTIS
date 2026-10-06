import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:vibration_checker/adapter/capture_session.dart';
import 'package:vibration_checker/adapter/measurement_recorder.dart';
import 'package:vibration_checker/adapter/sensor_channel.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_layout.dart';
import '../../core/widgets/app_notice.dart';
import 'record_failure_message.dart';

/// 작성: 2026-08-18 18:17:48 · 박건준
/// 수정: 2026-10-04 13:33:18 · nada
/// 클래스: MeasuringScreen
/// 목적: 측정이 진행되는 동안 보여주는 라이브 화면.
///       - 멀리서도 보이게 경과 시간을 크게 표시한다
///       - 어르신도 잘 보이도록 어두운 남색 배경에 밝은 글자, 56dp 이상의
///         버튼을 쓴다
///       센서 수집 절차는 `CaptureSession`(capture_session.dart), 저장
///       절차는 `MeasurementRecorder`(measurement_recorder.dart)가 맡고,
///       이 화면은 시간 표시 · 안내 · 대화상자만 맡는다.
class MeasuringScreen extends StatefulWidget {
  /// 센서 통로를 바꿔 끼울 때 넘기는 값. null 이면 `CaptureSession` 이
  /// 실제 `SensorChannelManager`(안드로이드 쪽 센서와 주고받는 통신을
  /// 담당하는 클래스)를 새로 만들어 쓴다
  final SensorChannelManager? sensorManager;

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 함수: MeasuringScreen
  /// 목적: 측정 화면을 만든다.
  /// 인자: sensorManager — 바꿔 끼울 센서 통로. 보통은 넘기지 않는다
  const MeasuringScreen({super.key, this.sensorManager});

  @override
  State<MeasuringScreen> createState() => _MeasuringScreenState();
}

/// 작성: 2026-08-18 18:17:48 · 박건준
/// 수정: 2026-10-04 16:54:15 · nada
/// 클래스: _MeasuringScreenState
/// 목적: 라이브 측정 화면의 상태를 관리한다. 경과 시간 · 카운트다운
///       타이머와, 앱이 백그라운드로 전환됐을 때의 중단 처리를 맡는다.
class _MeasuringScreenState extends State<MeasuringScreen>
    with WidgetsBindingObserver {
  /// 이번 측정의 센서 수집. 화면이 처음 쓸 때 만든다
  late final CaptureSession _capture = CaptureSession(
    sensorManager: widget.sensorManager,
  );

  /// 경과 시간(`_elapsedSeconds`)을 1초마다 하나씩 올리는 타이머.
  /// `_initCaptureAndTimers()`가 만들고, `_cleanup()`이 멈춘 뒤 비운다.
  /// 아직 시작 전이거나 이미 정리됐으면 null
  Timer? _timeTimer;

  /// 측정이 시작된 뒤 지난 시간(초). `_timeTimer`가 1초마다 1씩
  /// 올리고, 화면에는 "분:초" 형태로 바꿔 보여준다
  int _elapsedSeconds = 0;

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

  /// 측정이 끝났는지 여부. 저장을 시작할 때(`_finishMeasurement()`),
  /// 센서 무응답으로 중단됐을 때(`_onNoResponse()`), 사용자가
  /// 뒤로가기로 중단했을 때(`_confirmAndExit()`) 전부 true가 된다.
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
  /// 수정: 2026-10-04 18:15:24 · nada
  /// 함수: _initCaptureAndTimers
  /// 목적: 카운트다운이 끝난 뒤(또는 대기 시간이 없으면 곧바로) 경과
  ///       시간 타이머를 켜고 센서 수집을 시작한다. 볼륨키는 카운트다운 ·
  ///       마무리 중에는 무시한다.
  Future<void> _initCaptureAndTimers() async {
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });

    // → 로직 이동: CaptureSession.start()
    await _capture.start(
      onVolumeKey: () {
        if (!_isCountingDown && !_isFinishing && !_isFinished) {
          unawaited(_finishMeasurement()); // → 로직 이동: _finishMeasurement()
        }
      },
      onNoResponse: _onNoResponse, // → 로직 이동: _onNoResponse()
    );
  }

  /// 작성: 2026-10-04 13:33:18 · nada
  /// 함수: _onNoResponse
  /// 목적: 수집을 시작했는데 센서 값이 한 번도 오지 않았을 때
  ///       `CaptureSession` 이 부른다. 측정을 끝난 것으로 표시하고 정리한
  ///       뒤, 수집 시작 요청이 실패한 원인이 있으면 덧붙여 실패 안내를
  ///       띄운다. 저장하지 않는 측정이라 안드로이드 원본도 지운다.
  Future<void> _onNoResponse() async {
    if (!mounted) return;
    _isFinished = true;
    await _cleanup(discardRecord: true); // → 로직 이동: _cleanup()
    final cause = _capture.lastCaptureError; // 실패 원인 문구, 없으면 null
    const message = '센서 응답이 없습니다. 측정을 중단합니다.'; // 기본 안내 문구
    // → 로직 이동: _showMeasureFailDialog()
    await _showMeasureFailDialog(cause == null ? message : '$message\n$cause');
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 수정: 2026-10-07 03:30:18 · nada
  /// 함수: _cleanup
  /// 목적: 화면 타이머 두 개(경과 시간, 카운트다운)를 멈추고 센서 수집을
  ///       정리한다. 측정을 중단하거나 끝낼 때, 화면이 사라질 때 등 여러
  ///       곳에서 공통으로 부른다. 수집 정리의 순서와 시간 한도는
  ///       `CaptureSession.stop()` 이 지킨다.
  ///       저장하지 않는 중단이면 안드로이드 원본 기록까지 지운다
  ///       (`CaptureSession.discard()`). 저장하는 마무리는 원본을
  ///       `MeasurementRecorder.record()` 가 측정 폴더로 옮겨야 하므로
  ///       지우지 않는다.
  /// 인자: discardRecord — true 면 저장하지 않는 중단이라 원본을 지운다
  Future<void> _cleanup({bool discardRecord = false}) async {
    _timeTimer?.cancel();
    _countdownTimer?.cancel();
    _timeTimer = null;
    _countdownTimer = null;
    if (discardRecord) {
      await _capture.discard(); // → 로직 이동: CaptureSession.discard()
    } else {
      await _capture.stop(); // → 로직 이동: CaptureSession.stop()
    }
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 수정: 2026-10-07 03:30:18 · nada
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
  ///       - 측정을 마무리하지 않은 채 사라지면 저장하지 않는 중단이라
  ///         안드로이드 원본도 지운다
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // → 로직 이동: _cleanup()
    unawaited(_cleanup(discardRecord: !_isFinished));
    super.dispose();
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 수정: 2026-10-07 03:30:18 · nada
  /// 함수: didChangeAppLifecycleState
  /// 목적: 앱이 화면 밖으로 밀려나거나(전화 수신, 홈 버튼 등) 다시
  ///       돌아올 때 Flutter가 불러주는 함수다. 측정 중 앱이 밀려나면
  ///       측정을 중단하고, 다시 돌아오면 중단됐었다는 안내를 띄운다.
  ///       - `paused`(화면이 안 보이게 됨) 상태고, 아직 측정이 끝나지도
  ///         이미 중단되지도 않았으면 측정을 정리하고 중단 상태로 표시한다.
  ///         저장하지 않는 중단이라 안드로이드 원본도 지운다
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
      // → 로직 이동: _cleanup()
      unawaited(_cleanup(discardRecord: true));
      _measurementAborted = true;
    } else if (state == AppLifecycleState.resumed && _measurementAborted) {
      _showAbortedDialog(); // → 로직 이동: _showAbortedDialog()
    }
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 수정: 2026-10-04 18:26:41 · nada
  /// 함수: _showAbortedDialog
  /// 목적: 측정 중 전화가 오는 등 앱이 화면 밖으로 밀려나면 측정이
  ///       중단된다. 앱으로 다시 돌아왔을 때, 이 대화상자로 측정이
  ///       중단됐었다는 사실을 알려준다(`didChangeAppLifecycleState`
  ///       에서 부름). "확인"을 누르면 이 화면을 닫고 측정을 시작한
  ///       화면(시작 화면 또는 결과 화면을 열었던 곳)으로 돌아간다.
  ///       화면이 이미 사라졌으면(`mounted`가 false) 아무것도 하지
  ///       않는다.
  Future<void> _showAbortedDialog() async {
    if (!mounted) return;
    // → 로직 이동: showAppConfirmDialog()
    await showAppConfirmDialog(
      context,
      title: '측정이 중단되었습니다',
      message:
          '측정 중 앱이 백그라운드로 전환되어(전화 수신 등) 측정을 중단했습니다. '
          '처음부터 다시 측정해 주세요.',
      confirmLabel: '확인',
    );
    if (mounted) context.pop(); // 측정을 시작한 화면으로 돌아간다
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 수정: 2026-10-04 18:26:41 · nada
  /// 함수: _showMeasureFailDialog
  /// 목적: 측정 실패를 알리는 대화상자를 띄운다. "확인"을 누르면 이
  ///       화면을 닫고 측정을 시작한 화면으로 돌아간다. 화면 기록을 통째로
  ///       바꾸지 않아야 그곳에서 뒤로 가기로 홈까지 돌아갈 수 있다. 화면이
  ///       이미 사라졌으면(`mounted`가 false) 아무것도 하지 않는다.
  /// 인자: message — 실패 사유를 보여줄 문구
  Future<void> _showMeasureFailDialog(String message) async {
    if (!mounted) return;
    // → 로직 이동: showAppConfirmDialog()
    await showAppConfirmDialog(
      context,
      title: '측정 실패',
      message: message,
      confirmLabel: '확인',
    );
    if (mounted) context.pop(); // 측정을 시작한 화면으로 돌아간다
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 수정: 2026-10-04 18:15:24 · nada
  /// 함수: _finishMeasurement
  /// 목적: "테스트 완료" 버튼이나 볼륨키로 측정을 마무리한다. 순서대로
  ///       진행한다.
  ///       1. 이미 마무리 중이거나 끝났으면 다시 실행하지 않는다
  ///          (중복 탭 방지)
  ///       2. 마무리 중 상태로 표시하고 `_cleanup()`으로 타이머와 센서
  ///          수집을 멈춘다
  ///       3. `MeasurementRecorder.record()` 로 저장한다
  ///       4. 실패면 사유를 담은 실패 안내를 띄우고, 성공이면 이 화면을
  ///          결과 화면으로 바꾼다. 결과 화면에서 뒤로 가면 측정을 시작한
  ///          화면(시작 화면 또는 저장 결과 목록)이다
  Future<void> _finishMeasurement() async {
    if (_isFinishing || _isFinished) return; // 이미 진행 중이면 중복 실행 방지

    if (mounted) {
      setState(() => _isFinishing = true);
    } else {
      _isFinishing = true;
    }
    _isFinished = true;

    await _cleanup(); // → 로직 이동: _cleanup()

    // → 로직 이동: MeasurementRecorder.record()
    final outcome = await MeasurementRecorder.record(
      resampler: _capture.resampler,
      site: MeasurementSession.instance.currentSite,
      nativeRecordPath: _capture.nativeRecordPath,
      measuredAt: DateTime.now(),
    ); // 저장 결과
    if (!outcome.isSuccess) {
      // → 로직 이동: recordFailureMessage()
      final message = recordFailureMessage(
        outcome,
        minimumRecordMs: _capture.resampler.config.minimumRecordMs,
      ); // 실패 대화상자 문구
      // → 로직 이동: _showMeasureFailDialog()
      await _showMeasureFailDialog(message);
      return;
    }
    if (!mounted) return;
    // → 로직 이동: ResultScreen.build()
    context.pushReplacement('/result/${outcome.id}');
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 수정: 2026-10-07 03:30:18 · nada
  /// 함수: _confirmAndExit
  /// 목적: 기기 뒤로가기(제스처 · 버튼)를 눌렀을 때와 앱바의 뒤로가기
  ///       버튼을 눌렀을 때, 둘 다 이 함수가 실행된다.
  ///       저장 없이 중단된다는 것을 알리는 확인 대화상자를 띄우고,
  ///       "중단하기"를 선택하면 타이머를 멈추고 센서 수집을
  ///       끄는 정리(`_cleanup()`)를 한 뒤 이 화면에서 나가 이전
  ///       화면으로 돌아간다. 저장하지 않으므로 안드로이드 원본도 지운다.
  ///       대화상자를 기다리는 사이에 화면이 사라질 수 있으므로, 기다린
  ///       뒤에는 매번 이 화면이 아직 살아 있는지 보고 움직인다. 화면이
  ///       가진 `mounted` 를 보는 이유는 `context.mounted` 가 화면이
  ///       아니라 그 자리의 위젯만 살폈다고 보고 분석기가 경고하기
  ///       때문이다 — 여기서는 화면 자체가 사라졌는지가 알고 싶은 것이다.
  Future<void> _confirmAndExit() async {
    // → 로직 이동: showAppConfirmDialog()
    final confirm = await showAppConfirmDialog(
      context,
      title: '측정 중단',
      message: '측정을 중단할까요?\n진행 중인 측정 데이터는 저장되지 않습니다.',
      confirmLabel: '중단하기',
      cancelLabel: '계속 측정',
      isDestructive: true,
      barrierDismissible: true,
    ); // 사용자 선택. true 면 중단
    if (confirm && mounted) {
      _isFinished = true;
      await _cleanup(discardRecord: true); // → 로직 이동: _cleanup()
      if (mounted) context.pop();
    }
  }

  /// 작성: 2026-08-18 18:17:48 · 박건준
  /// 수정: 2026-10-04 16:54:15 · nada
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
                Text('$_countdownSec', style: AppText.countdown),
                const SizedBox(height: AppDims.gap3),
                Text(
                  '잠시 후 측정이 시작됩니다...',
                  style: AppText.subhead.copyWith(color: AppColors.onDark),
                ),
                const SizedBox(height: AppDims.gap6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.text,
                    minimumSize: const Size(
                      AppDims.wideButtonW,
                      AppDims.buttonH,
                    ),
                  ),
                  onPressed: () {
                    _countdownTimer?.cancel();
                    if (mounted) {
                      setState(() {
                        _isCountingDown = false;
                      });
                      // → 로직 이동: _initCaptureAndTimers()
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
          foregroundColor: AppColors.onDark,
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
                  size: AppDims.iconM,
                  color: AppColors.onDark,
                ),
                onPressed: _confirmAndExit, // → 로직 이동: _confirmAndExit()
              ),
            ),
          ),
          title: Text(
            '테스트 진행 중...',
            style: AppText.subhead.copyWith(color: AppColors.onDark),
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
                            color: AppColors.onDarkSub,
                          ),
                        ),
                        const SizedBox(height: AppDims.gap5),

                        // 걸린 시간 섹션
                        Text(
                          '걸린 시간',
                          style: AppText.bodyBold.copyWith(
                            color: AppColors.onDarkSub,
                          ),
                        ),
                        const SizedBox(height: AppDims.gap),
                        Text(
                          timeFormatted,
                          style: AppText.bigNumber.copyWith(
                            color: AppColors.onDark,
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
                child: AppNotice(
                  icon: Icons.front_hand_outlined,
                  message: '측정 중입니다.\n휴대폰을 움직이지 마세요.\n볼륨키를 누르면 측정이 종료됩니다.',
                  tone: NoticeTone.alert,
                ),
              ),
              const SizedBox(height: AppDims.gap2),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          child: ElevatedButton(
            // → 로직 이동: _finishMeasurement()
            onPressed: _isFinishing ? null : _finishMeasurement,
            child: Text(_isFinishing ? '종료 중...' : '테스트 완료'),
          ),
        ),
      ),
    );
  }
}
