import 'package:flutter/material.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/features/home/widgets/field_error.dart';

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 수정: 2026-10-22 23:10:00 · nada
/// 클래스: SiteTextField
/// 목적: 라벨 한 줄과 한 줄 입력칸으로 된 현장 정보 입력 영역. 제번과
///       현장명이 같은 모양을 쓴다. 오류가 있으면 테두리를 빨갛게 하고
///       칸 아래에 오류 박스를 둔다.
class SiteTextField extends StatelessWidget {
  /// 오류가 났을 때 스크롤로 이 영역을 찾는 위치 키
  final GlobalKey anchorKey;

  /// 입력칸 위 라벨
  final String label;

  /// 입력칸의 텍스트 컨트롤러. 화면이 갖고 정리한다
  final TextEditingController controller;

  /// 입력칸의 포커스 노드. 화면이 갖고 정리한다
  final FocusNode focusNode;

  /// 오류 문구. null 이면 오류 없음
  final String? error;

  /// 키보드의 "다음" 을 눌렀을 때 부를 함수(다음 칸으로 포커스를 옮긴다)
  final VoidCallback onSubmitted;

  /// 값이 바뀔 때마다 부를 함수(저장 · 오류 지우기)
  final VoidCallback onChanged;

  /// 작성: 2026-10-22 23:10:00 · nada
  /// 함수: SiteTextField
  /// 목적: 입력 영역 하나에 필요한 값을 받는다.
  /// 인자: anchorKey, label, controller, focusNode, error, onSubmitted,
  ///       onChanged — 위 필드 설명을 따른다
  const SiteTextField({
    super.key,
    required this.anchorKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onSubmitted,
    required this.onChanged,
  });

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-22 23:10:00 · nada
  /// 함수: build
  /// 목적: 라벨 → 입력칸 → (오류 박스) 를 세로로 놓는다.
  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          SizedBox(
            height: AppDims.fieldH,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppText.body,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                enabledBorder: error != null ? fieldErrorBorder() : null,
                focusedBorder: error != null ? fieldErrorBorder() : null,
              ),
              onSubmitted: (_) => onSubmitted(),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (error != null) FieldErrorBox(error!),
        ],
      ),
    );
  }
}
