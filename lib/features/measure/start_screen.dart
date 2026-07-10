import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../domain/sensor_channel.dart';
import '../shared/measurement_session.dart';
import 'placement_sheet.dart';

/// S3 측정 시작 화면
/// - 카운트다운 대기 시간을 고르고 측정을 시작
/// - 어르신 UX: 고정 높이 72dp 선택 카드, 64dp 시작 버튼, 색+아이콘+텍스트 3중 상태
class StartScreen extends StatefulWidget {
  final SensorChannelManager? sensorManager;
  const StartScreen({super.key, this.sensorManager});

  /// 센서 가용 여부 및 디버그 모드에 따른 측정 시작 가능 여부를 판정합니다.
  @visibleForTesting
  static bool canStartMeasure({required bool available, required bool isDebug}) =>
      available || isDebug;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

/// 측정 준비 화면의 상태, 지연 시간 선택, 센서 가용성 확인 및 거치 방법 바텀 시트 호출을 관리합니다.
class _StartScreenState extends State<StartScreen> {
  late final SensorChannelManager _sensorManager =
      widget.sensorManager ?? SensorChannelManager();
  bool _sensorsAvailable = true;

  // TODO(Phase 7): PrefsStore를 통한 SharedPreferences 영구 저장으로 변경
  static bool _hasSeenPlacementSheet = false;

  int _selectedSeconds = 5;
  final List<int> _timeOptions = const [0, 5, 10, 15];

  @override
  void initState() {
    super.initState();
    _checkSensors();
    if (!_hasSeenPlacementSheet) {
      _hasSeenPlacementSheet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPlacementSheet();
        }
      });
    }
  }

  Future<void> _checkSensors() async {
    final available = await _sensorManager.checkSensorsAvailable();
    if (mounted) {
      setState(() => _sensorsAvailable = available);
    }
  }

  void _showPlacementSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDims.radius),
        ),
      ),
      builder: (_) => const PlacementSheet(),
    );
  }

  Widget _buildTimeCard(int seconds) {
    final isSelected = _selectedSeconds == seconds;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$seconds초',
        child: InkWell(
          onTap: () => setState(() => _selectedSeconds = seconds),
          borderRadius: BorderRadius.circular(AppDims.radius),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.blue : AppColors.surface,
              borderRadius: BorderRadius.circular(AppDims.radius),
              border: Border.all(
                color: isSelected ? AppColors.blue : AppColors.border,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppDims.gap2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.white : AppColors.textSub,
                  size: 28,
                ),
                const SizedBox(width: AppDims.gap),
                Text(
                  '$seconds초',
                  style: AppText.subhead.copyWith(
                    color: isSelected ? Colors.white : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canStart = StartScreen.canStartMeasure(
      available: _sensorsAvailable,
      isDebug: kDebugMode,
    );
    final bool isDebugBypassed = !_sensorsAvailable && kDebugMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('측정 시작'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDims.gap),
                if (isDebugBypassed) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDims.gap2,
                      vertical: AppDims.gap,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppDims.radius),
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.gold,
                          size: 24,
                        ),
                        const SizedBox(width: AppDims.gap),
                        Expanded(
                          child: Text(
                            '디버그: 센서 체크 우회',
                            style: AppText.bodyBold.copyWith(color: AppColors.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDims.gap2),
                ],
                // 리마인더 카드
                Container(
                  padding: const EdgeInsets.all(AppDims.gap2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDims.radius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.smartphone,
                            color: AppColors.navy,
                            size: 28,
                          ),
                          const SizedBox(width: AppDims.gap),
                          Expanded(
                            child: Text(
                              '휴대폰을 카 바닥 중앙에 놓으세요',
                              style: AppText.bodyBold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDims.gap),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppDialogButton(
                          label: '거치 방법 보기',
                          onPressed: _showPlacementSheet,
                          primary: false,
                          icon: Icons.help_outline,
                          iconColor: AppColors.blue,
                          iconSize: 22,
                          textStyle: AppText.body.copyWith(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDims.gap3),

                // 질문 텍스트
                Text('언제 측정을 시작할까요?', style: AppText.subhead),
                const SizedBox(height: AppDims.gap2),

                // 대기 시간 선택 (2x2 그리드 형태의 Column + Row)
                Row(
                  children: [
                    _buildTimeCard(_timeOptions[0]),
                    const SizedBox(width: AppDims.gap2),
                    _buildTimeCard(_timeOptions[1]),
                  ],
                ),
                const SizedBox(height: AppDims.gap2),
                Row(
                  children: [
                    _buildTimeCard(_timeOptions[2]),
                    const SizedBox(width: AppDims.gap2),
                    _buildTimeCard(_timeOptions[3]),
                  ],
                ),
                const SizedBox(height: AppDims.gap2),

                // 선택 요약 텍스트
                Text(
                  '버튼을 누르면 $_selectedSeconds초 후 측정이 시작됩니다',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canStart) ...[
                Container(
                  padding: const EdgeInsets.all(AppDims.gap2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDims.radius),
                    border: Border.all(color: AppColors.red, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.red,
                        size: 24,
                      ),
                      const SizedBox(width: AppDims.gap),
                      Expanded(
                        child: Text(
                          '이 기기는 선형가속도 센서가 없어 측정을 지원하지 않습니다.',
                          style: AppText.bodyBold.copyWith(color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDims.gap2),
              ],
              ElevatedButton(
                onPressed: canStart
                    ? () {
                        MeasurementSession.instance.delaySec = _selectedSeconds;
                        context.push('/measuring');
                      }
                    : null,
                child: Text(_selectedSeconds == 0 ? '측정 시작' : '카운트다운 시작'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
