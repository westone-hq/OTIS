// 작성: 2026-08-17 11:50:18
// 작성자: 박건준

import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/measure/measuring_screen.dart';
import '../features/measure/start_screen.dart';
import '../features/result/result_screen.dart';
import '../features/settings/settings_screen.dart';

/// 변수: appRouter
/// 목적: 화면 전환을 URL 경로 기반으로 정의하는 앱 라우터. 경로 하나가
///       화면 하나에 대응한다. 로그인 화면은 라우트(route, 경로 하나와
///       그 경로에서 보여줄 화면을 연결한 등록 정보) 자체가 없다 (근거 참고).
///       - /home       홈 · 현장정보 입력
///       - /start      측정 시작 (시간 선택, 거치 안내는 바텀 시트(bottom
///         sheet, 화면 아래에서 위로 올라오는 패널)로 별도 표시)
///       - /measuring  측정 중 라이브
///       - /result/:id 결과 통합 (요약 카드 + 차트 스크롤). 신규 측정과
///         저장된 결과 조회 화면을 함께 쓴다
///       - /history    저장 결과 목록
///       - /settings   설정
///       - `initialLocation` — 앱을 켰을 때 처음 보여줄 화면. `/home`으로
///         지정돼 있다
/// 근거: script_explanations/01_overall_app_flow.md 1항 — 서버 API
///       (Application Programming Interface, 서버와 앱이 데이터를
///       주고받는 통신 규격)가 연결되지 않아 로그인 화면을 임시로
///       건너뛴다고 명시
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    // → 로직 이동: HomeScreen.build()
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    // → 로직 이동: StartScreen.build()
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
