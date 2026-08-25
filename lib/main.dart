import 'package:flutter/material.dart';

import 'ui/core/router.dart';
import 'ui/core/theme.dart';

/// 작성: 2026-08-17 11:15:41 · 박건준
/// 함수: main
/// 목적: 앱 실행 진입점.
///       - `WidgetsFlutterBinding.ensureInitialized()` — 프레임워크 바인딩
///         (binding, 위젯 트리(widget tree, 화면을 이루는 위젯들이 부모-
///         자식 구조로 이어진 것)가 화면·센서 등 실제 엔진 기능을 쓸 수
///         있도록 연결하는 초기화 과정)을 실행한다.
///       - `runApp(...)` — 초기화된 바인딩 위에 앱 위젯 트리를 올려 화면을
///         그리기 시작한다.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VibrationCheckerApp()); // → 로직 이동: VibrationCheckerApp.build()
}

/// 작성: 2026-08-17 11:15:41 · 박건준
/// 클래스: VibrationCheckerApp
/// 목적: 앱의 최상위 위젯. 실제 구성은 `build()`에서 한다.
class VibrationCheckerApp extends StatelessWidget {
  const VibrationCheckerApp({super.key});

  /// 작성: 2026-08-17 11:15:41 · 박건준
  /// 함수: build
  /// 목적: 앱의 최상위 설정을 구성한다. 화면 전환 자체는 `appRouter`
  ///       (앱 라우터. GoRouter 패키지로 만든 것으로, URL 경로 하나하나를
  ///       화면 하나에 대응시켜 전환을 관리해준다)가 맡고, 이 함수는
  ///       앱 전역 설정만 채운다.
  ///       - `title` — 앱 제목 (기기 최근 실행 목록 등에 노출)
  ///       - `color` — 앱 기본 배경색 (`AppColors.bg`)
  ///       - `theme` — 앱 전역 테마 (`buildAppTheme()`)
  ///       - `routerConfig` — 화면 라우팅 설정 (`appRouter`)
  ///       - `debugShowCheckedModeBanner` — 디버그 모드 "DEBUG" 배너 숨김
  ///         (false)
  /// 인자: context — 위젯 트리 상 빌드 위치 정보. `StatelessWidget.build`를
  ///       오버라이드(override, 상위 클래스가 정해둔 메서드를 하위 클래스가
  ///       자신의 내용으로 다시 정의하는 것)하는 시그니처(signature, 함수의
  ///       이름·매개변수·반환 타입 등 겉모습)라 항상 받아야 하는 인자라서
  ///       적혀 있을 뿐, 이 함수 내부에서는 실제로 쓰지 않는다
  /// 반환: 앱 루트로 쓰이는 `MaterialApp.router` 위젯
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OTIS 진동 측정',
      color: AppColors.bg,
      theme: buildAppTheme(),
      routerConfig: appRouter, // → 로직 이동: appRouter
      debugShowCheckedModeBanner: false,
    );
  }
}
