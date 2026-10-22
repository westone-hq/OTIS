import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration_checker/domain/session/site_info.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/features/home/widgets/field_error.dart';

/// 작성: 2026-10-11 17:28:28 · 박건준
/// 수정: 2026-10-22 23:10:00 · 박건준
/// 클래스: LoadField
/// 목적: 하중 입력칸과 단위 글자(`SiteInfo.loadUnit`, kg)를 한 줄에 둔다.
///       단위는 고를 수 없다(2026-10-13 kg 고정). 입력칸 안 꼬리
///       글자(suffixText)는 빈 칸일 때 숨으므로 칸 밖 같은 줄에 둔다.
///       하중은 소수점이 있는 숫자 키패드로 받고, 숫자인지는 측정 시작 때
///       `SiteInfo.validate()` 가 본다.
class LoadField extends StatelessWidget {
  /// 오류가 났을 때 스크롤로 이 영역을 찾는 위치 키
  final GlobalKey anchorKey;

  /// 하중 입력칸의 텍스트 컨트롤러
  final TextEditingController controller;

  /// 하중 입력칸의 포커스 노드
  final FocusNode focusNode;

  /// 하중 오류 문구. null 이면 오류 없음
  final String? error;

  /// 값이 바뀔 때마다 부를 함수(저장 · 오류 지우기)
  final VoidCallback onChanged;

  /// 작성: 2026-10-22 23:10:00 · 박건준
  /// 함수: LoadField
  /// 목적: 하중 입력칸에 필요한 값을 받는다.
  /// 인자: anchorKey, controller, focusNode, error, onChanged — 위 필드
  ///       설명을 따른다
  const LoadField({
    super.key,
    required this.anchorKey,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
  });

  /// 작성: 2026-10-11 17:28:28 · 박건준
  /// 수정: 2026-10-22 23:10:00 · 박건준
  /// 함수: build
  /// 목적: 라벨 → 입력칸 · 단위 한 줄 → (오류 박스) 를 세로로 놓는다.
  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('하중', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppDims.fieldH,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: AppText.body,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      hintText: '숫자',
                      enabledBorder: error != null ? fieldErrorBorder() : null,
                      focusedBorder: error != null ? fieldErrorBorder() : null,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ),
              const SizedBox(width: AppDims.gap2),
              Text(SiteInfo.loadUnit, style: AppText.bodyBold),
            ],
          ),
          if (error != null) FieldErrorBox(error!),
        ],
      ),
    );
  }
}
