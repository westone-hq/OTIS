import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme.dart';
import '../../domain/measure/metrics_config.dart';
import '../../domain/measure/measurement_engine.dart';
import '../../domain/sensor_channel.dart';
import '../../domain/repository/measurement_repository.dart';
import '../../domain/models/measurement_result.dart';
import '../shared/measurement_session.dart';
import '../../core/widgets/app_dialog.dart';

/// S4 측정 중 (라이브)
/// - 실시간 속도 및 경과 시간 표시. 멀리서도 읽히게 초대형 UI
/// - 어르신 UX: 대비 높은 Navy 어두운 배경, 72sp 속도 표시, 56dp+ 확인 버튼
class MeasuringScreen extends StatefulWidget {
  final SensorChannelManager? sensorManager;
  const MeasuringScreen({super.key, this.sensorManager});

  /// 측정 결과 파일을 로컬 디스크(repository)에 저장하고 성공 여부를 반환합니다.
  @visibleForTesting
  static Future<bool> attemptSave(
    MeasurementResult result, {
    void Function(Directory)? onSuccess,
    String? nativeRawPath,
  }) async {
    try {
      final dir = await MeasurementRepository.instance.save(
        result,
        nativeRawPath: nativeRawPath,
      );
      onSuccess?.call(dir);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  State<MeasuringScreen> createState() => _MeasuringScreenState();
}

/// S4 측정 저장 전 검증 게이트 판정 결과
enum _SaveGateResult { ok, siteInvalid, noSamples, lowMotion }

/// 라이브 측정 화면의 상태 및 생명주기(센서 수집, 타이머, 백그라운드 전환 등)를 관리합니다.
class _MeasuringScreenState extends State<MeasuringScreen>
    with WidgetsBindingObserver {
  late final SensorChannelManager _sensorManager =
      widget.sensorManager ?? SensorChannelManager();
  Timer? _timeTimer;
  Timer? _uiTimer;
  Timer? _mockFallbackTimer;
  Timer? _releaseTimeoutTimer;
  StreamSubscription<double>? _speedSub;
  StreamSubscription<SensorSample>? _sensorSub;

  int _elapsedSeconds = 0;
  double _currentSpeed = 0.00;
  bool _receivedRealSample = false;
  double _signedVelocity = 0.0;
  double _baselineSumZ = 0.0;
  int _baselineCount = 0;
  double _baselineZ = 0.0;
  int _lastTsUs = 0;

  final MeasurementEngine _engine = MeasurementEngine();
  int _countdownSec = 0;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  bool _measurementAborted = false;
  bool _isFinished = false;
  bool _isFinishing = false;
  /// 보간 전 원본 덤프(임시 파일) 경로 — stopCapture 시 수신
  String? _nativeRawPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final delay = MeasurementSession.instance.delaySec;
    if (delay > 0) {
      _countdownSec = delay;
      _isCountingDown = true;
      _startCountdown();
    } else {
      _initCaptureAndTimers();
    }
  }

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
          _initCaptureAndTimers();
        }
      });
    });
  }

  Future<void> _initCaptureAndTimers() async {
    // 1. wakelock 활성화 (D2, Phase 2)
    try {
      await WakelockPlus.enable()
          .timeout(const Duration(milliseconds: 100))
          .catchError((_) {});
    } catch (_) {}

    // 2. 오디오 권한 요청 (거부 시 소음 N/A 처리용 안내)
    final bool audioGranted = await _sensorManager.requestAudioPermission();
    if (!audioGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '소음 제외 측정: 마이크 권한이 거부되어 진동만 측정합니다. (결과에 소음 N/A 표기)\n권한 요청 창이 다시 나타나지 않으면 휴대폰 설정 > 애플리케이션 > OTIS 진동측정 > 권한에서 마이크를 허용해 주세요.',
            style: AppText.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // 3. 경과 시간 카운트 (1초 간격)
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });

    // 4. UI 갱신 스로틀링 (150ms 주기 setState - 50Hz 과부하 해소)
    _uiTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      if (_receivedRealSample) {
        setState(() {
          _currentSpeed = _elapsedSeconds < 1 ? 0.00 : _signedVelocity.abs();
        });
      }
    });

    // 5. 센서 가용성 검증 및 단일 스트림 명시적 구독
    final bool available = await _sensorManager.checkSensorsAvailable();
    if (available && !_sensorManager.useMock) {
      await _sensorManager.startCapture(
        targetSampleRate: 256,
        micDbfsToDbaOffset: MetricsConfig.defaultConfig.micDbfsToDbaOffset,
      );
      _sensorSub = _sensorManager.sensorStream.listen((sample) {
        if (sample.tsUs > 0) {
          _receivedRealSample = true;
          _engine.addSamples([sample]);
          // 첫 1초간 Z축 baseline 보정 수집
          if (_elapsedSeconds < 1) {
            _baselineSumZ += sample.z;
            _baselineCount++;
            _baselineZ = _baselineCount > 0
                ? _baselineSumZ / _baselineCount
                : 0.0;
            _signedVelocity = 0.0;
          } else {
            final double dt = (_lastTsUs > 0 && sample.tsUs > _lastTsUs)
                ? (sample.tsUs - _lastTsUs) / 1000000.0
                : (1.0 / 256.0);
            final double aZ =
                (sample.z - _baselineZ) *
                SensorSample.mgToMetersPerSecondSquared;
            _signedVelocity = (_signedVelocity + aZ * dt).clamp(-3.0, 3.0);
          }
          _lastTsUs = sample.tsUs;
        }
      });

      // 1초 후에도 실제 콜백이 전혀 없다면 mock 스트림으로 폴백 (디버그 모드 전용)
      if (kDebugMode) {
        _mockFallbackTimer = Timer(const Duration(seconds: 1), () {
          if (mounted && !_receivedRealSample && _speedSub == null) {
            _subscribeMockStream();
          }
        });
      }
    } else {
      if (kDebugMode) {
        _subscribeMockStream();
      }
    }

    // 릴리즈 경로: 3초간 수신 없으면 측정 중단 및 복귀 (저장 없음)
    if (!kDebugMode) {
      _releaseTimeoutTimer = Timer(const Duration(seconds: 3), () async {
        if (mounted && !_receivedRealSample) {
          _isFinished = true;
          await _cleanup();
          await _showMeasureFailDialog('센서 응답이 없습니다. 측정을 중단합니다.');
        }
      });
    }
  }

  void _subscribeMockStream() {
    _speedSub?.cancel();
    _speedSub = _mockSpeedStream().listen((speed) {
      if (mounted && !_receivedRealSample) {
        setState(() => _currentSpeed = speed);
      }
    });
  }

  Stream<double> _mockSpeedStream() {
    return Stream.periodic(const Duration(milliseconds: 100), (count) {
      // 0.00에서 시작해 약 3초(30회) 동안 1.50 m/s까지 가속
      if (count < 30) {
        return (count * 0.05).clamp(0.0, 1.50);
      } else {
        // 1.50 유지 (미세한 0.01 변동으로 라이브 느낌 부여)
        final noise = (math.Random().nextDouble() - 0.5) * 0.02;
        return (1.50 + noise).clamp(1.48, 1.52);
      }
    });
  }

  Future<void> _cleanup() async {
    _timeTimer?.cancel();
    _uiTimer?.cancel();
    _countdownTimer?.cancel();
    _mockFallbackTimer?.cancel();
    _releaseTimeoutTimer?.cancel();
    _timeTimer = null;
    _uiTimer = null;
    _countdownTimer = null;
    _mockFallbackTimer = null;
    _releaseTimeoutTimer = null;
    final speedSub = _speedSub;
    final sensorSub = _sensorSub;
    _speedSub = null;
    _sensorSub = null;
    await Future.wait<void>([
      if (speedSub != null) _ignoreSlowCleanup(speedSub.cancel()),
      if (sensorSub != null) _ignoreSlowCleanup(sensorSub.cancel()),
    ]);
    try {
      final path = await _sensorManager
          .stopCapture()
          .timeout(const Duration(milliseconds: 2000));
      if (path != null && path.isNotEmpty) {
        _nativeRawPath = path;
      }
    } catch (_) {}
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

  /// 현장 정보 및 층수 파싱 유효성 검증
  ({SiteInfo site, int bottomFloor, int topFloor})? _validateSite() {
    final site = MeasurementSession.instance.currentSite;
    if (site == null) return null;
    final bottomFloor = int.tryParse(site.bottomFloor);
    final topFloor = int.tryParse(site.topFloor);
    if (bottomFloor == null || topFloor == null) return null;
    return (site: site, bottomFloor: bottomFloor, topFloor: topFloor);
  }

  /// 타당성 게이트 (측정 시간, 최대 속도, 운행 거리) 및 샘플/현장 정보 유효성 평가
  _SaveGateResult _evaluateSaveGate(MeasurementResult? result) {
    if (_validateSite() == null) {
      return _SaveGateResult.siteInvalid;
    }
    if (_engine.sampleCount < 2) {
      return _SaveGateResult.noSamples;
    }
    if (result == null) {
      return _SaveGateResult.ok;
    }
    if (_elapsedSeconds < MetricsConfig.defaultConfig.minMeasureDurationSec ||
        result.maxSpeed < MetricsConfig.defaultConfig.minValidMaxSpeed ||
        result.distance < MetricsConfig.defaultConfig.minValidDistance) {
      return _SaveGateResult.lowMotion;
    }
    return _SaveGateResult.ok;
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

  /// 승강기 움직임 미감지 시 사용자 선택 다이얼로그 표시
  /// - 반환값: true([그래도 저장]), false/null([다시 측정] 또는 닫기)
  Future<bool?> _showLowMotionDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('승강기 움직임이 감지되지 않았습니다'),
        content: const Text(
          '측정 시간이 짧거나 이동이 거의 없습니다. 폰을 카 바닥에 두고 승강기를 운행한 뒤 완료를 눌러 주세요.',
        ),
        actions: [
          AppDialogButton(
            label: '그래도 저장',
            onPressed: () => Navigator.of(ctx).pop(true),
            primary: false,
          ),
          AppDialogButton(
            label: '다시 측정',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
  }

  /// 파일 저장 실패 시 재시도 다이얼로그 표시
  Future<void> _showSaveRetryDialog(
    MeasurementResult finalResult, {
    required void Function(Directory) onSuccess,
    String? nativeRawPath,
  }) async {
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('저장 실패 알림'),
        content: const Text('측정 결과 파일 저장에 실패했습니다\n결과 화면으로 이동합니다.'),
        actions: [
          AppDialogButton(
            label: '확인',
            onPressed: () => Navigator.of(ctx).pop(false),
            primary: false,
          ),
          AppDialogButton(
            label: '재시도',
            onPressed: () async {
              final success = await MeasuringScreen.attemptSave(
                finalResult,
                onSuccess: onSuccess,
                nativeRawPath: nativeRawPath,
              );
              if (success && ctx.mounted) {
                Navigator.of(ctx).pop(true);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 측정 종료 시 안전장치 게이트 평가, 분기, 저장, 화면 이동을 수행합니다.
  Future<void> _finishMeasurement() async {
    if (_isFinishing || _isFinished) return;
    if (mounted) {
      setState(() => _isFinishing = true);
    } else {
      _isFinishing = true;
    }
    _isFinished = true;
    await _cleanup();

    final preGate = _evaluateSaveGate(null);
    if (preGate == _SaveGateResult.siteInvalid) {
      await _showMeasureFailDialog('현장 정보가 없습니다. 홈에서 다시 시작해 주세요.');
      return;
    }
    if (preGate == _SaveGateResult.noSamples) {
      await _showMeasureFailDialog(
        '센서 데이터가 수집되지 않았습니다.\n기기 지원 여부를 확인한 뒤 다시 측정해 주세요.',
      );
      return;
    }

    final siteData = _validateSite()!;

    final result = _engine.analyze(
      jobNo: siteData.site.jobNo,
      siteName: siteData.site.siteName,
      bottomFloor: siteData.bottomFloor,
      topFloor: siteData.topFloor,
      direction: siteData.site.direction,
      dateTime: DateTime.now(),
    );

    var finalResult = result;
    if (_evaluateSaveGate(result) == _SaveGateResult.lowMotion) {
      if (!mounted) return;
      final proceed = await _showLowMotionDialog();
      if (proceed != true) {
        if (mounted) context.go('/start');
        return;
      }
      finalResult = result.copyWith(lowMotionWarning: true);
    }

    MeasurementSession.instance.lastResult = finalResult;
    MeasurementSession.instance.lastResultId = finalResult.id;

    Directory? savedDir;
    final bool initialSuccess = await MeasuringScreen.attemptSave(
      finalResult,
      onSuccess: (dir) => savedDir = dir,
      nativeRawPath: _nativeRawPath,
    );
    if (!initialSuccess) {
      await _showSaveRetryDialog(
        finalResult,
        onSuccess: (dir) => savedDir = dir,
        nativeRawPath: _nativeRawPath,
      );
    }

    if (savedDir != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '저장되었습니다 (경로: ${savedDir!.path})',
            style: AppText.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.green,
        ),
      );
    }

    if (mounted) {
      context.pushReplacement('/result/${finalResult.id}');
    }
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
                        // 현재 속도 섹션
                        Text(
                          '현재 속도',
                          style: AppText.bodyBold.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: AppDims.gap),
                        Text(
                          _currentSpeed.toStringAsFixed(2),
                          style: AppText.bigNumber.copyWith(
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '미터/초',
                          style: AppText.subhead.copyWith(
                            color: AppColors.gold,
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
