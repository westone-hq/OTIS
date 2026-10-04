import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/ui/features/home/home_screen.dart';

/// 작성: 2026-10-04 14:35:59 · nada
/// 함수: main
/// 목적: 홈 화면이 지난번 현장 정보로 입력창 · 선택지를 미리 채우는지,
///       선택지에 없는 저장값은 버리는지 시험한다.
void main() {
  testWidgets('저장된 현장 정보로 입력창과 기종을 채운다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lastSite': jsonEncode({
        'jobNo': '2024F 1447R01',
        'siteName': '현장',
        'bottomFloor': '1',
        'topFloor': '8',
        'direction': '상부 → 하부',
        'model': '기타',
      }),
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('2024F 1447R01'), findsOneWidget);
    expect(find.text('기타'), findsOneWidget, reason: '기종이 저장값으로 바뀌어야 한다');
    expect(find.text('Gen2'), findsNothing);
  });

  testWidgets('선택지에 없는 기종은 버리고 기본값을 둔다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lastSite': jsonEncode({'model': '없는 기종'}),
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Gen2'), findsOneWidget);
  });
}
