import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import 'package:vibration_checker/ui/features/settings/settings_screen.dart';

/// 작성: 2026-10-11 19:11:50 · nada
/// 함수: main
/// 목적: 설정 화면의 엔지니어 이름 칸을 시험한다. 저장된 이름으로 칸을
///       채우는지, 입력하는 즉시 저장하는지, 비우면 저장값도 지우는지 본다.
void main() {
  testWidgets('저장된 엔지니어 이름으로 칸을 채운다', (tester) async {
    SharedPreferences.setMockInitialValues({'engineerName': '홍길동'});

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('엔지니어 이름 (선택)'), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('리포트 엔지니어 칸에 찍힙니다'), findsOneWidget);
  });

  testWidgets('입력하면 바로 저장하고, 비우면 저장값을 지운다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first; // 엔지니어 이름 칸
    await tester.enterText(field, '김철수');
    await tester.pumpAndSettle();
    expect(await PrefsStore.instance.loadEngineerName(), '김철수');

    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(await PrefsStore.instance.loadEngineerName(), isNull);
  });
}
