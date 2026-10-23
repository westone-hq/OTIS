import 'package:flutter/material.dart';
import 'package:vibration_checker/ui/core/theme.dart';

/// 작성: 2026-10-11 17:28:28 · 박건준
/// 수정: 2026-10-22 23:10:00 · 박건준
/// 클래스: LabeledDropdown
/// 목적: 선택지 하나를 고르는 드롭다운을 라벨과 함께 둔다. 기종과 해석
///       종류가 같은 모양을 쓴다. 긴 선택지("사이클 저크(가속도증가율)
///       테스트")도 칸 폭에 맞춰 보이게 칸을 가로로 채운다.
class LabeledDropdown extends StatelessWidget {
  /// 드롭다운 위 라벨
  final String label;

  /// 지금 고른 값. `options` 가운데 하나
  final String value;

  /// 선택지와 그 차례
  final List<String> options;

  /// 다른 값을 고르면 부를 함수. 고른 값을 받는다
  final ValueChanged<String> onChanged;

  /// 작성: 2026-10-22 23:10:00 · 박건준
  /// 함수: LabeledDropdown
  /// 목적: 라벨 · 지금 값 · 선택지 · 바꿀 때 할 일을 받는다.
  /// 인자: label, value, options, onChanged — 위 필드 설명을 따른다
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  /// 작성: 2026-10-11 17:28:28 · 박건준
  /// 수정: 2026-10-22 23:10:00 · 박건준
  /// 함수: build
  /// 목적: 라벨 아래에 가로를 채우는 드롭다운을 놓는다.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.bodyBold),
        const SizedBox(height: AppDims.gap),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          style: AppText.body,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: AppDims.iconM,
            color: AppColors.navy,
          ),
          // 여백 · 테두리는 앱 테마의 입력창 설정을 그대로 따른다
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}
