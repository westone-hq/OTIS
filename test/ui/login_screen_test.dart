import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/login_store.dart';
import 'package:vibration_checker/domain/session/login_session.dart';
import 'package:vibration_checker/ui/features/login/login_screen.dart';

import '../support/fake_worker_bundle.dart';

/// 작성: 2026-10-18 09:41:12 · nada
/// 함수: _pumpLogin
/// 목적: 시험용 명단을 읽는 로그인 화면과, 로그인하면 옮겨 갈 홈 자리
///       화면을 띄운다.
/// 인자: tester — 위젯 시험 도구
Future<void> _pumpLogin(WidgetTester tester) async {
  final store = LoginStore(bundle: FakeWorkerBundle()); // 시험용 명단 저장소
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => LoginScreen(store: store),
      ),
      GoRoute(path: '/home', builder: (_, _) => const Text('홈 화면')),
    ],
  ); // 시험용 라우터
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

/// 작성: 2026-10-18 09:41:12 · nada
/// 함수: _submit
/// 목적: 사번 · 비밀번호 칸을 채우고 "로그인" 을 누른다.
/// 인자: tester — 위젯 시험 도구
///       id — 사번 칸에 넣을 글자
///       password — 비밀번호 칸에 넣을 글자
Future<void> _submit(WidgetTester tester, String id, String password) async {
  await tester.enterText(find.byType(TextField).at(0), id);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
  // 명단 읽기는 실제 비동기 작업이라 시험 시계 밖에서 끝나기를 기다린다
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pumpAndSettle();
}

/// 작성: 2026-10-18 09:41:12 · nada
/// 함수: main
/// 목적: 로그인 화면이 맞는 사번 · 비밀번호면 홈으로 가고, 틀리면 사유에
///       맞는 칸에 문구를 띄우는지 시험한다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LoginSession.instance.current = null;
  });
  tearDown(() => LoginSession.instance.current = null);

  testWidgets('사번과 같은 비밀번호면 로그인하고 홈으로 간다', (tester) async {
    await _pumpLogin(tester);

    await _submit(tester, 't00001', 'T00001');

    expect(find.text('홈 화면'), findsOneWidget);
    expect(LoginSession.instance.current?.name, '홍길동');
  });

  testWidgets('명단에 없는 사번은 사번 칸에 알린다', (tester) async {
    await _pumpLogin(tester);

    await _submit(tester, 'T99999', 'T99999');

    expect(find.text('등록되지 않은 사번입니다.'), findsOneWidget);
    expect(LoginSession.instance.current, isNull);
  });

  testWidgets('비밀번호가 틀리면 비밀번호 칸에 알리고 칸을 비운다', (tester) async {
    await _pumpLogin(tester);

    await _submit(tester, 'T00001', '1234');

    expect(find.text('비밀번호가 맞지 않습니다.'), findsOneWidget);
    final password = tester.widget<TextField>(
      find.byType(TextField).at(1),
    ); // 비밀번호 칸
    expect(password.controller?.text, isEmpty);
  });

  testWidgets('빈 칸이면 그 칸에 입력을 요청한다', (tester) async {
    await _pumpLogin(tester);

    await _submit(tester, '', '');

    expect(find.text('사번을 입력하세요.'), findsOneWidget);
  });

  testWidgets('키보드가 열려도 로그인 버튼은 키보드 위에 보인다', (tester) async {
    // 2026-10-22 에뮬레이터: 키보드가 열리면 아래 고정 버튼이 키보드에 가려졌다
    const keyboardPx = 900.0; // 키보드 높이 (물리 픽셀)
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboardPx);
    addTearDown(tester.view.resetViewInsets);
    await _pumpLogin(tester);

    final screenBottom =
        tester.view.physicalSize.height /
        tester.view.devicePixelRatio; // 화면 아래 끝 (논리 픽셀)
    final keyboardTop =
        screenBottom - keyboardPx / tester.view.devicePixelRatio; // 키보드 위 끝
    final button = tester.getRect(
      find.widgetWithText(ElevatedButton, '로그인'),
    ); // 로그인 버튼 자리
    expect(button.bottom, lessThanOrEqualTo(keyboardTop));

    await _submit(tester, 't00001', 'T00001');
    expect(find.text('홈 화면'), findsOneWidget, reason: '가려지지 않아 누를 수 있다');
  });
}
