import 'package:flutter_test/flutter_test.dart';
import 'package:otis_vibration_prototype/main.dart';

void main() {
  testWidgets('Measurement screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OtisVibrationApp());

    expect(find.text('엘리베이터 진동 측정'), findsOneWidget);
    expect(find.text('측정 안내'), findsOneWidget);
    expect(find.text('측정 시작'), findsOneWidget);
    expect(find.text('측정 종료'), findsOneWidget);
  });
}
