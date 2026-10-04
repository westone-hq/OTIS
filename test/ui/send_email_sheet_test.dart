import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/ui/features/shared/send_email_sheet.dart';

/// 작성: 2026-10-04 16:44:32 · nada
/// 함수: _openSheet
/// 목적: 아래쪽 시스템 영역이 있는 화면에서 메일 시트를 띄운다.
/// 인자: tester — 위젯 시험 도구
///       bottomInset — 아래쪽 시스템 영역 높이 (논리 픽셀)
Future<void> _openSheet(WidgetTester tester, {double bottomInset = 0}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: EdgeInsets.only(bottom: bottomInset)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showSendEmailSheet(context, jobId: '20260114-110359'),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

/// 작성: 2026-10-04 16:44:32 · nada
/// 함수: _checked
/// 목적: 받는 사람 목록에서 한 주소의 체크 상태를 읽는다.
/// 인자: tester — 위젯 시험 도구
///       email — 찾을 주소
/// 반환: 체크돼 있으면 true
bool _checked(WidgetTester tester, String email) {
  final row = find.ancestor(of: find.text(email), matching: find.byType(Row));
  final box = tester.widget<Checkbox>(
    find.descendant(of: row.first, matching: find.byType(Checkbox)),
  ); // 그 줄의 체크박스
  return box.value ?? false;
}

/// 작성: 2026-10-04 16:44:32 · nada
/// 함수: main
/// 목적: 메일 시트가 등록된 주소를 전부 보여주고 지난번 보낸 주소만 미리
///       고르는지, 여러 개를 고를 수 있는지, 보내기 버튼이 아래쪽 시스템
///       영역에 가리지 않는지 시험한다.
void main() {
  testWidgets('지난번 보낸 주소만 미리 고른다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com', 'b@otis.com', 'c@otis.com'],
      'lastRecipients': <String>['b@otis.com'],
    });

    await _openSheet(tester);

    expect(_checked(tester, 'a@otis.com'), isFalse);
    expect(_checked(tester, 'b@otis.com'), isTrue);
    expect(_checked(tester, 'c@otis.com'), isFalse);
  });

  testWidgets('여러 주소를 함께 고를 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com', 'b@otis.com'],
      'lastRecipients': <String>['b@otis.com'],
    });

    await _openSheet(tester);
    await tester.tap(find.text('a@otis.com'));
    await tester.pumpAndSettle();

    expect(_checked(tester, 'a@otis.com'), isTrue);
    expect(_checked(tester, 'b@otis.com'), isTrue);
  });

  testWidgets('보내기 버튼이 아래쪽 시스템 영역 위에 놓인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });
    const inset = 48.0; // 홈 · 뒤로 키 막대 높이로 잡은 값

    await _openSheet(tester, bottomInset: inset);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final button = tester.getRect(find.widgetWithText(ElevatedButton, '보내기'));
    expect(button.bottom, lessThanOrEqualTo(screen.height - inset));
  });
}
