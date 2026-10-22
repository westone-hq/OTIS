import 'package:flutter/material.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/core/widgets/app_notice.dart';

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 수정: 2026-10-22 23:10:00 · nada
/// 함수: fieldErrorBorder
/// 목적: 입력 필드에 오류가 있을 때 보여줄 빨간 테두리를 만든다. 홈 화면
///       입력 칸 묶음이 함께 쓴다.
/// 반환: 빨간 테두리 스타일
OutlineInputBorder fieldErrorBorder() {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDims.radius),
    borderSide: const BorderSide(
      color: AppColors.red,
      width: AppDims.borderWThick,
    ),
  );
}

/// 작성: 2026-08-17 12:40:41 · 박건준
/// 수정: 2026-10-22 23:10:00 · nada
/// 클래스: FieldErrorBox
/// 목적: 입력 칸 아래에 오류 문구를 아이콘 · 빨간 박스와 함께 보여준다.
class FieldErrorBox extends StatelessWidget {
  /// 화면에 보여줄 오류 문구
  final String message;

  /// 작성: 2026-10-22 23:10:00 · nada
  /// 함수: FieldErrorBox
  /// 목적: 보여줄 오류 문구를 받는다.
  /// 인자: message — 오류 문구
  const FieldErrorBox(this.message, {super.key});

  /// 작성: 2026-08-17 12:40:41 · 박건준
  /// 수정: 2026-10-22 23:10:00 · nada
  /// 함수: build
  /// 목적: 위쪽 간격을 두고 위험 톤 안내 박스를 그린다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDims.gap2),
      child: AppNotice(
        icon: Icons.error_outline,
        message: message,
        tone: NoticeTone.danger,
      ),
    );
  }
}
