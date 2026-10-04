import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/ui/features/measure/placement_sheet.dart';

/// 작성: 2026-10-04 16:54:15 · nada
/// 함수: main
/// 목적: 거치 안내가 휴대폰 크기 화면에서 넘치지 않고, 어려운 말(축 이름)
///       대신 그림 기준 문구와 볼륨키 종료를 안내하는지 시험한다.
void main() {
  testWidgets('작은 화면에서도 넘치지 않고 볼륨키 종료를 안내한다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlacementSheet())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('그림과 같은 방향'), findsOneWidget);
    expect(find.textContaining('볼륨키'), findsOneWidget);
    expect(find.textContaining('축'), findsNothing);
  });
}
