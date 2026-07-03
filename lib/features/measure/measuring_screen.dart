import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../domain/sensor_channel.dart';

/// S4 측정 중 (라이브)
/// - 실시간 속도 및 경과 시간 표시. 멀리서도 읽히게 초대형 UI
/// - 어르신 UX: 대비 높은 Navy 어두운 배경, 72sp 속도 표시, 56dp+ 확인 버튼
class MeasuringScreen extends StatefulWidget {
  const MeasuringScreen({super.key});

  @override
  State<MeasuringScreen> createState() => _MeasuringScreenState();
}

class _MeasuringScreenState extends State<MeasuringScreen> {
  final _sensorManager = SensorChannelManager();
  Timer? _timeTimer;
  StreamSubscription<double>? _speedSub;
  StreamSubscription<SensorSample>? _sensorSub;

  int _elapsedSeconds = 0;
  double _currentSpeed = 0.00;

  @override
  void initState() {
    super.initState();
    _startTimers();
  }

  void _startTimers() {
    // 경과 시간 카운트 (1초 간격)
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });

    // P11 안드로이드 센서 채널 연결 (startCapture 호출 및 스트림 구독)
    _sensorManager.startCapture(targetSampleRate: 256);
    _sensorSub = _sensorManager.sensorStream.listen((sample) {
      if (sample.timestamp > 0 && mounted) {
        // 실제 센서 데이터 수신 시 가속도(z)를 기반으로 속도 갱신
        setState(() => _currentSpeed = (sample.z * 0.0098).abs().clamp(0.0, 3.0));
      }
    });

    // fallback: 네이티브 센서 콜백이 없는 환경(에뮬레이터/위젯테스트)에서는 mock 스트림으로 라이브 표시 유지
    _speedSub = _mockSpeedStream().listen((speed) {
      if (mounted && _sensorSub?.isPaused != false) {
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

  @override
  void dispose() {
    _timeTimer?.cancel();
    _speedSub?.cancel();
    _sensorSub?.cancel();
    _sensorManager.stopCapture();
    super.dispose();
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
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    final timeFormatted = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await _showExitDialog();
        if (confirm == true && context.mounted) {
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
              onPressed: () => context.pushReplacement('/result/demo'),
              child: const Text('테스트 완료'),
            ),
          ),
        ),
      ),
    );
  }
}
