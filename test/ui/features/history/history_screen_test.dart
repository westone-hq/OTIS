import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vibration_checker/adapter/storage/measurement_repository.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
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
    zPtp: 32.0,
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
      // 테스트 재실행이 결과 화면과 바꿔 끼우는 측정 화면 자리
      GoRoute(
        path: '/measuring',
        builder: (_, _) => const Scaffold(body: Text('측정 중')),
      ),
    ],
  ); // 시험용 화면 경로
  _router = router;
  return MaterialApp.router(routerConfig: router);
}

/// 작성: 2026-10-22 12:20:00 · nada
/// 변수: _router
/// 목적: `_app()` 이 만든 경로 관리자. 재실행처럼 화면을 바꿔 끼우는 시험이
///       직접 부른다.
late GoRouter _router;

/// 작성: 2026-10-04 18:38:14 · nada
/// 함수: main
/// 목적: 저장 결과 목록이 최근 것부터 보이고, 누르면 결과 화면이 열리고,
///       삭제되는지, 읽지 못한 결과가 그 한 건만 따로 보이는지 시험한다.
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
    expect(find.text('초과'), findsNWidgets(2), reason: 'Z 32mg 은 30mg 초과');
    expect(find.textContaining('Z 32.0mg 초과'), findsNWidgets(2));
  });

  testWidgets('측정 일시가 깨진 결과는 그 한 건만 "읽을 수 없는 결과" 로 보인다', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory(
        '${temp.path}/captures/20260113-090000',
      ); // 일시를 망가뜨릴 폴더
      final file = File(
        '${dir.path}/${MeasurementRepository.resultFileName}',
      ); // 그 정본
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      map.remove('dateTime');
      await file.writeAsString(jsonEncode(map));
      await File(
        '${dir.path}/${MeasurementRepository.summaryFileName}',
      ).delete();
    });

    await tester.pumpWidget(_app());
    await _settle(tester);

    expect(find.text('J-NEW · 현장'), findsOneWidget, reason: '나머지는 정상');
    expect(find.text('J-OLD · 현장'), findsNothing);
    expect(find.text('읽을 수 없는 결과'), findsOneWidget);
    expect(find.textContaining('20260113-090000'), findsOneWidget);
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

  testWidgets('결과 화면에서 재실행해 새 결과가 생기면 돌아온 목록에 보인다', (tester) async {
    // 2026-10-22 에뮬레이터: 목록 → 결과 → 재실행(결과 화면을 측정 화면으로
    // 바꿔 끼움) → 새 결과 저장 → 뒤로 오면 새 결과가 목록에 없었다
    await tester.pumpWidget(_app());
    await _settle(tester);
    await tester.tap(find.text('J-OLD · 현장'));
    await _settle(tester);
    _router.pushReplacement('/measuring');
    await _settle(tester);
    await tester.runAsync(
      () => MeasurementRepository.instance.save(
        _result('20260115-080000', 'J-RERUN', DateTime(2026, 1, 15, 8)),
      ),
    );
    _router.pop();
    await _settle(tester);

    expect(find.text('J-RERUN · 현장'), findsOneWidget);
    expect(find.text('J-OLD · 현장'), findsOneWidget);
  });
}
