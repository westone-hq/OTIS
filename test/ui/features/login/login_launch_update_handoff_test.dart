import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/ui/features/home/home_screen.dart';
import 'package:vibration_checker/ui/features/login/login_screen.dart';
import 'package:vibration_checker/ui/features/update/update_prompt.dart';

import '../../../support/fake_update_server.dart';

/// 작성: 2026-10-28 10:50:00 · 박건준
/// 함수: main
/// 목적: 로그인 화면이 업데이트를 확인하는 동안 로그인해 홈으로 넘어가면,
///       떠난 로그인 화면 대신 홈 화면에 창이 한 번만 뜨는지 시험한다.
///       시작 확인 기록은 앱 실행 전체에 하나라 시나리오마다 파일을 나눈다.
void main() {
  testWidgets('확인 중에 홈으로 가면 홈에 창이 한 번 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final gate = Completer<void>(); // 서버 응답을 잡아 두는 문
    final server = FakeUpdateServer(gate: gate.future); // 늦게 응답하는 서버
    final prompt = UpdatePrompt(checker: server.checker(build: 12));
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginScreen(updatePrompt: prompt),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => HomeScreen(updatePrompt: prompt),
        ),
      ],
    ); // 로그인 · 홈 라우터
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(server.requests, 1, reason: '로그인 화면이 확인을 시작했다');

    router.go('/home'); // 로그인을 마친 것처럼 홈으로 간다
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있습니다'), findsNothing, reason: '아직 응답 전');

    gate.complete();
    await tester.pumpAndSettle();

    expect(server.requests, 2, reason: '홈 화면도 확인했다');
    expect(find.text('새 버전이 있습니다'), findsOneWidget);
    expect(find.text('나중에'), findsOneWidget, reason: '선택 업데이트');
    expect(find.byType(LoginScreen), findsNothing);
  });
}
