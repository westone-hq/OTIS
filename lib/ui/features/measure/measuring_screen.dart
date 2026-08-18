// 작성: 2026-08-18 18:17:48
// 작성자: 박건준

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

/// 측정을 저장해도 되는지 판정한 결과. ok(저장 가능),
/// siteInvalid(현장 정보 누락 · 오류), noSamples(유효 샘플 부족)
enum _CaptureGateResult { ok, siteInvalid, noSamples }

/// 클래스: _MeasuringScreenState
/// 목적: 라이브 측정 화면의 상태를 관리한다. 센서 데이터 수집, 경과
///       시간 · 카운트다운 타이머, 앱이 백그라운드로 전환됐을 때의
///       중단 처리를 담당한다.
class _MeasuringScreenState extends State<MeasuringScreen>
    with WidgetsBindingObserver {
  late final SensorChannelManager _sensorManager =
      widget.sensorManager ?? SensorChannelManager();
  Timer? _timeTimer;
  Timer? _releaseTimeoutTimer;
  StreamSubscription<NativeEvent>? _sensorSub;

  int _elapsedSeconds = 0;
  bool _receivedRealSample = false;

  static const CaptureConfig _captureConfig = CaptureConfig();
  final GridResampler _resampler = GridResampler(config: _captureConfig);
  int _countdownSec = 0;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  bool _measurementAborted = false;
  bool _isFinished = false;
  bool _isFinishing = false;

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
    final delay = MeasurementSession.instance.delaySec; // 시작 전 대기 시간 (초)
    if (delay > 0) {
      _countdownSec = delay;
      _isCountingDown = true;
      _startCountdown(); // → 로직 이동: _startCountdown()
    } else {
      _initCaptureAndTimers(); // → 로직 이동: _initCaptureAndTimers()
    }
  }

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

  /// 함수: _initCaptureAndTimers
  /// 목적: 카운트다운이 끝난 뒤(또는 대기 시간이 없으면 곧바로) 실제
  ///       측정을 준비하고 시작한다. 순서대로 다섯 단계를 거친다.
  ///       1. 화면이 꺼지지 않도록 화면 꺼짐 방지를 켠다. 100ms 안에
  ///          응답이 없어도 그냥 넘어간다 — 느려도 측정 자체를
  ///          막지 않는다
  ///       2. 마이크 권한을 요청한다. 거부돼도 진동 측정은 계속하고,
  ///          결과에서 소음 항목만 "해당 없음"으로 표시한다
  ///       3. 1초마다 경과 시간을 올리는 타이머를 시작한다
  ///       4. 센서가 실제로 있는지 확인하고, 있으면(가짜 모드가
  ///          아니면) 측정을 시작해 센서 데이터를 구독한다
  ///       5. 3초 안에 센서 데이터가 하나도 안 오면 측정을 중단하고
  ///          실패 안내를 띄운다. 개발용 빌드와 실제 배포판이 똑같이
  ///          동작해야, 이 문제를 개발 중에 미리 발견할 수 있다
  Future<void> _initCaptureAndTimers() async {
    // 1) 화면 꺼짐 방지
    try {
      await WakelockPlus.enable()
          .timeout(const Duration(milliseconds: 100))
          .catchError((_) {});
    } catch (_) {}

    // 2) 오디오 권한 요청 (거부해도 진동 측정은 계속 진행)
    // → 로직 이동: SensorChannelManager.requestAudioPermission()
    await _sensorManager.requestAudioPermission();

    // 3) 경과 시간 카운트 (1초 간격)
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });

    // 4) 센서 가용성 확인 후 있으면 측정 시작 및 데이터 구독
    // → 로직 이동: SensorChannelManager.checkSensorsAvailable()
    final bool available = await _sensorManager.checkSensorsAvailable();
    if (available && !_sensorManager.useMock) {
      // → 로직 이동: SensorChannelManager.startCapture()
      await _sensorManager.startCapture();
      _sensorSub = _sensorManager.nativeEventStream.listen((event) {
        _receivedRealSample = true;
        _resampler.onEvent(event);
      });
    }

    // 5) 3초간 센서 응답이 없으면 측정을 포기하고 되돌아간다 (저장 없음)
    _releaseTimeoutTimer = Timer(const Duration(seconds: 3), () async {
      if (mounted && !_receivedRealSample) {
        _isFinished = true;
        await _cleanup(); // → 로직 이동: _cleanup()
        final cause = _sensorManager.lastCaptureError; // 실패 원인 문구, 없으면 null
        final message = cause == null
            ? '센서 응답이 없습니다. 측정을 중단합니다.'
            : '센서 응답이 없습니다. 측정을 중단합니다.\n$cause';
        await _showMeasureFailDialog(
          message,
        ); // → 로직 이동: _showMeasureFailDialog()
      }
    });
  }

  Future<void> _cleanup() async {
    _timeTimer?.cancel();
    _countdownTimer?.cancel();
    _releaseTimeoutTimer?.cancel();
    _timeTimer = null;
    _countdownTimer = null;
    _releaseTimeoutTimer = null;
    final sensorSub = _sensorSub;
    _sensorSub = null;
    // 순서 고정: stopCapture 가 네이티브 잔여 배치를 flush 하므로 먼저 부른다.
    // 구독을 먼저 끊으면 onCancel 이 eventSink 를 비워 잔여분이 버려진다.
    await _ignoreSlowCleanup(_sensorManager.stopCapture());
    // 잔여 배치는 네이티브 메인 루퍼에 post 되어 stopCapture 응답 이후 도착한다.
    // 도착 대기 없이 구독을 끊으면 같은 유실이 재발한다.
    await Future.delayed(const Duration(milliseconds: 300));
    if (sensorSub != null) {
      await _ignoreSlowCleanup(sensorSub.cancel());
    }
    try {
      await WakelockPlus.disable().timeout(const Duration(milliseconds: 200));
    } catch (_) {}
  }

  Future<void> _ignoreSlowCleanup(Future<void> future) async {
    try {
      await future.timeout(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cleanup());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused &&
        !_isFinished &&
        !_measurementAborted) {
      unawaited(_cleanup());
      _measurementAborted = true;
    } else if (state == AppLifecycleState.resumed && _measurementAborted) {
      _showAbortedDialog();
    }
  }

  /// 백그라운드 전환으로 인한 측정 중단 시 안내 다이얼로그 표시 후 /start 이동
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

  /// 목적: 현장 정보와 층수 파싱이 유효한지 확인한다.
  /// 인자: 없음 (MeasurementSession 의 현재 현장 정보를 본다)
  /// 반환: 현장 정보가 있고 시작·도착 층이 정수로 파싱되면 true
  bool _hasValidSite() {
    final site = MeasurementSession.instance.currentSite;
    if (site == null) return false;
    return int.tryParse(site.bottomFloor) != null &&
        int.tryParse(site.topFloor) != null;
  }

  /// 목적: 계측 시작·종료 전 진행 가능 여부를 판정한다.
  /// 인자: 없음 (현장 정보와 리샘플러 누적 수를 본다)
  /// 반환: 진행 가능하면 ok, 현장 정보 누락이면 siteInvalid,
  ///       raw 또는 gravity 유효 샘플이 2개 미만이면 noSamples
  _CaptureGateResult _evaluateCaptureGate() {
    if (!_hasValidSite()) return _CaptureGateResult.siteInvalid;
    if (_resampler.rawCount < 2 || _resampler.gravityCount < 2) {
      return _CaptureGateResult.noSamples;
    }
    return _CaptureGateResult.ok;
  }

  /// 현장 정보 누락 또는 센서 샘플 부족 시 실패 안내 다이얼로그 표시 후 /start 이동
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

  /// 목적: 이번 측정 산출물을 저장할 디렉터리를 확보한다.
  /// 인자: 없음
  /// 반환: 생성이 보장된 저장 디렉터리
  Future<Directory> _resolveCaptureDirectory() async {
    return MeasurementRepository.instance.getBaseDirectory();
  }

  /// 측정 종료 시 안전장치 게이트 평가, 격자 환산, 파일 저장, 요약 다이얼로그 표시를 수행합니다.
  Future<void> _finishMeasurement() async {
    if (_isFinishing || _isFinished) return;
    if (mounted) {
      setState(() => _isFinishing = true);
    } else {
      _isFinishing = true;
    }
    _isFinished = true;
    await _cleanup();

    final preGate = _evaluateCaptureGate();
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

    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final result = _resampler.resample();

    try {
      final baseDir = await _resolveCaptureDirectory();
      final metaPath = '${baseDir.path}/${stamp}_meta.txt';

      try {
        await VibrationFileWriter.writeMeta(metaPath, result);
      } catch (e, st) {
        debugPrint('집계 파일 기록 실패: $e\n$st');
      }

      if (!result.isSuccess) {
        await _showMeasureFailDialog(
          '측정 파일 생성에 실패했습니다.\n사유: ${result.failureReason}',
        );
        return;
      }

      final valuePath = '${baseDir.path}/$stamp.txt';
      await VibrationFileWriter.write(valuePath, result);

      final rawPath = _sensorManager.lastRecordPath;
      final rawCopyPath = '${baseDir.path}/${stamp}_raw.txt';
      String? savedRawPath;
      if (rawPath != null) {
        await File(rawPath).copy(rawCopyPath);
        savedRawPath = rawCopyPath;
      } else {
        await File(
          metaPath,
        ).writeAsString('rawRecordPath: null\n', mode: FileMode.append);
      }

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

  /// 측정 완료 후 저장된 파일 목록과 격자 환산 집계를 보여주고,
  /// 메일 발송 또는 시작 화면 복귀로 이어주는 다이얼로그 표시
  Future<void> _showCaptureSummaryDialog({
    required GridResampleResult result,
    required String dirPath,
    required String valuePath,
    required String metaPath,
    required String? rawPath,
  }) async {
    if (!mounted) return;
    final savedFiles = <String>[valuePath, metaPath, ?rawPath];
    final fileNames = savedFiles.map((p) => p.split('/').last).toList();
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

  /// 사용자 뒤로가기/종료 요청 시 확인 다이얼로그 표시
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

    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    final timeFormatted = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await _showExitDialog();
        if (confirm == true && context.mounted) {
          _isFinished = true;
          await _cleanup();
          if (context.mounted) context.pop();
        }
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
                onPressed: () async {
                  final confirm = await _showExitDialog();
                  if (confirm == true && context.mounted) {
                    _isFinished = true;
                    await _cleanup();
                    if (context.mounted) context.pop();
                  }
                },
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
