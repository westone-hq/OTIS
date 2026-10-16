import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vibration_checker/ui/core/theme.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 변수: shotSizes
/// 목적: 캡처할 기기 화면 크기 (dp). 현장에서 흔한 좁은 폰과 넓은 폰이다.
/// 근거: 인용 — 2026-10-15 점검 지시 "360×800 dp, 412×915 dp, 배율 2"
const List<Size> shotSizes = <Size>[Size(360, 800), Size(412, 915)];

/// 작성: 2026-10-15 16:50:04 · nada
/// 변수: shotPixelRatio
/// 목적: 캡처 배율. 360 dp 폭이 720 픽셀 그림이 된다.
const double shotPixelRatio = 2.0;

/// 작성: 2026-10-15 16:50:04 · nada
/// 변수: shotKey
/// 목적: 캡처할 범위(앱 전체)를 감싸는 경계의 열쇠. 대화상자 · 바텀
///       시트도 앱 안 겹 위에 그려져 함께 찍힌다.
const GlobalObjectKey shotKey = GlobalObjectKey('screenshot-boundary');

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: shotOutputDir
/// 목적: 캡처를 쓸 폴더. 환경 변수 `SHOT_DIR` 이 있으면 그곳, 없으면
///       `build/screenshots/`.
/// 반환: 만들어 둔 폴더
Directory shotOutputDir() {
  final dir = Directory(
    Platform.environment['SHOT_DIR'] ?? 'build/screenshots',
  ); // 쓸 폴더
  dir.createSync(recursive: true);
  return dir;
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: loadShotFonts
/// 목적: 시험 환경에서 한글 · 아이콘이 네모로 나오지 않게 글꼴을 올린다.
///       - 리포트용 나눔고딕(보통 · 굵게)을 앱 기본(Roboto)과 시험 기본
///         (FlutterTest) 이름으로 올린다. 글꼴 이름 없이 스타일을 넘기는
///         버튼 묶음 · 드롭다운도 한글로 나온다
///       - Flutter SDK 의 Material 아이콘 글꼴을 올린다
/// 근거: 측정 — 2026-10-15 시험 환경에서 확인. 앱바 제목처럼 글꼴 이름
///       없이 그리는 일부 글자는 여전히 시험 기본 글꼴로 그려져,
///       `shotTheme()` 이 그 스타일에 이름을 붙인다
Future<void> loadShotFonts() async {
  ByteData bytesOf(String path) =>
      ByteData.sublistView(File(path).readAsBytesSync());
  for (final family in <String>['Roboto', 'FlutterTest']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(bytesOf('assets/report/NanumGothic-Regular.ttf')))
      ..addFont(Future.value(bytesOf('assets/report/NanumGothic-Bold.ttf')));
    await loader.load();
  }
  final flutterRoot = // Flutter SDK 위치 (flutter 실행 파일의 두 단계 위)
      Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        bytesOf(
          '$flutterRoot/bin/cache/artifacts/material_fonts/'
          'materialicons-regular.otf',
        ),
      ),
    );
  await icons.load();
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: shotTheme
/// 목적: 앱 테마에 캡처용 글꼴 이름만 붙인다. 앱바 제목 · 버튼 글자
///       스타일(`AppText.subhead` · `AppText.button`)이 글꼴 이름 없이 넘어가
///       시험 환경에서만 네모로 나오는 것을 막는다(기기에서는 기본 한글
///       글꼴로 나온다). 색 · 크기 · 굵기는 그대로다.
/// 반환: 캡처용 테마
ThemeData shotTheme() {
  final base = buildAppTheme(); // 앱 테마
  // 버튼 글자 스타일에 글꼴 이름을 붙인다. 상태별로 고르는 스타일이라 한
  // 번 풀어 이름을 붙인 뒤 모든 상태에 같은 값을 준다
  ButtonStyle? named(ButtonStyle? style) {
    final text = style?.textStyle?.resolve(<WidgetState>{}); // 글자 스타일
    if (style == null || text == null) return style;
    return style.copyWith(
      textStyle: WidgetStatePropertyAll(text.copyWith(fontFamily: 'Roboto')),
    );
  }

  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: named(base.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: named(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: named(base.textButtonTheme.style),
    ),
  );
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: setShotSize
/// 목적: 시험 화면을 기기 크기로 맞춘다. 시험이 끝나면 되돌린다.
/// 인자: tester — 위젯 시험 도구
///       size — 화면 크기 (dp)
void setShotSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = shotPixelRatio;
  tester.view.physicalSize = size * shotPixelRatio;
  addTearDown(tester.view.reset);
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: settle
/// 목적: 파일 읽기처럼 시험 시계 밖에서 도는 작업이 끝날 틈을 주며 화면을
///       다시 그린다.
/// 인자: tester — 위젯 시험 도구
///       rounds — 기다릴 횟수 (한 번 10ms)
Future<void> settle(WidgetTester tester, {int rounds = 30}) async {
  for (var round = 0; round < rounds; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 500)); // 화면 전환 움직임
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 수정: 2026-10-15 22:01:43 · nada
/// 함수: capture
/// 목적: `shotKey` 경계 안을 PNG 로 찍어 `shotOutputDir()` 에 쓴다. 찍기
///       전에 글꼴 이름 없는 글자에 이름을 붙인다(`_nameUnnamedFonts`).
/// 인자: tester — 위젯 시험 도구
///       name — 파일 이름 (확장자 없이)
Future<void> capture(WidgetTester tester, String name) async {
  _nameUnnamedFonts(tester);
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(shotKey),
  ); // 찍을 경계
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: shotPixelRatio); // 그림
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${shotOutputDir().path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// 작성: 2026-10-15 22:01:43 · nada
/// 함수: _nameUnnamedFonts
/// 목적: 글꼴 이름 없이 그려진 글자(운전 방향 버튼 묶음 · 드롭다운 선택
///       값처럼 위젯이 스타일을 그대로 넘기는 곳)를 캡처용 글꼴(Roboto 로
///       올린 나눔고딕)로 다시 그린다. 화면 위젯은 건드리지 않고 그려진
///       글자 묶음만 바꾼다.
/// 인자: tester — 위젯 시험 도구
/// 근거: 측정 — 2026-10-15 시험 환경에서 확인. 시험 실행기는 이름 없는
///       글자를 늘 내장 시험 글꼴로 그려(`--use-test-fonts`, 끌 수 없음)
///       한글이 네모, 영문이 검은 막대로 나온다. 같은 이름으로 글꼴을
///       올려도 내장 글꼴이 먼저다. 기기에서는 시스템 글꼴로 나온다
void _nameUnnamedFonts(WidgetTester tester) {
  // 글자 묶음 하나를 따라 내려가며 이름 없는 스타일에 이름을 붙인다
  InlineSpan named(InlineSpan span) {
    if (span is! TextSpan) return span;
    final style = span.style; // 이 묶음의 스타일
    return TextSpan(
      text: span.text,
      style: style != null && style.fontFamily == null
          ? style.copyWith(fontFamily: 'Roboto')
          : style,
      children: span.children?.map(named).toList(),
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel,
    );
  }

  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    if (paragraph.text.style?.fontFamily != null) continue;
    paragraph.text = named(paragraph.text);
  }
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: shotName
/// 목적: 화면 크기를 붙인 캡처 파일 이름을 만든다.
/// 인자: base — 번호 · 화면 · 상태 (예: "01_홈_빈칸")
///       size — 화면 크기
/// 반환: "01_홈_빈칸_360x800" 꼴
String shotName(String base, Size size) =>
    '${base}_${size.width.toInt()}x${size.height.toInt()}';

/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: TempPathProvider
/// 목적: 저장소의 기준 폴더를 캡처마다 새로 만든 임시 폴더로 바꿔 끼운다.
class TempPathProvider extends PathProviderPlatform {
  /// 임시 폴더 경로
  final String root;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: TempPathProvider
  /// 목적: 돌려줄 임시 폴더 경로를 받는다.
  /// 인자: root — 임시 폴더 경로
  TempPathProvider(this.root);

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: getExternalStoragePath
  /// 목적: 외부 저장소 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getExternalStoragePath() async => root;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: getApplicationDocumentsPath
  /// 목적: 앱 문서 폴더 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: getTemporaryPath
  /// 목적: 임시 폴더 자리 대신 임시 폴더를 돌려준다(메일 첨부 사본).
  @override
  Future<String?> getTemporaryPath() async => root;
}
