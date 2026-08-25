import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 작성: 2026-07-03 15:21:58 · 박건준
/// 클래스: ResultScreen
/// 목적: 측정 결과를 보여줄 화면. 분석 계층이 아직 없어 안내 문구만 띄운다.
class ResultScreen extends StatelessWidget {
  /// 표시할 측정 결과의 식별자
  final String id;

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: ResultScreen
  /// 목적: 보여줄 측정 결과의 식별자를 받아 화면을 만든다.
  /// 인자: id — 측정 결과 식별자
  const ResultScreen({super.key, required this.id});

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: build
  /// 목적: 결과 화면을 그린다.
  /// 미구현: 분석 계층이 없어 안내 문구만 보여준다. `id`로 결과를
  ///       조회해 그래프·수치를 보여주는 로직은 아직 없다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('측정 결과'),
      ),
      body: const Center(
        child: Text(
          '분석 계층 미구현\n(결과 화면 작성 예정)',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
      ),
    );
  }
}
