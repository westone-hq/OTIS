import 'package:go_router/go_router.dart';
import 'package:vibration_checker/domain/session/login_session.dart';
import 'package:vibration_checker/ui/features/history/history_screen.dart';
import 'package:vibration_checker/ui/features/home/home_screen.dart';
import 'package:vibration_checker/ui/features/login/login_screen.dart';
import 'package:vibration_checker/ui/features/measure/measuring_screen.dart';
import 'package:vibration_checker/ui/features/measure/start_screen.dart';
import 'package:vibration_checker/ui/features/result/result_screen.dart';
import 'package:vibration_checker/ui/features/settings/settings_screen.dart';

/// 작성: 2026-08-17 11:50:18 · 박건준
/// 수정: 2026-10-18 09:41:12 · nada
/// 변수: appRouter
/// 목적: 화면 전환을 URL 경로 기반으로 정의하는 앱 라우터. 경로 하나가
///       화면 하나에 대응한다. 라우트(route, 경로 하나와 그 경로에서
///       보여줄 화면을 연결한 등록 정보)는 아래와 같다.
///       - /login      로그인 (사번 · 비밀번호)
///       - /home       홈 · 현장정보 입력
///       - /start      측정 시작 (시간 선택, 거치 안내는 바텀 시트(bottom
///         sheet, 화면 아래에서 위로 올라오는 패널)로 별도 표시)
///       - /measuring  측정 중 라이브
///       - /result/:id 측정 결과 (지표 · 결과 비교 · 메일 · 테스트 재실행).
///         측정을 마쳤을 때와 저장 결과 목록에서 고를 때 함께 쓴다
///       - /history    저장 결과 목록
///       - /settings   설정
///       - `initialLocation` — 앱을 켰을 때 처음 보여줄 화면. `/home`으로
///         지정돼 있다
///       - `redirect` — 화면을 옮길 때마다 로그인 상태
///         (`LoginSession.instance.current`)를 본다. 로그인 전이면 어느
///         경로든 `/login` 으로, 로그인한 뒤 `/login` 이면 `/home` 으로
///         돌린다. 측정을 저장할 때 엔지니어 이름이 비지 않게 한다
final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (_, state) {
    final loggedIn = LoginSession.instance.current != null; // 로그인했는지
    final atLogin = state.matchedLocation == '/login'; // 로그인 화면인지
    if (!loggedIn && !atLogin) return '/login';
    if (loggedIn && atLogin) return '/home';
    return null;
  },
  routes: [
    // → 로직 이동: LoginScreen.build()
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    // → 로직 이동: HomeScreen.build()
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    // → 로직 이동: StartScreen.build()
    GoRoute(path: '/start', builder: (_, _) => const StartScreen()),
    // → 로직 이동: MeasuringScreen.build()
    GoRoute(path: '/measuring', builder: (_, _) => const MeasuringScreen()),
    // → 로직 이동: ResultScreen.build()
    GoRoute(
      path: '/result/:id',
      builder: (_, s) => ResultScreen(id: s.pathParameters['id'] ?? 'demo'),
    ),
    // → 로직 이동: HistoryScreen.build()
    GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
    // → 로직 이동: SettingsScreen.build()
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);
