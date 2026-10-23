import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/features/home/widgets/field_error.dart';

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 수정: 2026-10-22 23:10:00 · 박건준
/// 클래스: FloorFields
/// 목적: 최하층 · 최상층 입력 필드 2개를 나란히 둔다. 숫자 세 자리까지만
///       받고, 두 칸이 오류 상자 하나를 함께 쓴다.
class FloorFields extends StatelessWidget {
  /// 오류가 났을 때 스크롤로 이 영역을 찾는 위치 키
  final GlobalKey anchorKey;

  /// 최하층 입력칸의 텍스트 컨트롤러
  final TextEditingController bottomController;

  /// 최하층 입력칸의 포커스 노드
  final FocusNode bottomFocus;

  /// 최상층 입력칸의 텍스트 컨트롤러
  final TextEditingController topController;

  /// 최상층 입력칸의 포커스 노드. 최하층에서 "다음" 을 누르면 옮겨 온다
  final FocusNode topFocus;

  /// 층수 오류 문구. null 이면 오류 없음
  final String? error;

  /// 최상층에서 "완료" 를 눌렀을 때 부를 함수(측정 시작)
  final VoidCallback onTopSubmitted;

  /// 두 칸 가운데 하나라도 값이 바뀌면 부를 함수(저장 · 오류 지우기)
  final VoidCallback onChanged;

  /// 작성: 2026-10-22 23:10:00 · 박건준
  /// 함수: FloorFields
  /// 목적: 두 입력칸에 필요한 값을 받는다.
  /// 인자: anchorKey, bottomController, bottomFocus, topController,
  ///       topFocus, error, onTopSubmitted, onChanged — 위 필드 설명을
  ///       따른다
  const FloorFields({
    super.key,
    required this.anchorKey,
    required this.bottomController,
    required this.bottomFocus,
    required this.topController,
    required this.topFocus,
    required this.error,
    required this.onTopSubmitted,
    required this.onChanged,
  });

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-22 23:10:00 · 박건준
  /// 함수: build
  /// 목적: 라벨 → 최하층 · 최상층 한 줄 → (오류 박스) 를 세로로 놓는다.
  @override
  Widget build(BuildContext context) {
    return Container(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('측정 구간 (최하층 / 최상층)', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppDims.fieldH,
                  child: TextField(
                    controller: bottomController,
                    focusNode: bottomFocus,
                    style: AppText.body,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: InputDecoration(
                      hintText: '1',
                      labelText: '최하층',
                      enabledBorder: error != null ? fieldErrorBorder() : null,
                      focusedBorder: error != null ? fieldErrorBorder() : null,
                    ),
                    onSubmitted: (_) => topFocus.requestFocus(),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ),
              const SizedBox(width: AppDims.gap2),
              Expanded(
                child: SizedBox(
                  height: AppDims.fieldH,
                  child: TextField(
                    controller: topController,
                    focusNode: topFocus,
                    style: AppText.body,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: InputDecoration(
                      hintText: '8',
                      labelText: '최상층',
                      enabledBorder: error != null ? fieldErrorBorder() : null,
                      focusedBorder: error != null ? fieldErrorBorder() : null,
                    ),
                    onSubmitted: (_) => onTopSubmitted(),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ),
            ],
          ),
          if (error != null) FieldErrorBox(error!),
        ],
      ),
    );
  }
}
