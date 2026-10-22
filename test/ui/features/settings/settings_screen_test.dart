import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/storage/prefs_store.dart';
import 'package:vibration_checker/domain/auth/login_session.dart';
import 'package:vibration_checker/domain/auth/worker.dart';
import 'package:vibration_checker/ui/features/settings/settings_screen.dart';

/// 작성: 2026-10-18 09:41:12 · nada
/// 함수: _pumpSettings
/// 목적: 설정 화면과, 로그아웃하면 옮겨 갈 로그인 자리 화면을 띄운다.
/// 인자: tester — 위젯 시험 도구
Future<void> _pumpSettings(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/login', builder: (_, _) => const Text('로그인 화면')),
    ],
  ); // 시험용 라우터
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

/// 작성: 2026-10-11 19:11:50 · nada
/// 수정: 2026-10-18 09:41:12 · nada
/// 함수: main
/// 목적: 설정 화면의 작업자 칸을 시험한다. 로그인 작업자의 성명 · 사번 ·
///       업체 · 팀을 보여 주고 빈 칸은 빼는지, 로그아웃하면 로그인을 지우고
///       로그인 화면으로 가는지 본다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LoginSession.instance.current = null);

  testWidgets('로그인 작업자의 성명 · 사번 · 업체 · 팀을 보여 준다', (tester) async {
    LoginSession.instance.current = const Worker(
      employeeId: 'T00001',
      name: '홍길동',
      company: '(주)시험승강기',
      team: '설치1팀',
    );

    await _pumpSettings(tester);

    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('T00001'), findsOneWidget);
    expect(find.text('(주)시험승강기'), findsOneWidget);
    expect(find.text('설치1팀'), findsOneWidget);
    expect(find.text('성명이 리포트 엔지니어 칸에 찍힙니다'), findsOneWidget);
  });

  testWidgets('업체 · 팀이 빈 작업자는 그 줄을 빼고 보여 준다', (tester) async {
    LoginSession.instance.current = const Worker(
      employeeId: '200001',
      name: '김철수',
    );

    await _pumpSettings(tester);

    expect(find.text('김철수'), findsOneWidget);
    expect(find.text('업체'), findsNothing);
    expect(find.text('관리팀'), findsNothing);
  });

  testWidgets('로그아웃하면 로그인을 지우고 로그인 화면으로 간다', (tester) async {
    SharedPreferences.setMockInitialValues({'loginEmployeeId': 'T00001'});
    LoginSession.instance.current = const Worker(
      employeeId: 'T00001',
      name: '홍길동',
    );
    await _pumpSettings(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '로그아웃'));
    await tester.pumpAndSettle();
    // 대화상자 안의 "로그아웃" 은 제목과 확인 버튼 두 곳이다. 확인 버튼이 뒤다
    await tester.tap(
      find
          .descendant(of: find.byType(Dialog), matching: find.text('로그아웃'))
          .last,
    );
    await tester.pumpAndSettle();

    expect(find.text('로그인 화면'), findsOneWidget);
    expect(LoginSession.instance.current, isNull);
    expect(await PrefsStore.instance.loadLoginEmployeeId(), isNull);
  });
}
