import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/model/measurement_result.dart';
import 'package:vibration_checker/ui/features/history/history_screen.dart';
import 'package:vibration_checker/ui/features/result/result_screen.dart';

/// 작성: 2026-10-04 18:38:14 · nada
/// 클래스: _TempPathProvider
/// 목적: 저장소의 기준 폴더를 시험마다 새로 만든 임시 폴더로 바꿔 끼운다.
class _TempPathProvider extends PathProviderPlatform {
  /// 임시 폴더 경로
  final String root;

  /// 작성: 2026-10-04 18:38:14 · nada
  /// 함수: _TempPathProvider
  /// 목적: 돌려줄 임시 폴더 경로를 받는다.
  /// 인자: root — 임시 폴더 경로
  _TempPathProvider(this.root);

  /// 작성: 2026-10-04 18:38:14 · nada
  /// 함수: getExternalStoragePath
  /// 목적: 외부 저장소 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getExternalStoragePath() async => root;

  /// 작성: 2026-10-04 18:38:14 · nada
  /// 함수: getApplicationDocumentsPath
  /// 목적: 앱 문서 폴더 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// 작성: 2026-10-04 18:38:14 · nada
/// 함수: _result
/// 목적: 목록에 올릴 측정 결과를 꾸민다.
/// 인자: id — 측정 ID
///       jobNo — 제번
///       measuredAt — 측정 시각
/// 반환: 측정 결과
MeasurementResult _result(String id, String jobNo, DateTime measuredAt) {
  return MeasurementResult(
    id: id,
    jobNo: jobNo,
    siteName: '현장',
    bottomFloor: 1,
    topFloor: 8,
    direction: '상승',
    dateTime: measuredAt,
    xPtp: 5.0,
    yPtp: 5.0,
    zPtp: 20.0,
    noiseMax: 45.0,
    xSeries: const <double>[],
    ySeries: const <double>[],
    zSeries: const <double>[],
    noiseSeries: const <double>[],
    positionSeries: const <double>[],
    speedSeries: const <double>[],
    accelSeries: const <double>[],
    jerkSeries: const <double>[],
  );
}

/// 작성: 2026-10-04 18:38:14 · nada
/// 함수: _settle
/// 목적: 파일 읽기처럼 시험 시계 밖에서 도는 작업이 끝날 틈을 주며 화면을
///       다시 그린다.
/// 인자: tester — 위젯 시험 도구
Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 40; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1)); // 화면 전환 움직임
}

/// 작성: 2026-10-04 18:38:14 · nada
/// 함수: _app
/// 목적: 목록 화면에서 시작하고 결과 화면으로 넘어갈 수 있는 앱을 만든다.
/// 반환: 시험용 앱
Widget _app() {
  final router = GoRouter(
    initialLocation: '/history',
    routes: [
      GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(
        path: '/result/:id',
        builder: (_, s) => ResultScreen(id: s.pathParameters['id']!),
      ),
    ],
  ); // 시험용 화면 경로
  return MaterialApp.router(routerConfig: router);
}

/// 작성: 2026-10-04 18:38:14 · nada
/// 함수: main
/// 목적: 저장 결과 목록이 최근 것부터 보이고, 누르면 결과 화면이 열리고,
///       삭제되는지 시험한다.
void main() {
  late Directory temp; // 이번 시험이 쓸 임시 폴더

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('otis_history_screen');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
    await MeasurementRepository.instance.save(
      _result('20260113-090000', 'J-OLD', DateTime(2026, 1, 13, 9)),
    );
    await MeasurementRepository.instance.save(
      _result('20260114-110359', 'J-NEW', DateTime(2026, 1, 14, 11, 3, 59)),
    );
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  testWidgets('최근 것부터 상태 · 요약과 함께 보인다', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);

    final newer = tester.getTopLeft(find.text('J-NEW · 현장')); // 최근 줄 위치
    final older = tester.getTopLeft(find.text('J-OLD · 현장')); // 옛 줄 위치
    expect(newer.dy, lessThan(older.dy));
    expect(find.text('초과'), findsNWidgets(2), reason: 'Z 20mg 은 15mg 초과');
    expect(find.textContaining('Z 20.0mg 초과'), findsNWidgets(2));
  });

  testWidgets('한 줄을 누르면 그 측정의 결과 화면이 열린다', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await tester.tap(find.text('J-NEW · 현장'));
    await _settle(tester);

    expect(find.text('측정 결과'), findsOneWidget);
    expect(find.text('X축 진동 Peak to Peak [mg]'), findsOneWidget);
  });

  testWidgets('확인을 받고 한 건을 지운다', (tester) async {
    await tester.pumpWidget(_app());
    await _settle(tester);
    await tester.tap(find.byTooltip('측정 결과 삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await _settle(tester);

    expect(find.text('J-NEW · 현장'), findsNothing);
    expect(find.text('J-OLD · 현장'), findsOneWidget);
  });
}
