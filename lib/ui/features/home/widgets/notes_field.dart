import 'package:flutter/material.dart';
import 'package:vibration_checker/ui/core/theme.dart';

/// 작성: 2026-10-11 17:28:28 · nada
/// 수정: 2026-10-22 23:10:00 · nada
/// 클래스: _NotesLayout
/// 목적: 참고사항 입력칸 배치에만 쓰는 수치. 다른 화면은 쓰지 않아
///       `theme.dart` 토큰으로 올리지 않는다.
class _NotesLayout {
  /// 추가 참고사항 입력칸이 처음 보이는 줄 수
  static const int notesMinLines = 3;

  /// 추가 참고사항 입력칸이 늘어나는 최대 줄 수. 넘치면 칸 안에서
  /// 스크롤된다
  static const int notesMaxLines = 5;
}

/// 작성: 2026-10-11 17:28:28 · nada
/// 수정: 2026-10-22 23:10:00 · nada
/// 클래스: NotesField
/// 목적: 추가 참고사항을 여러 줄로 받는다. 비워 둬도 측정을 시작할 수
///       있고, 적은 내용은 메일 본문에만 들어간다. 현장마다 달라 기기에
///       저장하지 않는다.
class NotesField extends StatelessWidget {
  /// 참고사항 입력칸의 텍스트 컨트롤러. 화면이 갖고 정리한다
  final TextEditingController controller;

  /// 작성: 2026-10-22 23:10:00 · nada
  /// 함수: NotesField
  /// 목적: 참고사항 입력칸의 컨트롤러를 받는다.
  /// 인자: controller — 위 필드 설명을 따른다
  const NotesField({super.key, required this.controller});

  /// 작성: 2026-10-11 17:28:28 · nada
  /// 수정: 2026-10-22 23:10:00 · nada
  /// 함수: build
  /// 목적: 라벨 → 여러 줄 입력칸 → 안내 글자를 세로로 놓는다.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('추가 참고사항 (선택)', style: AppText.bodyBold),
        const SizedBox(height: AppDims.gap),
        TextField(
          controller: controller,
          style: AppText.body,
          keyboardType: TextInputType.multiline,
          minLines: _NotesLayout.notesMinLines,
          maxLines: _NotesLayout.notesMaxLines,
        ),
        const SizedBox(height: AppDims.gap),
        Text('메일 본문에 들어갑니다', style: AppText.caption),
      ],
    );
  }
}
