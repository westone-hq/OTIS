import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/storage/login_store.dart';
import 'package:vibration_checker/domain/auth/login_session.dart';
import 'package:vibration_checker/ui/core/router.dart';
import 'package:vibration_checker/ui/features/login/login_screen.dart';

/// 작성: 2026-10-20 09:12:40 · 박건준
/// 함수: _location
/// 목적: 앱 라우터가 지금 보여 주는 경로를 읽는다.
/// 반환: 경로 (예: "/home")
String _location() => appRouter.routerDelegate.currentConfiguration.uri.path;

/// 작성: 2026-10-20 09:12:40 · 박건준
/// 함수: _waitForAsset
/// 목적: 명단 자산 읽기처럼 시험 시계 밖에서 도는 작업이 끝나기를 기다린 뒤
///       화면을 다시 그린다.
/// 인자: tester — 위젯 시험 도구
Future<void> _waitForAsset(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

/// 작성: 2026-10-20 09:12:40 · 박건준
/// 함수: main
/// 목적: 앱의 실제 라우터(`appRouter`)와 실제 명단 자산으로 로그인 흐름을
///       끝까지 시험한다. 로그인 전에는 어느 경로로 가도 로그인 화면이고,
///       명단의 사번으로 화면에서 로그인하면 홈으로 가며, 로그인 뒤 로그인
///       화면으로 가려 하면 홈으로 돌리고, 로그아웃하면 다시 막는지 본다.
///       앱을 다시 켤 때의 되살리기도 실제 명단으로 본다. 사번은 시험
///       코드에 적지 않고 실행할 때 자산의 첫 줄을 쓴다.
void main() {
  late String firstId; // 명단 첫 줄의 사번

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final source = await rootBundle.loadString(LoginStore.directoryAsset);
    final rows =
        (jsonDecode(source) as Map<String, Object?>)['workers'] as List;
    firstId = (rows.first as Map<String, Object?>)['id'] as String;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LoginSession.instance.current = null;
  });

  tearDown(() => LoginSession.instance.current = null);

  testWidgets('로그인 전에는 어느 경로든 로그인 화면이고, 로그인하면 홈으로 간다', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    appRouter.go('/home');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(_location(), '/login');

    for (final path in <String>[
      '/settings',
      '/history',
      '/start',
      '/result/x',
    ]) {
      appRouter.go(path);
      await tester.pumpAndSettle();
      expect(_location(), '/login', reason: '$path 은 로그인 전에 막혀야 한다');
    }

    await tester.enterText(find.byType(TextField).at(0), firstId.toLowerCase());
    await tester.enterText(find.byType(TextField).at(1), firstId);
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    await _waitForAsset(tester);

    expect(_location(), '/home');
    expect(LoginSession.instance.current?.employeeId, firstId);

    appRouter.go('/login');
    await tester.pumpAndSettle();
    expect(_location(), '/home', reason: '로그인 뒤에는 로그인 화면으로 가지 않는다');

    await tester.runAsync(LoginStore.instance.logout);
    appRouter.go('/home');
    await tester.pumpAndSettle();
    expect(_location(), '/login', reason: '로그아웃하면 다시 막는다');
  });

  test('기기에 남은 실제 사번으로 앱을 다시 켜면 로그인이 되살아난다', () async {
    SharedPreferences.setMockInitialValues({'loginEmployeeId': firstId});

    expect(await LoginStore.instance.restore(), isTrue);
    expect(LoginSession.instance.current?.employeeId, firstId);
  });
}
