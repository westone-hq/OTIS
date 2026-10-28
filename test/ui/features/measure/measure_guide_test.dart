import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/features/measure/measure_guide.dart';

/// 작성: 2026-10-28 11:00:00 · 박건준
/// 함수: main
/// 목적: 측정 안내 줄바꿈 처리(`keepWordsTogether()`)가 글자는 그대로 두고,
///       좁은 폭에서 낱말 중간이 아니라 띄어쓰기에서 꺾이는지 본다.
void main() {
  test('보이는 글자는 그대로이고 낱말 안에만 이음표가 들어간다', () {
    final joined = keepWordsTogether(measureIdleGuide); // 이음표를 넣은 문구
    expect(joined.replaceAll('⁠', ''), measureIdleGuide);
    expect(joined.split(' ').length, measureIdleGuide.split(' ').length);
  });

  test('좁은 폭에서 마지막 낱말을 통째로 다음 줄로 넘긴다', () {
    final painter = TextPainter(
      text: TextSpan(
        text: keepWordsTogether(measureIdleGuide),
        style: AppText.bodyBold,
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 300); // 360dp 폰의 안내 박스 안쪽 폭 어림
    final lines = painter.computeLineMetrics(); // 줄마다 자리
    final secondStart = painter
        .getPositionForOffset(Offset(0, lines.last.baseline))
        .offset; // 마지막 줄 첫 글자 자리
    final rest = keepWordsTogether(
      measureIdleGuide,
    ).substring(secondStart).replaceAll('⁠', ''); // 마지막 줄 글자
    painter.dispose();

    expect(lines.length, greaterThan(1), reason: '이 폭이면 한 줄에 안 든다');
    expect(
      measureIdleGuide.split(' '),
      contains(rest.trim().split(' ').first),
      reason: '마지막 줄이 낱말 처음에서 시작한다: "$rest"',
    );
  });
}
