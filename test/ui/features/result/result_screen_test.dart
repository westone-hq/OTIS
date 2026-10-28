import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vibration_checker/adapter/storage/measurement_repository.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/ui/features/result/result_charts_screen.dart';
import 'package:vibration_checker/ui/features/result/result_screen.dart';

/// 작성: 2026-10-04 18:15:24 · 박건준
/// 클래스: _TempPathProvider
/// 목적: 저장소의 기준 폴더를 시험마다 새로 만든 임시 폴더로 바꿔 끼운다.
class _TempPathProvider extends PathProviderPlatform {
  /// 임시 폴더 경로
  final String root;

  /// 작성: 2026-10-04 18:15:24 · 박건준
  /// 함수: _TempPathProvider
  /// 목적: 돌려줄 임시 폴더 경로를 받는다.
  /// 인자: root — 임시 폴더 경로
  _TempPathProvider(this.root);

  /// 작성: 2026-10-04 18:15:24 · 박건준
  /// 함수: getExternalStoragePath
  /// 목적: 외부 저장소 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getExternalStoragePath() async => root;

  /// 작성: 2026-10-04 18:15:24 · 박건준
  /// 함수: getApplicationDocumentsPath
  /// 목적: 앱 문서 폴더 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// 작성: 2026-10-04 18:15:24 · 박건준
/// 수정: 2026-10-11 19:09:59 · 박건준
/// 함수: _result
/// 목적: 결과 화면에 띄울 측정 결과를 꾸민다. 기본은 지금 필수 항목(주소 ·
///       우편번호 · 하중)을 다 갖춘 결과다.
/// 인자: id — 측정 ID
///       measuredAt — 측정 시각
///       zPtp — Z축 진동 P2P (mg)
///       legacy — true 면 하중 · 우편번호를 받기 전의 예전 결과
/// 반환: 측정 결과
MeasurementResult _result(
  String id,
  DateTime measuredAt,
  double zPtp, {
  bool legacy = false,
}) {
  return MeasurementResult(
    id: id,
    jobNo: 'J-1',
    siteName: '현장',
    address: '서울시',
    bottomFloor: 1,
    topFloor: 8,
    direction: '상승',
    model: 'Gen2',
    load: legacy ? null : 2000.0,
    loadUnit: legacy ? null : 'kg',
    postalCode: legacy ? null : '06236',
    dateTime: measuredAt,
    xPtp: 26.0,
    yPtp: 5.0,
    zPtp: zPtp,
    noiseMax: 45.0,
    distance: 57.1,
    maxSpeed: 1.74,
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

/// 작성: 2026-10-04 18:15:24 · 박건준
/// 함수: _settle
/// 목적: 파일 읽기처럼 시험 시계 밖에서 도는 작업이 끝날 틈을 준 뒤 화면을
///       다시 그린다.
/// 인자: tester — 위젯 시험 도구
Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 40; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1)); // 시트가 올라오는 움직임
}

/// 작성: 2026-10-04 18:15:24 · 박건준
/// 함수: main
/// 목적: 결과 화면이 지표 아홉 줄을 보여주고 기준을 넘은 값만 표시하는지,
///       다른 저장 결과와 비교하는지, 재실행 전에 운전 방향을 묻는지
///       시험한다.
void main() {
  late Directory temp; // 이번 시험이 쓸 임시 폴더

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('otis_result_screen');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  testWidgets('X · Y · Z 평균 · 최대와 소음 · 거리 · 속도 아홉 줄을 보이고 넘은 값에 경고를 붙인다', (
    tester,
  ) async {
    await tester.runAsync(
      () => MeasurementRepository.instance.save(
        _result(
          '20260114-110359',
          DateTime(2026, 1, 14, 11, 3, 59),
          31.0,
        ).copyWith(xA95: 14.0, yA95: 5.0, zA95: 22.0),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ResultScreen(id: '20260114-110359')),
    );
    await _settle(tester);

    for (final label in <String>[
      'X축 진동 평균 [mg]',
      'X축 진동 최대 [mg]',
      'Y축 진동 평균 [mg]',
      'Y축 진동 최대 [mg]',
      'Z축 진동 평균 [mg]',
      'Z축 진동 최대 [mg]',
      '소음 최대 [dBA]',
      '운행 거리 [m]',
      '최대 속도 [m/s]',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.textContaining('Peak to Peak'), findsNothing);
    expect(find.textContaining('수직'), findsNothing);
    expect(find.textContaining('수평'), findsNothing);
    expect(find.text('26.0'), findsOneWidget);
    expect(find.text('1.74'), findsOneWidget, reason: '리포트와 같은 둘째 자리');
    expect(
      find.byIcon(Icons.error_outline),
      findsNWidgets(4),
      reason: 'X 평균(13.5 초과) · X 최대(25.5) · Z 평균(21) · Z 최대(30)',
    );
    expect(
      find.text('13.5mg 초과 시 적색'),
      findsNWidgets(2),
      reason: 'X · Y 평균은 수평 기준',
    );
    expect(find.text('21mg 초과 시 적색'), findsOneWidget, reason: 'Z 평균 수직');
    expect(
      find.text('25.5mg 초과 시 적색'),
      findsNWidgets(2),
      reason: '기준을 반올림해 26 으로 보이지 않는다',
    );
    expect(find.text('30mg 초과 시 적색'), findsOneWidget);
    expect(find.text('테스트 재실행'), findsOneWidget);
    expect(find.text('그래프 보기'), findsOneWidget);
    expect(find.text('측정 그래프'), findsNothing, reason: '그래프는 따로 연다');
  });

  testWidgets('그래프 보기를 누르면 그래프 화면이 열린다', (tester) async {
    await tester.runAsync(
      () => MeasurementRepository.instance.save(
        _result('20260114-110359', DateTime(2026, 1, 14, 11, 3, 59), 8.0),
      ),
    );
    final router = GoRouter(
      initialLocation: '/result/20260114-110359',
      routes: [
        GoRoute(
          path: '/result/:id',
          builder: (_, s) => ResultScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/result/:id/charts',
          builder: (_, s) => ResultChartsScreen(id: s.pathParameters['id']!),
        ),
      ],
    ); // 결과 · 그래프 두 경로
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _settle(tester);
    await tester.ensureVisible(find.text('그래프 보기'));
    await tester.tap(find.text('그래프 보기'));
    await _settle(tester);

    expect(find.text('측정 그래프'), findsOneWidget);
    expect(find.text('up_J-1 · 현장'), findsOneWidget);
    expect(find.text('X축 진동 [mg]'), findsOneWidget);
  });

  testWidgets('머리 카드 층은 출발 → 도착이라 하강이면 최상층부터다', (tester) async {
    await tester.runAsync(() async {
      await MeasurementRepository.instance.save(
        _result(
          '20260114-110359',
          DateTime(2026, 1, 14, 11, 3, 59),
          8.0,
        ).copyWith(direction: '하강'),
      );
      await MeasurementRepository.instance.save(
        _result('20260113-090000', DateTime(2026, 1, 13, 9), 8.0),
      );
    });

    await tester.pumpWidget(
      const MaterialApp(home: ResultScreen(id: '20260114-110359')),
    );
    await _settle(tester);
    expect(find.text('하강 · 8층 → 1층 · Gen2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(home: ResultScreen(id: '20260113-090000')),
    );
    await _settle(tester);
    expect(find.text('상승 · 1층 → 8층 · Gen2'), findsOneWidget);
  });

  testWidgets('거치 · 미보정 기종 경고는 띄우지 않는다 (2026-10-27)', (tester) async {
    for (final (minute, placement) in <(int, String?)>[
      (1, 'faceUp'),
      (2, 'tilted'),
      (3, null),
    ]) {
      final id = '20260114-11${minute.toString().padLeft(2, '0')}00';
      await tester.runAsync(
        () => MeasurementRepository.instance.save(
          _result(id, DateTime(2026, 1, 14, 11, minute), 8.0).copyWith(
            placement: placement,
            placementGravityZMg: 0.0,
            deviceModel: 'SM-A536N',
            deviceCompensation: 'none',
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: ResultScreen(id: id)));
      await _settle(tester);
      expect(find.textContaining('거치로 측정됨'), findsNothing, reason: placement);
      expect(find.textContaining('미보정 기종'), findsNothing, reason: placement);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.text('테스트 재실행'), findsOneWidget);
    }
  });

  testWidgets('다른 저장 결과를 골라 비교 값과 차이를 보여준다', (tester) async {
    await tester.runAsync(() async {
      await MeasurementRepository.instance.save(
        _result('20260114-110359', DateTime(2026, 1, 14, 11, 3, 59), 20.0),
      );
      await MeasurementRepository.instance.save(
        _result('20260113-090000', DateTime(2026, 1, 13, 9), 8.0),
      );
    });

    await tester.pumpWidget(
      const MaterialApp(home: ResultScreen(id: '20260114-110359')),
    );
    await _settle(tester);
    await tester.tap(find.text('결과 비교'));
    await _settle(tester);
    await tester.tap(find.text('2026-01-13 09:00'));
    await tester.pumpAndSettle();

    expect(find.text('비교 8.0'), findsOneWidget);
    expect(find.text('차이 +12.0'), findsOneWidget, reason: 'Z: 20.0 − 8.0');
    expect(find.text('비교 해제'), findsOneWidget);
  });

  testWidgets('테스트 재실행은 운전 방향부터 묻고 상승 · 하강을 같은 모양으로 나란히 둔다', (tester) async {
    await tester.runAsync(
      () => MeasurementRepository.instance.save(
        _result('20260114-110359', DateTime(2026, 1, 14, 11, 3, 59), 20.0),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ResultScreen(id: '20260114-110359')),
    );
    await _settle(tester);
    await tester.tap(find.text('테스트 재실행'));
    await tester.pumpAndSettle();

    expect(find.text('운전 방향 확인'), findsOneWidget);
    final up = find.widgetWithText(OutlinedButton, '상승'); // 상승 버튼
    final down = find.widgetWithText(OutlinedButton, '하강'); // 하강 버튼
    expect(up, findsOneWidget);
    expect(down, findsOneWidget, reason: '둘 다 같은 테두리 버튼이다');
    final upRect = tester.getRect(up); // 상승 버튼 자리
    final downRect = tester.getRect(down); // 하강 버튼 자리
    expect(upRect.center.dy, closeTo(downRect.center.dy, 0.5), reason: '한 줄');
    expect(upRect.right, lessThan(downRect.left), reason: '상승이 왼쪽');
    expect(upRect.width, closeTo(downRect.width, 0.5), reason: '같은 폭');
    expect(upRect.height, greaterThanOrEqualTo(56));

    await tester.tap(down);
    await tester.pumpAndSettle();
    expect(find.text('운전 방향 확인'), findsNothing, reason: '고르면 닫힌다');
  });

  testWidgets('필수 항목이 빠진 예전 결과는 재실행하지 않고 홈 입력을 안내한다', (tester) async {
    await tester.runAsync(
      () => MeasurementRepository.instance.save(
        _result(
          '20260114-110359',
          DateTime(2026, 1, 14, 11, 3, 59),
          20.0,
          legacy: true,
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ResultScreen(id: '20260114-110359')),
    );
    await _settle(tester);
    await tester.tap(find.text('테스트 재실행'));
    await tester.pumpAndSettle();

    expect(find.text('현장 정보 확인'), findsOneWidget);
    expect(find.textContaining('홈에서 빠진 항목을 입력한 뒤 측정하세요'), findsOneWidget);
    expect(find.text('운전 방향 확인'), findsNothing);
  });

  testWidgets('없는 결과는 찾을 수 없다고 알린다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ResultScreen(id: 'none')));
    await _settle(tester);

    expect(find.text('측정 결과를 찾을 수 없습니다.'), findsOneWidget);
    expect(find.text('테스트 재실행'), findsNothing);
  });
}
