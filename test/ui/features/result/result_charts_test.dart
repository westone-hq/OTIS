import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/ui/features/result/result_charts.dart';

import '../../../support/reference_records.dart';

/// 작성: 2026-10-27 10:00:00 · 박건준
/// 변수: _titles
/// 목적: 결과 화면 그래프 카드 제목과 차례.
const List<String> _titles = <String>[
  'X축 진동 [mg]',
  'Y축 진동 [mg]',
  'Z축 진동 [mg]',
  '소음 [dBA]',
];

/// 작성: 2026-10-27 10:00:00 · 박건준
/// 함수: _pump
/// 목적: 그래프 묶음을 스크롤 화면에 띄운다. 폭은 현장 폰 최소 폭(360dp)에
///       화면 여백을 뺀 자리다.
/// 인자: tester — 위젯 시험 도구
///       result — 그릴 측정 결과
Future<void> _pump(WidgetTester tester, MeasurementResult result) async {
  tester.view.physicalSize = const Size(360, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ResultCharts(result: result),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 작성: 2026-10-27 10:00:00 · 박건준
/// 함수: main
/// 목적: 결과 화면 그래프가 실측 기록의 네 파형을 오류 없이 그리고, 파형이
///       없는 측정은 빈 틀 대신 글로 알리는지 시험한다.
void main() {
  testWidgets('실측 기록은 진동 세 축 · 소음 네 장을 그린다', (tester) async {
    final result = assembleRecord(rideReferencePath).result!; // 실측 결과
    await _pump(tester, result);

    for (final title in _titles) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('기록된 파형이 없습니다'), findsNothing);
    expect(
      find.text('가로: 시간 [s] · 빨간 점: 정속 구간 Peak to Peak 두 지점'),
      findsOneWidget,
    );
    expect(find.text('가로: 시간 [s] · 빨간 점: 운행 구간 소음 최대'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '그리다 실패하지 않는다');
  });

  testWidgets('파형이 없는 측정은 카드마다 없다고 적는다', (tester) async {
    final empty = MeasurementResult(
      id: '20261027-100000',
      jobNo: 'J-1',
      siteName: '현장',
      bottomFloor: 1,
      topFloor: 8,
      direction: '상승',
      dateTime: DateTime(2026, 10, 27, 10),
      xSeries: const <double>[],
      ySeries: const <double>[],
      zSeries: const <double>[],
      noiseSeries: const <double>[],
      positionSeries: const <double>[],
      speedSeries: const <double>[],
      accelSeries: const <double>[],
      jerkSeries: const <double>[],
    ); // 시계열을 싣지 않은 결과
    await _pump(tester, empty);

    for (final title in _titles) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('기록된 파형이 없습니다'), findsNWidgets(4));
    expect(find.textContaining('가로: 시간'), findsNothing);
  });
}
