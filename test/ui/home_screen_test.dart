import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import 'package:vibration_checker/ui/features/home/home_screen.dart';

/// 작성: 2026-10-04 14:35:59 · nada
/// 함수: main
/// 목적: 홈 화면이 지난번 현장 정보로 입력창 · 선택지를 미리 채우는지,
///       선택지에 없는 저장값은 버리는지, 입력하는 즉시 저장하는지
///       시험한다.
void main() {
  testWidgets('저장된 현장 정보로 입력창과 선택지를 채운다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lastSite': jsonEncode({
        'jobNo': '2024F 1447R01',
        'siteName': '현장',
        'address': '서울시 강남구',
        'bottomFloor': '1',
        'topFloor': '8',
        'direction': '하강',
        'model': '줄-로우프, 2:1',
      }),
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('2024F 1447R01'), findsOneWidget);
    expect(find.text('서울시 강남구'), findsOneWidget);
    expect(find.text('줄-로우프, 2:1'), findsOneWidget);
    expect(find.text('Gen2'), findsNothing);
    final segments = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    ); // 운전 방향 선택 버튼
    expect(segments.selected, {'하강'});
  });

  testWidgets('선택지에 없는 저장값은 버리고 기본값을 둔다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lastSite': jsonEncode({'direction': '하부 → 상부', 'model': '없는 기종'}),
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Gen2'), findsOneWidget);
    final segments = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    ); // 운전 방향 선택 버튼
    expect(segments.selected, {'상승'});
  });

  testWidgets('입력하면 측정을 시작하지 않아도 바로 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'J-77');
    await tester.pumpAndSettle();

    final saved = await PrefsStore.instance.loadLastSite(); // 저장된 현장 정보
    expect(saved['jobNo'], 'J-77');
  });

  testWidgets('예시 힌트 없이 주소 · 층수 힌트만 둔다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('예:'), findsNothing);
    expect(find.text('시 · 도 주소'), findsOneWidget);
  });
}
