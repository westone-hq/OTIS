import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/core/theme.dart';
import 'package:vibration_checker/domain/auth_repository.dart';
import 'package:vibration_checker/features/auth/login_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthRepository.instance = LocalAuthRepository();
  });

  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }

  group('LoginScreen Widget Tests (Phase 5-A)', () {
    testWidgets('사번 입력 + PW 동일 -> 로그인 성공 -> /home 이동', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), '123456');
      await tester.enterText(textFields.at(1), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
      expect(AuthRepository.instance.currentUserId, equals('123456'));
    });

    testWidgets('사번 입력 + PW 불일치 -> 에러 메시지 3중 표시 (색+아이콘+텍스트)', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '123456');
      await tester.enterText(textFields.at(1), 'wrongpw');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('아이디 또는 비밀번호를 확인하세요'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // 색상 검증
      final errorText = tester.widget<Text>(
        find.textContaining('아이디 또는 비밀번호를 확인하세요'),
      );
      expect(errorText.style?.color, equals(AppColors.red));
    });

    testWidgets('잘못된 사번 형식 4종 (12345, T1234, A12345, 1234) 각각 로그인 거부 및 에러 표시', (tester) async {
      final invalidIds = ['12345', 'T1234', 'A12345', '1234'];

      for (final invalidId in invalidIds) {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), invalidId);
        await tester.enterText(textFields.at(1), invalidId);
        await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
        await tester.pump();

        expect(
          find.textContaining('아이디 형식을 확인하세요'),
          findsOneWidget,
          reason: '$invalidId should show format error',
        );
        expect(
          find.byIcon(Icons.error_outline),
          findsOneWidget,
          reason: '$invalidId should display error icon',
        );
      }
    });
  });
}
