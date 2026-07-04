import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/domain/auth_repository.dart';
import 'package:vibration_checker/domain/models/measurement_result.dart';
import 'package:vibration_checker/domain/repository/measurement_repository.dart';
import 'package:vibration_checker/domain/sensor_channel.dart';
import 'package:vibration_checker/features/auth/login_screen.dart';
import 'package:vibration_checker/features/home/home_screen.dart';
import 'package:vibration_checker/features/history/history_screen.dart';
import 'package:vibration_checker/features/measure/measuring_screen.dart';
import 'package:vibration_checker/features/measure/placement_sheet.dart';
import 'package:vibration_checker/features/measure/start_screen.dart';
import 'package:vibration_checker/features/result/result_screen.dart';
import 'package:vibration_checker/features/settings/settings_screen.dart';
import 'package:vibration_checker/features/shared/measurement_session.dart';
import 'package:vibration_checker/features/shared/send_email_sheet.dart';
import 'package:vibration_checker/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthRepository.instance = LocalAuthRepository();
    final tempDir = await Directory.systemTemp.createTemp('otis_test_w7_');
    MeasurementRepository.instance.overrideBaseDir = tempDir.path;
  });

  testWidgets('앱 시작 시 /login 라우트에서 로그인 화면이 표시되는지 확인', (WidgetTester tester) async {
    await tester.pumpWidget(const VibrationCheckerApp());
    await tester.pumpAndSettle();

    // LoginScreen 위젯이 정상적으로 표시되는지 확인
    expect(find.byType(LoginScreen), findsOneWidget);

    // 주요 텍스트 및 UI 요소 검증
    expect(find.text('OTIS'), findsOneWidget);
    expect(find.text('진동 측정'), findsOneWidget);
    expect(find.text('아이디'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '로그인'), findsOneWidget);
  });

  testWidgets('S2 홈 화면 구성 요소 및 필수값 검증 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 주요 구성 요소 표시 확인
    expect(find.text('현장 정보'), findsOneWidget);
    expect(find.text('제번'), findsOneWidget);
    expect(find.text('현장명'), findsOneWidget);
    expect(find.text('운전 방향'), findsOneWidget);
    expect(find.text('기종'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('저장 결과'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '측정 시작'), findsOneWidget);

    // 아무 값도 입력하지 않고 측정 시작 버튼 누를 시 검증 오류 표시 확인
    await tester.tap(find.widgetWithText(ElevatedButton, '측정 시작'));
    await tester.pumpAndSettle();

    expect(find.text('제번을 입력하세요 (예: 2024F 1447R01)'), findsOneWidget);
    expect(find.text('현장명을 입력하세요 (예: 럭키종합건설/송정동근생)'), findsOneWidget);
    expect(find.text('최하층과 최상층을 모두 입력하세요'), findsOneWidget);
  });

  testWidgets('S3 측정 시작 화면 시간 선택 및 거치 안내 바텀 시트 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 최초 진입 시 자동 안내 시트 표시 확인 (또는 기본 화면 UI 확인)
    if (find.byType(PlacementSheet).evaluate().isNotEmpty) {
      expect(find.text('휴대폰 거치 방법'), findsOneWidget);
      expect(find.text('출입구'), findsOneWidget);
      expect(find.text('측정 중에는 조용히 해주세요'), findsOneWidget);

      // 시트 닫기
      await tester.tap(find.widgetWithText(ElevatedButton, '확인했습니다'));
      await tester.pumpAndSettle();
    }

    // StartScreen 기본 UI 확인
    expect(find.text('휴대폰을 카 바닥 중앙에 놓으세요'), findsOneWidget);
    expect(find.text('언제 측정을 시작할까요?'), findsOneWidget);
    expect(find.text('0초'), findsOneWidget);
    expect(find.text('5초'), findsOneWidget);
    expect(find.text('10초'), findsOneWidget);
    expect(find.text('15초'), findsOneWidget);
    expect(find.text('버튼을 누르면 5초 후 측정이 시작됩니다'), findsOneWidget);

    // 10초 선택 시 요약 문구 변경 확인
    await tester.tap(find.text('10초'));
    await tester.pumpAndSettle();
    expect(find.text('버튼을 누르면 10초 후 측정이 시작됩니다'), findsOneWidget);

    // 거치 방법 보기 버튼 클릭 시 바텀 시트 표시 확인
    await tester.tap(find.text('거치 방법 보기'));
    await tester.pumpAndSettle();

    expect(find.byType(PlacementSheet), findsOneWidget);
    expect(find.text('휴대폰 거치 방법'), findsOneWidget);
    expect(find.text('출입구'), findsOneWidget);
    expect(find.text('Y축'), findsOneWidget);
    expect(find.text('측정 중에는 조용히 해주세요'), findsOneWidget);
  });

  // 참고: 기존 위젯 테스트는 kDebugMode=true 환경이라 mock 폴백이 살아있어 그대로 통과한다.
  // 3초 무수신 릴리즈 경로는 위젯 테스트로 검증 불가(kDebugMode가 컴파일 타임 상수로 true 고정)하므로,
  // PENDING(실기기): 해당 릴리즈 격리 로직 및 중단 경로는 릴리즈 빌드에서 검증한다.
  testWidgets('S4 측정 중 라이브 화면 UI 및 중단 다이얼로그 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MeasuringScreen(),
      ),
    );
    await tester.pump();

    // 주요 텍스트 확인
    expect(find.text('테스트 진행 중...'), findsOneWidget);
    expect(find.text('현재 속도'), findsOneWidget);
    expect(find.text('미터/초'), findsOneWidget);
    expect(find.text('걸린 시간'), findsOneWidget);
    expect(find.text('테스트가 진행되는 동안 휴대폰을 들어 올리지 마세요'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '테스트 완료'), findsOneWidget);

    // 뒤로가기 버튼 클릭 시 중단 확인 다이얼로그 표시 확인
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('측정 중단'), findsOneWidget);
    expect(find.textContaining('진행 중인 측정 데이터는 저장되지 않습니다.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '계속 측정'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '중단하기'), findsOneWidget);

    // 계속 측정 버튼 누를 시 다이얼로그 닫힘 확인
    await tester.tap(find.widgetWithText(TextButton, '계속 측정'));
    await tester.pumpAndSettle();

    expect(find.text('측정 중단'), findsNothing);
  });

  testWidgets('S4 측정 완료 시 샘플 없음 -> 측정 실패 다이얼로그 노출 + repository.save 미호출', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '1',
      topFloor: '8',
      direction: '하부 → 상부',
      model: 'Gen2',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MeasuringScreen(),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, '테스트 완료'));
    await tester.pumpAndSettle();

    expect(find.text('측정 실패'), findsOneWidget);
    expect(find.textContaining('센서 데이터가 수집되지 않았습니다.'), findsOneWidget);
    expect(MeasurementSession.instance.lastResult, isNull);
  });

  testWidgets('S4 측정 중 백그라운드 전환(paused -> resumed) 시 중단 다이얼로그 노출 및 save 미호출', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '1',
      topFloor: '8',
      direction: '하부 → 상부',
      model: 'Gen2',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MeasuringScreen(sensorManager: FakeSensorChannelManager()),
      ),
    );
    await tester.pump();

    // 백그라운드 전환 (paused)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // 다시 포그라운드 전환 (resumed)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('측정이 중단되었습니다'), findsOneWidget);
    expect(find.textContaining('백그라운드로 전환되어'), findsOneWidget);
    expect(MeasurementSession.instance.lastResult, isNull);
  });

  testWidgets('S4 측정 완료 시 정상 샘플 -> 자동 저장 및 결과 화면 이동', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '1',
      topFloor: '8',
      direction: '하부 → 상부',
      model: 'Gen2',
    );

    final router = GoRouter(
      initialLocation: '/measuring',
      routes: [
        GoRoute(
          path: '/measuring',
          builder: (_, _) => MeasuringScreen(sensorManager: FakeSensorChannelManager()),
        ),
        GoRoute(
          path: '/result/:id',
          builder: (_, s) => ResultScreen(id: s.pathParameters['id'] ?? 'demo'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, '테스트 완료'));
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(MeasurementSession.instance.lastResult, isNotNull);
    expect(find.byType(ResultScreen), findsOneWidget);
  });

  testWidgets('S4 저장 실패 시 [재시도] 및 [확인] 다이얼로그 동작 검증', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '1',
      topFloor: '8',
      direction: '하부 → 상부',
      model: 'Gen2',
    );

    MeasurementRepository.instance.overrideBaseDir = 'Z:/non_existent_drive_999/test';

    final router = GoRouter(
      initialLocation: '/measuring',
      routes: [
        GoRoute(
          path: '/measuring',
          builder: (_, _) => MeasuringScreen(sensorManager: FakeSensorChannelManager()),
        ),
        GoRoute(
          path: '/result/:id',
          builder: (_, s) => ResultScreen(id: s.pathParameters['id'] ?? 'demo'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    await tester.tap(find.widgetWithText(ElevatedButton, '테스트 완료'));
    await tester.pumpAndSettle();

    expect(find.text('저장 실패 알림'), findsOneWidget);
    expect(find.text('재시도'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
    // 위젯 레벨 검증 부적합 (다이얼로그 애니메이션 반복 교착), 유닛으로 대체
  });

  test('S4 저장 재시도 로직 순수 유닛테스트 (attemptSave)', () async {
    final result = MeasurementResult.mock.copyWith(id: 'test_attempt_save');

    MeasurementRepository.instance.overrideBaseDir = 'Z:/';
    Directory? savedDir;
    final failResult = await MeasuringScreen.attemptSave(
      result,
      onSuccess: (dir) => savedDir = dir,
    );
    expect(failResult, false);
    expect(savedDir, null);

    final recoverDir = await Directory.systemTemp.createTemp('otis_recover_unit_');
    MeasurementRepository.instance.overrideBaseDir = recoverDir.path;
    final successResult = await MeasuringScreen.attemptSave(
      result,
      onSuccess: (dir) => savedDir = dir,
    );
    expect(successResult, true);
    expect(savedDir, isNotNull);
  });

  testWidgets('S4 저장 실패 시 [확인] 선택 -> 결과 화면으로 이동', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '1',
      topFloor: '8',
      direction: '하부 → 상부',
      model: 'Gen2',
    );

    MeasurementRepository.instance.overrideBaseDir = 'Z:/non_existent_drive_999/test';

    final router = GoRouter(
      initialLocation: '/measuring',
      routes: [
        GoRoute(
          path: '/measuring',
          builder: (_, _) => MeasuringScreen(sensorManager: FakeSensorChannelManager()),
        ),
        GoRoute(
          path: '/result/:id',
          builder: (_, s) => ResultScreen(id: s.pathParameters['id'] ?? 'demo'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    await tester.tap(find.widgetWithText(ElevatedButton, '테스트 완료'));
    await tester.pumpAndSettle();

    expect(find.text('저장 실패 알림'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '확인'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
  });

  testWidgets('S4 마이크 권한 거부 시 설정 안내 문구 포함 스낵바 노출 검증', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '1',
      topFloor: '8',
      direction: '하부 → 상부',
      model: 'Gen2',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeasuringScreen(sensorManager: AudioDeniedFakeSensorChannelManager()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('휴대폰 설정 > 애플리케이션 > OTIS 진동측정 > 권한에서 마이크를 허용해 주세요.'), findsOneWidget);
  });

  testWidgets('S4 하강 운행 모사(z 부호 반전 합성 스트림) -> 측정 5초 시점 표시 속도가 0.3 m/s 이상인지 확인', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '8',
      topFloor: '1',
      direction: '상부 → 하부',
      model: 'Gen2',
    );

    final router = GoRouter(
      initialLocation: '/measuring',
      routes: [
        GoRoute(
          path: '/measuring',
          builder: (_, _) => MeasuringScreen(sensorManager: DescentFakeSensorChannelManager()),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    final speedWidgetFinder = find.byWidgetPredicate((w) {
      if (w is Text && w.data != null) {
        final val = double.tryParse(w.data!);
        if (val != null && val >= 0.3) return true;
      }
      return false;
    });
    expect(speedWidgetFinder, findsWidgets);
  });

  testWidgets('S4 측정 완료 시 움직임 없음(합성 샘플 z 0) -> 게이트 다이얼로그 노출 및 [다시 측정] 시 save 미호출', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '1',
      topFloor: '8',
      direction: '하부 → 상부',
      model: 'Gen2',
    );

    final router = GoRouter(
      initialLocation: '/measuring',
      routes: [
        GoRoute(
          path: '/measuring',
          builder: (_, _) => MeasuringScreen(sensorManager: ZeroMotionFakeSensorChannelManager()),
        ),
        GoRoute(
          path: '/start',
          builder: (_, _) => const Scaffold(body: Text('StartScreen')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    await tester.tap(find.widgetWithText(ElevatedButton, '테스트 완료'));
    await tester.pumpAndSettle();

    expect(find.text('승강기 움직임이 감지되지 않았습니다'), findsOneWidget);
    expect(find.textContaining('측정 시간이 짧거나 이동이 거의 없습니다.'), findsOneWidget);
    expect(MeasurementSession.instance.lastResult, isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, '다시 측정'));
    await tester.pumpAndSettle();

    expect(find.text('StartScreen'), findsOneWidget);
    expect(MeasurementSession.instance.lastResult, isNull);
  });

  testWidgets('S4 측정 완료 시 움직임 없음 -> [그래도 저장] 선택 시 lowMotionWarning=true 로 저장 및 결과 화면 이동', (WidgetTester tester) async {
    MeasurementSession.instance.clear();
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2024F 1447R01',
      siteName: '럭키종합건설/송정동근생',
      bottomFloor: '1',
      topFloor: '8',
      direction: '하부 → 상부',
      model: 'Gen2',
    );

    final router = GoRouter(
      initialLocation: '/measuring',
      routes: [
        GoRoute(
          path: '/measuring',
          builder: (_, _) => MeasuringScreen(sensorManager: ZeroMotionFakeSensorChannelManager()),
        ),
        GoRoute(
          path: '/result/:id',
          builder: (_, s) => ResultScreen(id: s.pathParameters['id'] ?? 'demo'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, '테스트 완료'));
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(find.text('승강기 움직임이 감지되지 않았습니다'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(TextButton, '그래도 저장'));
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(MeasurementSession.instance.lastResult, isNotNull);
    expect(MeasurementSession.instance.lastResult!.lowMotionWarning, isTrue);
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('참고: 움직임 미감지 상태로 저장된 결과입니다'), findsOneWidget);
  });

  testWidgets('S5 결과 통합 화면 usedDetectedRideSegment false 시 안내 문구 노출 검증', (WidgetTester tester) async {
    final res = MeasurementResult.mock.copyWith(usedDetectedRideSegment: false);
    MeasurementSession.instance.lastResultId = 'test_fallback';
    MeasurementSession.instance.lastResult = res;

    await tester.pumpWidget(
      const MaterialApp(
        home: ResultScreen(id: 'test_fallback'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('참고: 주행 구간 자동검출 실패 — 전체 구간 기준 산출'), findsOneWidget);
  });

  testWidgets('S5 결과 통합 화면 요약 카드 및 차트 구성 요소 검증 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResultScreen(id: '2024F1447R01'),
      ),
    );
    await tester.pumpAndSettle();

    // 상단 요약 한 줄 확인
    expect(find.textContaining('2024F 1447R01 · 럭키종합건설/송정동근생'), findsOneWidget);

    // 6지표 카드 라벨 및 값 확인
    expect(find.text('X축 진동 (P2P)'), findsOneWidget);
    expect(find.text('Y축 진동 (P2P)'), findsOneWidget);
    expect(find.text('Z축 진동 (P2P)'), findsOneWidget);
    expect(find.text('최대 소음'), findsOneWidget);
    expect(find.text('운행 거리'), findsOneWidget);
    expect(find.text('최대 속도'), findsOneWidget);

    // 임계 판정 상태 태그 확인 (X/Z/소음 초과, Y 정상)
    expect(find.text('기준 초과'), findsWidgets);
    expect(find.text('정상'), findsOneWidget);

    // 차트 섹션 제목 확인
    expect(find.text('데이터 차트'), findsOneWidget);
    // 카드 탭 시 해당 차트 위치로 자동 스크롤 및 표시 확인
    await tester.tap(find.text('X축 진동 (P2P)'));
    await tester.pumpAndSettle();
    expect(find.text('1. X축 진동 (mg)'), findsOneWidget);

    // 이메일로 보내기 버튼 클릭 시 발송 바텀 시트 열림 확인
    await tester.tap(find.widgetWithText(ElevatedButton, '이메일로 보내기'));
    await tester.pumpAndSettle(); // 바텀 시트 애니메이션 대기
    expect(find.text('이메일 발송'), findsOneWidget);
    expect(find.text('설정에서 이메일을 등록하세요'), findsOneWidget);
  });

  testWidgets('S5 저장 결과 목록 화면 행 구성 요소 및 빈 상태 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 상단 타이틀 확인
    expect(find.text('저장된 결과'), findsOneWidget);

    // 3건의 mock 데이터 렌더링 확인
    expect(find.text('2024F 1447R01 · 럭키종합건설/송정동근생'), findsOneWidget);
    expect(find.text('2024F 1448R02 · 현대그린빌/아산건설'), findsOneWidget);
    expect(find.text('2024F 1449R03 · 삼성타운/강남프라임'), findsOneWidget);

    // 상태 표시(초과/정상) 및 뱃지 확인
    expect(find.text('초과'), findsWidgets);
    expect(find.text('정상'), findsWidgets);
    expect(find.text('PDF'), findsWidgets);
    expect(find.text('RAW'), findsWidgets);

    // 메일 아이콘 클릭 시 발송 바텀 시트 열림 확인
    await tester.tap(find.byIcon(Icons.mail_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('이메일 발송'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 목록 비우기 토글 버튼 클릭 시 빈 상태 화면 확인
    await tester.tap(find.byTooltip('목록 비우기'));
    await tester.pumpAndSettle();

    expect(find.text('저장된 결과가 없습니다'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '측정하러 가기'), findsOneWidget);
  });

  testWidgets('P7 이메일 발송 바텀 시트 구성 요소, 항목 선택 및 발송 테스트', (WidgetTester tester) async {
    await AuthRepository.instance.login('123456', '123456');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email_123456', 'test@otis.com');
    SendEmailSheet.overrideEmailSender = (email) async {};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showSendEmailSheet(ctx, jobId: '2024F1447R01'),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    // 시트 열기
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('이메일 발송'), findsOneWidget);
    expect(find.text('test@otis.com'), findsOneWidget);
    expect(find.text('PDF 리포트'), findsOneWidget);
    expect(find.text('RAW 데이터 파일'), findsOneWidget);
    expect(find.text('지표 요약(메일 본문)'), findsOneWidget);

    // 기본적으로 PDF와 RAW가 선택됨. 둘 다 해제 시 0개 선택 상태 확인
    await tester.tap(find.text('PDF 리포트'));
    await tester.pump();
    await tester.tap(find.text('RAW 데이터 파일'));
    await tester.pump();

    expect(find.text('보낼 항목을 선택하세요'), findsOneWidget);

    // 항목 1개(PDF 리포트) 다시 선택 후 발송 버튼 탭
    await tester.tap(find.text('PDF 리포트'));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, '보내기'));
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('메일 작성창이 호출되었습니다 (첨부 구성 완료)'), findsOneWidget);
  });

  testWidgets('P8 S6 설정 화면 정보 조회, 이메일 검증 및 로그아웃 다이얼로그 테스트', (WidgetTester tester) async {
    await AuthRepository.instance.login('123456', '123456');
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('Otis 직원'), findsOneWidget);
    expect(find.text('결과 수신 이메일'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);

    // 잘못된 이메일 형식 입력 검증
    await tester.enterText(find.byType(TextField), 'wrong-email');
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pump();

    expect(find.text('올바른 이메일 형식을 입력하세요.'), findsOneWidget);

    // 정상 이메일 입력 후 저장
    await tester.enterText(find.byType(TextField), 'test@otis.com');
    await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
    await tester.pump();

    expect(find.text('저장되었습니다'), findsOneWidget);

    // 로그아웃 다이얼로그 확인
    await tester.tap(find.widgetWithText(OutlinedButton, '로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('정말 로그아웃 하시겠습니까?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '로그아웃'), findsOneWidget);
  });
}

class FakeSensorChannelManager extends SensorChannelManager {
  FakeSensorChannelManager() : super(useMock: false);

  @override
  Future<bool> checkSensorsAvailable() async => true;

  @override
  Future<bool> requestAudioPermission() async => true;

  @override
  Future<void> startCapture({
    int targetSampleRate = 256,
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 85.0,
  }) async {}

  @override
  Future<void> stopCapture() async {}

  @override
  Stream<SensorSample> get sensorStream {
    return Stream.fromIterable(List.generate(2560, (index) {
      final tsUs = (index + 1) * 3906;
      final sec = index / 256.0;
      double z = 0.0;
      if (sec >= 1.0 && sec < 3.0) {
        z = 40.0;
      } else if (sec >= 7.0 && sec < 9.0) {
        z = -40.0;
      }
      return SensorSample(
        tsUs: tsUs,
        x: 0.0,
        y: 0.0,
        z: z,
        noiseDba: 55.0,
      );
    }));
  }
}

class ZeroMotionFakeSensorChannelManager extends SensorChannelManager {
  ZeroMotionFakeSensorChannelManager() : super(useMock: false);

  @override
  Future<bool> checkSensorsAvailable() async => true;

  @override
  Future<bool> requestAudioPermission() async => true;

  @override
  Future<void> startCapture({
    int targetSampleRate = 256,
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 85.0,
  }) async {}

  @override
  Future<void> stopCapture() async {}

  @override
  Stream<SensorSample> get sensorStream {
    return Stream.fromIterable(List.generate(2560, (index) {
      final tsUs = (index + 1) * 3906;
      return SensorSample(
        tsUs: tsUs,
        x: 0.0,
        y: 0.0,
        z: 0.0,
        noiseDba: 55.0,
      );
    }));
  }
}

class DescentFakeSensorChannelManager extends SensorChannelManager {
  DescentFakeSensorChannelManager() : super(useMock: false);

  @override
  Future<bool> checkSensorsAvailable() async => true;

  @override
  Future<bool> requestAudioPermission() async => true;

  @override
  Future<void> startCapture({
    int targetSampleRate = 256,
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 85.0,
  }) async {}

  @override
  Future<void> stopCapture() async {}

  @override
  Stream<SensorSample> get sensorStream {
    return Stream.periodic(const Duration(milliseconds: 4), (index) {
      if (index >= 2560) return null;
      final tsUs = (index + 1) * 3906;
      final sec = index / 256.0;
      double z = 0.0;
      if (sec >= 1.0 && sec < 3.0) {
        z = -40.0;
      } else if (sec >= 7.0 && sec < 9.0) {
        z = 40.0;
      }
      return SensorSample(
        tsUs: tsUs,
        x: 0.0,
        y: 0.0,
        z: z,
        noiseDba: 55.0,
      );
    }).takeWhile((s) => s != null).cast<SensorSample>();
  }
}

class AudioDeniedFakeSensorChannelManager extends FakeSensorChannelManager {
  @override
  Future<bool> requestAudioPermission() async => false;
}
