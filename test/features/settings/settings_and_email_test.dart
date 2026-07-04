import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/core/theme.dart';
import 'package:vibration_checker/domain/auth_repository.dart';
import 'package:vibration_checker/domain/repository/measurement_repository.dart';
import 'package:vibration_checker/features/settings/settings_screen.dart';
import 'package:vibration_checker/features/shared/send_email_sheet.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthRepository.instance = LocalAuthRepository();
    await AuthRepository.instance.login('123456', '123456');
    SendEmailSheet.overrideEmailSender = null;
    final tempDir = await Directory.systemTemp.createTemp('otis_test_email_');
    MeasurementRepository.instance.overrideBaseDir = tempDir.path;
  });

  Widget buildSettingsSubject() {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('Login Screen'))),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    );
    return MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }

  Widget buildEmailSheetSubject(String jobId) {
    return MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSendEmailSheet(context, jobId: jobId),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  group('SettingsScreen & SendEmailSheet (Phase 5-B & 5-C)', () {
    testWidgets('SettingsScreen: 로그인한 사용자 사번 표시 및 이메일 저장/로드', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email_123456', 'old@otis.com');

      await tester.pumpWidget(buildSettingsSubject());
      await tester.pumpAndSettle();

      // 프로필에 사번 표시 확인
      expect(find.text('123456'), findsOneWidget);
      expect(find.text('old@otis.com'), findsOneWidget);

      // 이메일 변경 및 저장
      final emailField = find.byType(TextField);
      await tester.enterText(emailField, 'new.worker@otis.com');
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pump();

      expect(prefs.getString('email_123456'), equals('new.worker@otis.com'));
      expect(find.text('저장되었습니다'), findsOneWidget);
    });

    testWidgets('SettingsScreen: 로그아웃 버튼 클릭 및 확인 시 로그아웃 호출 및 /login 이동', (tester) async {
      await tester.pumpWidget(buildSettingsSubject());
      await tester.pumpAndSettle();

      final logoutBtn = find.widgetWithText(OutlinedButton, '로그아웃');
      await tester.ensureVisible(logoutBtn);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(find.text('정말 로그아웃 하시겠습니까?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '로그아웃'));
      await tester.pumpAndSettle();

      expect(AuthRepository.instance.currentUserId, isNull);
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('SendEmailSheet: 이메일 미설정 시 보내기 클릭하면 등록 안내 다이얼로그 표시', (tester) async {
      await tester.pumpWidget(buildEmailSheetSubject('demo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('설정에서 이메일을 등록하세요'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '보내기'));
      await tester.pumpAndSettle();

      expect(find.text('이메일 등록 안내'), findsOneWidget);
      expect(find.textContaining('수신할 이메일 주소가 설정되지 않았습니다'), findsOneWidget);
    });

    testWidgets('SendEmailSheet: 이메일 설정 완료 시 발송 호출 및 안내 문구(작성창 호출) 표시', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email_123456', 'test@otis.com');

      Email? sentEmail;
      SendEmailSheet.overrideEmailSender = (email) async {
        sentEmail = email;
      };

      await tester.pumpWidget(buildEmailSheetSubject('2024F1447R01'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('test@otis.com'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, '보내기'));
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(find.textContaining('메일 작성창 호출 실패'), findsNothing);
      expect(sentEmail, isNotNull);
      expect(sentEmail!.recipients, equals(['test@otis.com']));
      expect(sentEmail!.subject, contains('TUNE Summary Report -'));
      expect(sentEmail!.attachmentPaths, isNotEmpty); // PDF 및 RAW 기본 첨부

      expect(find.textContaining('메일 작성창이 호출되었습니다 (첨부 구성 완료)'), findsOneWidget);
    });
  });
}
