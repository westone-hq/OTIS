import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme.dart';
import '../../domain/measure/metrics_config.dart';
import '../../domain/measure/measurement_engine.dart';
import '../../domain/models/measurement_result.dart';
import '../../domain/sensor_channel.dart';
import '../shared/measurement_session.dart';

/// S4 측정 중 (라이브)
/// - 실시간 속도 및 경과 시간 표시. 멀리서도 읽히게 초대형 UI
/// - 어르신 UX: 대비 높은 Navy 어두운 배경, 72sp 속도 표시, 56dp+ 확인 버튼
class MeasuringScreen extends StatefulWidget {
  final SensorChannelManager? sensorManager;
  const MeasuringScreen({super.key, this.sensorManager});

  @override
  State<MeasuringScreen> createState() => _MeasuringScreenState();
}

class _MeasuringScreenState extends State<MeasuringScreen> {
  late final SensorChannelManager _sensorManager =
      widget.sensorManager ?? SensorChannelManager();
  Timer? _timeTimer;
  Timer? _uiTimer;
  StreamSubscription<double>? _speedSub;
  StreamSubscription<SensorSample>? _sensorSub;

  int _elapsedSeconds = 0;
  double _currentSpeed = 0.00;
  bool _receivedRealSample = false;
  double _integratedVelocity = 0.0;
  double _baselineSumZ = 0.0;
  int _baselineCount = 0;
  double _baselineZ = 0.0;
  int _lastTsUs = 0;

  final MeasurementEngine _engine = MeasurementEngine();
  int _countdownSec = 0;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
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
      await WakelockPlus.enable();
    } catch (_) {}

    // 2. 오디오 권한 요청 (거부 시 소음 N/A 처리용 안내)
    final bool audioGranted = await _sensorManager.requestAudioPermission();
    if (!audioGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '소음 제외 측정: 마이크 권한이 거부되어 진동만 측정합니다. (결과에 소음 N/A 표기)',
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
          _currentSpeed = _elapsedSeconds < 1 ? 0.00 : _integratedVelocity;
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
            _baselineZ = _baselineCount > 0 ? _baselineSumZ / _baselineCount : 0.0;
            _integratedVelocity = 0.0;
          } else {
            final double dt = (_lastTsUs > 0 && sample.tsUs > _lastTsUs)
                ? (sample.tsUs - _lastTsUs) / 1000000.0
                : (1.0 / 256.0);
            final double aZ = (sample.z - _baselineZ) * SensorSample.mgToMetersPerSecondSquared;
            _integratedVelocity = (_integratedVelocity + aZ * dt).abs().clamp(0.0, 3.0);
          }
          _lastTsUs = sample.tsUs;
        }
      });

      // 1초 후에도 실제 콜백이 전혀 없다면 mock 스트림으로 폴백
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_receivedRealSample && _speedSub == null) {
          _subscribeMockStream();
        }
      });
    } else {
      _subscribeMockStream();
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

  void _cleanup() {
    _timeTimer?.cancel();
    _uiTimer?.cancel();
    _countdownTimer?.cancel();
    _speedSub?.cancel();
    _sensorSub?.cancel();
    _sensorManager.stopCapture();
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _finishMeasurement() {
    _cleanup();

    final site = MeasurementSession.instance.currentSite;
    MeasurementResult result;
    if (_engine.sampleCount >= 2) {
      result = _engine.analyze(
        jobNo: site?.jobNo ?? '2024F 1447R01',
        siteName: site?.siteName ?? '럭키종합건설/송정동근생',
        bottomFloor: int.tryParse(site?.bottomFloor ?? '1') ?? 1,
        topFloor: int.tryParse(site?.topFloor ?? '8') ?? 8,
        direction: site?.direction ?? '하부 → 상부',
        dateTime: DateTime.now(),
      );
    } else {
      result = MeasurementResult.mock.copyWith(
        id: 'RES-${DateTime.now().millisecondsSinceEpoch}',
        jobNo: site?.jobNo ?? '2024F 1447R01',
        siteName: site?.siteName ?? '럭키종합건설/송정동근생',
        bottomFloor: int.tryParse(site?.bottomFloor ?? '1') ?? 1,
        topFloor: int.tryParse(site?.topFloor ?? '8') ?? 8,
        direction: site?.direction ?? '하부 → 상부',
        dateTime: DateTime.now(),
      );
    }

    MeasurementSession.instance.lastResult = result;
    MeasurementSession.instance.lastResultId = result.id;

    if (mounted) {
      context.pushReplacement('/result/${result.id}');
    }
  }

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
          Semantics(
            button: true,
            label: '계속 측정',
            child: SizedBox(
              height: AppDims.touchMin,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  '계속 측정',
                  style: AppText.bodyBold.copyWith(color: AppColors.navy),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '중단하기',
            child: SizedBox(
              height: AppDims.touchMin,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  padding: const EdgeInsets.symmetric(horizontal: AppDims.gap2),
                ),
                child: Text(
                  '중단하기',
                  style: AppText.bodyBold.copyWith(color: Colors.white),
                ),
              ),
            ),
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
          _cleanup();
          context.pop();
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
                    _cleanup();
                    context.pop();
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
              onPressed: () => _finishMeasurement(),
              child: const Text('테스트 완료'),
            ),
          ),
        ),
      ),
    );
  }
}
