import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ResultScreen extends StatelessWidget {
  final String id;

  const ResultScreen({super.key, required this.id});

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
