import 'package:go_router/go_router.dart';
import 'package:vibration_checker/domain/auth_repository.dart';

import '../features/auth/login_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/measure/measuring_screen.dart';
import '../features/measure/start_screen.dart';
import '../features/result/result_screen.dart';
import '../features/settings/settings_screen.dart';

/// 화면 6개 + 시트 2개 구조 (2026-07 확정)
/// /login      S1 로그인
/// /home       S2 홈·현장정보 입력
/// /start      S3 측정 시작(시간 선택, 거치 안내는 bottom sheet)
/// /measuring  S4 측정 중 라이브
/// /result/:id 결과 통합(요약 카드 + 차트 스크롤) - 신규/저장 공용
/// /history    S5 저장 결과 목록
/// /settings   S6 설정
final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final loggedIn = AuthRepository.instance.currentUserId != null;
    final isLoggingIn = state.matchedLocation == '/login';
    if (!loggedIn && !isLoggingIn) return '/login';
    if (loggedIn && isLoggingIn) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/start', builder: (_, _) => const StartScreen()),
    GoRoute(path: '/measuring', builder: (_, _) => const MeasuringScreen()),
    GoRoute(
      path: '/result/:id',
      builder: (_, s) => ResultScreen(id: s.pathParameters['id'] ?? 'demo'),
    ),
    GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);
