import 'package:flutter/material.dart';
import 'package:vibration_checker/domain/session/site_info.dart';
import 'package:vibration_checker/ui/core/theme.dart';

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 수정: 2026-10-22 23:10:00 · 박건준
/// 클래스: DirectionSelector
/// 목적: 운전 방향(상승 / 하강)을 고르는 버튼 2개.
class DirectionSelector extends StatelessWidget {
  /// 지금 고른 운전 방향. `SiteInfo.directionUp` 또는 `SiteInfo.directionDown`
  final String direction;

  /// 다른 방향을 고르면 부를 함수. 고른 방향을 받는다
  final ValueChanged<String> onChanged;

  /// 작성: 2026-10-22 23:10:00 · 박건준
  /// 함수: DirectionSelector
  /// 목적: 지금 방향과 바꿀 때 할 일을 받는다.
  /// 인자: direction, onChanged — 위 필드 설명을 따른다
  const DirectionSelector({
    super.key,
    required this.direction,
    required this.onChanged,
  });

  /// 작성: 2026-10-11 17:28:28 · 박건준
  /// 수정: 2026-10-22 23:10:00 · 박건준
  /// 함수: _segmentStyle
  /// 목적: 운전 방향 버튼 묶음의 모양. 터치 영역 56dp 를 지킨다.
  /// 반환: 버튼 묶음 스타일
  ButtonStyle _segmentStyle() {
    return SegmentedButton.styleFrom(
      backgroundColor: AppColors.surface,
      selectedBackgroundColor: AppColors.blue,
      selectedForegroundColor: AppColors.onDark,
      foregroundColor: AppColors.navy,
      textStyle: AppText.bodyBold,
      minimumSize: const Size(0, AppDims.touchMin),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
      ),
    );
  }

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-22 23:10:00 · 박건준
  /// 함수: build
  /// 목적: 라벨 아래에 상승 · 하강 버튼 묶음을 놓는다.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('운전 방향', style: AppText.bodyBold),
        const SizedBox(height: AppDims.gap),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: SiteInfo.directionUp,
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: AppDims.gap2),
                child: Text(SiteInfo.directionUp),
              ),
              icon: Icon(Icons.arrow_upward),
            ),
            ButtonSegment<String>(
              value: SiteInfo.directionDown,
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: AppDims.gap2),
                child: Text(SiteInfo.directionDown),
              ),
              icon: Icon(Icons.arrow_downward),
            ),
          ],
          selected: {direction},
          onSelectionChanged: (val) => onChanged(val.first),
          style: _segmentStyle(), // → 로직 이동: _segmentStyle()
        ),
      ],
    );
  }
}
