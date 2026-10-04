import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/model/measurement_result.dart';
import 'package:vibration_checker/ui/features/result/result_screen.dart';

/// 작성: 2026-10-04 18:15:24 · nada
/// 클래스: _TempPathProvider
/// 목적: 저장소의 기준 폴더를 시험마다 새로 만든 임시 폴더로 바꿔 끼운다.
class _TempPathProvider extends PathProviderPlatform {
  /// 임시 폴더 경로
  final String root;

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: _TempPathProvider
  /// 목적: 돌려줄 임시 폴더 경로를 받는다.
  /// 인자: root — 임시 폴더 경로
  _TempPathProvider(this.root);

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: getExternalStoragePath
  /// 목적: 외부 저장소 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getExternalStoragePath() async => root;

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 함수: getApplicationDocumentsPath
  /// 목적: 앱 문서 폴더 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// 작성: 2026-10-04 18:15:24 · nada
/// 함수: _result
/// 목적: 결과 화면에 띄울 측정 결과를 꾸민다.
/// 인자: id — 측정 ID
///       measuredAt — 측정 시각
///       zPtp — Z축 진동 P2P (mg)
/// 반환: 측정 결과
MeasurementResult _result(String id, DateTime measuredAt, double zPtp) {
  return MeasurementResult(
    id: id,
    jobNo: 'J-1',
    siteName: '현장',
    address: '서울시',
    bottomFloor: 1,
    topFloor: 8,
    direction: '상승',
    model: 'Gen2',
    dateTime: measuredAt,
    xPtp: 12.0,
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

/// 작성: 2026-10-04 18:15:24 · nada
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

/// 작성: 2026-10-04 18:15:24 · nada
/// 함수: main
/// 목적: 결과 화면이 지표 여섯 줄을 보여주고 기준을 넘은 값만 표시하는지,
///       다른 저장 결과와 비교하는지 시험한다.
void main() {
  late Directory temp; // 이번 시험이 쓸 임시 폴더

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('otis_result_screen');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  testWidgets('지표 여섯 줄을 보여주고 기준을 넘은 값에 경고를 붙인다', (tester) async {
    await tester.runAsync(
      () => MeasurementRepository.instance.save(
        _result('20260114-110359', DateTime(2026, 1, 14, 11, 3, 59), 20.0),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ResultScreen(id: '20260114-110359')),
    );
    await _settle(tester);

    for (final label in <String>[
      'X축 진동 Peak to Peak [mg]',
      'Y축 진동 Peak to Peak [mg]',
      'Z축 진동 Peak to Peak [mg]',
      '소음 최대 [dBA]',
      '운행 거리 [m]',
      '최대 속도 [m/s]',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('12.0'), findsOneWidget);
    expect(find.text('1.74'), findsOneWidget);
    expect(
      find.byIcon(Icons.error_outline),
      findsNWidgets(2),
      reason: 'X(10 초과) · Z(15 초과)만 경고다',
    );
    expect(find.text('테스트 재실행'), findsOneWidget);
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

  testWidgets('없는 결과는 찾을 수 없다고 알린다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ResultScreen(id: 'none')));
    await _settle(tester);

    expect(find.text('측정 결과를 찾을 수 없습니다.'), findsOneWidget);
    expect(find.text('테스트 재실행'), findsNothing);
  });
}
