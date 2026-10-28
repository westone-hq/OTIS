import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/ui/features/login/login_screen.dart';
import 'package:vibration_checker/ui/features/update/update_prompt.dart';

import '../../../support/fake_update_server.dart';

/// 작성: 2026-10-28 10:50:00 · 박건준
/// 함수: main
/// 목적: 로그인하지 않은 채 앱을 켜도 로그인 화면에 업데이트 창이 뜨는지
///       시험한다. 필수 업데이트(설치 빌드 11 < minimum 12)라 "나중에" 가
///       없고 뒤로가기로 닫히지 않아야 한다 — 로그인 앞에서 막히면 이
///       빌드를 계속 쓰게 된다. 시작 확인 기록은 앱 실행 전체에 하나라
///       시나리오마다 파일을 나눈다.
void main() {
  testWidgets('로그인 전 로그인 화면에 필수 업데이트 창이 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final server = FakeUpdateServer(); // 바로 응답하는 가짜 서버
    final prompt = UpdatePrompt(checker: server.checker(build: 11));
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginScreen(updatePrompt: prompt),
        ),
      ],
    ); // 로그인 화면만 있는 라우터
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(server.requests, 1);
    expect(find.text('새 버전이 있습니다'), findsOneWidget);
    expect(find.textContaining('이 버전은 더 이상 사용할 수 없습니다'), findsOneWidget);
    expect(find.text('나중에'), findsNothing);

    await tester.binding.handlePopRoute(); // 뒤로가기
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있습니다'), findsOneWidget, reason: '필수 창은 닫히지 않는다');
  });
}
