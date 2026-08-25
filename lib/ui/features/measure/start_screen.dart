import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';
import 'package:vibration_checker/adapter/sensor_channel.dart';
import '../shared/measurement_session.dart';
import 'placement_sheet.dart';

/// 작성: 2026-08-17 13:31:30 · 박건준
/// 클래스: StartScreen
/// 목적: 카운트다운 대기 시간을 고르고 측정을 시작하는 화면.
///       - 어르신도 쓰기 쉽도록 선택 카드 높이 72dp, 시작 버튼 높이 64dp로
///         맞춘다
///       - 상태(선택됨 · 비활성 등)는 색·아이콘·문구 세 가지를 함께 표시한다
class StartScreen extends StatefulWidget {
  /// 테스트에서 가짜(mock) 센서 관리자를 주입하기 위한 값. null이면
  /// 화면이 실제 `SensorChannelManager`(네이티브 가속도 · 중력 센서와
  /// 주고받는 통신을 담당하는 관리자 클래스)를 새로 만들어 쓴다
  final SensorChannelManager? sensorManager;
  const StartScreen({super.key, this.sensorManager});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

/// 작성: 2026-08-17 13:31:30 · 박건준
/// 클래스: _StartScreenState
/// 목적: 측정 준비 화면의 상태를 관리한다.
///       - 센서 가용 여부(`_sensorsAvailable`)를 비동기로 확인해 저장한다
///       - 카운트다운 대기 시간(`_selectedSeconds`)을 고르게 한다
///       - 거치 방법 안내 바텀 시트(bottom sheet, 화면 아래에서 위로
///         올라오는 패널)를 앱 실행 중 한 번만 자동으로 띄우기 위해
///         `_hasSeenPlacementSheet`를 static 필드로 기억해둔다
class _StartScreenState extends State<StartScreen> {
  /// 실제로 쓰는 센서 관리자. `widget.sensorManager`가 없으면 새로 만든다
  late final SensorChannelManager _sensorManager =
      widget.sensorManager ?? SensorChannelManager();

  /// 가속도 · 중력 센서 사용 가능 여부
  bool _sensorsAvailable = true;

  /// 이 화면을 앱 실행 중 한 번이라도 보여준 적이 있는지 여부. 거치 방법
  /// 안내 바텀 시트를 최초 1회만 자동으로 띄우는 데 쓴다. static 필드라
  /// 앱을 재시작하면 초기화되고, `PrefsStore`에도 저장하지 않는다
  static bool _hasSeenPlacementSheet = false;

  /// 사용자가 고른 카운트다운 대기 시간 (초)
  int _selectedSeconds = 5;

  /// 선택 가능한 대기 시간 목록 (초)
  final List<int> _timeOptions = const [0, 5, 10, 15];

  /// 작성: 2026-08-17 13:31:30 · 박건준
  /// 함수: initState
  /// 목적: `initState`(이 화면이 새로 만들어질 때, 화면을 그리기 전에
  ///       Flutter가 딱 한 번만 불러주는 생명주기(lifecycle, "만들어짐
  ///       → 화면에 나타남 → 다시 그려짐 → 사라짐"처럼 정해진 순서로
  ///       불리는 함수들) 메서드다. 이 화면에서는 두 가지를 준비한다.
  ///       - `_checkSensors()`로 센서 가용 여부를 비동기로 확인한다
  ///       - 이 화면을 처음 보여주는 경우에만, 첫 프레임이 그려진 뒤 거치
  ///         방법 안내 바텀 시트(`_showPlacementSheet`)를 자동으로 띄운다
  @override
  void initState() {
    super.initState();
    _checkSensors(); // → 로직 이동: _checkSensors()
    if (!_hasSeenPlacementSheet) {
      _hasSeenPlacementSheet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPlacementSheet(); // → 로직 이동: _showPlacementSheet()
        }
      });
    }
  }

  /// 작성: 2026-08-17 13:31:30 · 박건준
  /// 함수: _checkSensors
  /// 목적: 가속도 · 중력 센서를 실제로 쓸 수 있는지 비동기로 확인해
  ///       `_sensorsAvailable`에 반영한다.
  ///       - 이 확인이 끝나기 전에 사용자가 다른 화면으로 넘어가는 등,
  ///         이 화면이 사라지면 `mounted`(이 화면이 아직 떠 있는지
  ///         여부)가 false로 바뀐다
  ///       - 이미 사라진 화면에 결과를 반영하려고 `setState`를 부르면
  ///         오류가 나므로, `mounted`가 true일 때만 반영한다
  Future<void> _checkSensors() async {
    // → 로직 이동: SensorChannelManager.checkSensorsAvailable()
    final available = await _sensorManager.checkSensorsAvailable(); // 센서 가용 여부
    if (mounted) {
      setState(() => _sensorsAvailable = available);
    }
  }

  /// 작성: 2026-08-17 13:31:30 · 박건준
  /// 함수: _showPlacementSheet
  /// 목적: `showModalBottomSheet`(화면 아래에서 위로 올라오는 바텀
  ///       시트를 띄우는 Flutter 함수)로 `PlacementSheet`(휴대폰을
  ///       엘리베이터 바닥 어디에 어느 방향으로 놓을지부터, 측정을
  ///       시작하고 끝내는 방법까지 4단계 그림으로 안내하는 위젯)를
  ///       띄운다. 각 인자의 역할은 다음과 같다.
  ///       - `context` — 어느 화면 위에 띄울지 알려주는 위치 정보
  ///       - `isScrollControlled` — true로 주면 시트가 내용 길이에 맞춰
  ///         화면 위쪽 끝까지 늘어날 수 있다. 기본값(false)이면 화면
  ///         절반 높이로 제한돼 안내문 4단계가 다 안 보일 수 있다
  ///       - `backgroundColor` — 시트 바탕색
  ///       - `shape` — 시트의 위쪽 두 모서리만 둥글게 깎는 테두리 모양
  ///       - `builder` — 시트 안에 실제로 그릴 위젯을 돌려주는 함수.
  ///         여기서는 `PlacementSheet`를 그대로 띄운다
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
      // → 로직 이동: PlacementSheet.build()
      builder: (_) => const PlacementSheet(),
    );
  }

  /// 작성: 2026-08-17 13:31:30 · 박건준
  /// 함수: _buildTimeCard
  /// 목적: 대기 시간 선택 카드 하나를 만든다. 선택된 카드는 파란
  ///       배경 · 체크 아이콘으로, 나머지는 기본 배경 · 빈 원으로
  ///       구별해서 보여준다.
  /// 인자: seconds — 이 카드가 나타내는 대기 시간 (초)
  /// 반환: 대기 시간 선택 카드 위젯
  Widget _buildTimeCard(int seconds) {
    final isSelected = _selectedSeconds == seconds; // 이 카드가 현재 선택된 시간인지
    return Expanded(
      // 가로 폭을 다른 카드와 균등하게 나눔
      child: Semantics(
        // 화면 낭독기 등 보조기술에 버튼·선택 상태를 알려줌
        button: true,
        selected: isSelected,
        label: '$seconds초',
        child: InkWell(
          // 누르면 이 시간을 선택하도록 반응
          onTap: () => setState(() => _selectedSeconds = seconds),
          borderRadius: BorderRadius.circular(AppDims.radius),
          child: Container(
            // 카드 배경과 테두리
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
              // 아이콘 + 초 표시 텍스트를 가로로 배치
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

  /// 작성: 2026-08-17 13:31:30 · 박건준
  /// 함수: build
  /// 목적: 측정 준비 화면의 레이아웃을 구성한다.
  ///       - `appBar` — 제목만 있는 간단한 상단 바
  ///       - `body` — 스크롤 가능한 안내 영역. 거치 안내 카드 → 대기
  ///         시간 선택 카드 4개 → 선택한 시간 요약 문구 순으로 보여준다
  ///       - `bottomNavigationBar` — 센서를 못 쓰면 오류 안내를 보여주고,
  ///         그 아래 측정(또는 카운트다운) 시작 버튼을 둔다
  /// 인자: context — 이 화면이 어디에 놓이는지 알려주는 값. 시작 버튼을
  ///       눌러 `/measuring`으로 넘어갈 때 쓴다
  /// 반환: 측정 준비 화면 전체를 담는 위젯
  @override
  Widget build(BuildContext context) {
    final bool canStart = _sensorsAvailable; // 측정 시작 버튼을 눌러도 되는지

    return Scaffold(
      appBar: AppBar(title: const Text('측정 시작')),
      body: SafeArea(
        // 시스템 UI를 피해서 배치
        child: SingleChildScrollView(
          // 안내 내용이 길면 스크롤
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: ConstrainedBox(
            // 넓은 화면에서 폭이 과하게 늘어나지 않게 제한
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDims.gap),
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
                          // → 로직 이동: _showPlacementSheet()
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
        // 하단 고정 영역, 시스템 UI를 피해서 배치
        child: Padding(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canStart) ...[
                Container(
                  // 센서 없어서 측정 불가 안내
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
                          '이 기기는 가속도 또는 중력 센서가 없어 측정을 지원하지 않습니다.',
                          style: AppText.bodyBold.copyWith(
                            color: AppColors.red,
                          ),
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
                        // → 로직 이동: MeasurementSession.instance.delaySec
                        MeasurementSession.instance.delaySec = _selectedSeconds;
                        context.push(
                          '/measuring',
                        ); // → 로직 이동: MeasuringScreen.build()
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
