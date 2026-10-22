import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/storage/prefs_store.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/ui/features/home/home_screen.dart';

/// 작성: 2026-10-11 17:28:28 · nada
/// 변수: _startScreenText
/// 목적: 측정 시작이 통과했을 때 넘어가는 자리에 띄우는 문구. 시작 화면
///       대신 이 문구가 보이면 홈 화면이 `/start` 로 넘어간 것이다.
const String _startScreenText = '시작 화면 자리';

/// 작성: 2026-10-11 17:28:28 · nada
/// 함수: _pumpHome
/// 목적: 홈 화면을 길쭉한 화면에 띄운다. 입력칸이 모두 한 화면에 들어오게
///       해 스크롤 없이 누를 수 있게 하고, `/start` 로 넘어가는지 볼 수
///       있게 라우터를 단다.
/// 인자: tester — 위젯 시험 도구
Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/start',
            builder: (_, _) => const Scaffold(body: Text(_startScreenText)),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 작성: 2026-10-11 17:28:28 · nada
/// 함수: _field
/// 목적: 화면 위에서부터 n 번째 입력칸을 찾는다. 차례는 제번(0) ·
///       현장명(1) · 우편번호(2) · 주소(3) · 최하층(4) · 최상층(5) ·
///       하중(6) · 추가 참고사항(7) 이다.
/// 인자: index — 위에서부터의 차례
/// 반환: 그 입력칸을 찾는 조건
Finder _field(int index) => find.byType(TextField).at(index);

/// 작성: 2026-10-11 17:28:28 · nada
/// 함수: _fillRequired
/// 목적: 필수 입력칸을 검사를 통과하는 값으로 모두 채운다. 참고사항은
///       비워 둔다.
/// 인자: tester — 위젯 시험 도구
Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(_field(0), 'J-1');
  await tester.enterText(_field(1), '현장');
  await tester.enterText(_field(2), '10575');
  await tester.enterText(_field(3), '고양시 덕양구');
  await tester.enterText(_field(4), '1');
  await tester.enterText(_field(5), '8');
  await tester.enterText(_field(6), '2000');
  await tester.pumpAndSettle();
}

/// 작성: 2026-10-04 14:35:59 · nada
/// 수정: 2026-10-13 13:17:56 · nada
/// 함수: main
/// 목적: 홈 화면을 시험한다.
///       - 지난번 현장 정보로 입력창 · 선택지를 미리 채우는지, 선택지에
///         없는 저장값은 버리는지, 입력하는 즉시 저장하는지
///       - 새 입력칸(우편번호 · 하중 · 해석 종류 · 참고사항)이 보이는지
///       - 하중 단위가 고르는 버튼 없이 고정 글자 kg 로 보이는지, 단위를
///         고를 수 있던 빌드가 남긴 저장값(lb)을 오류 없이 읽는지
///       - 필수 항목이 빠지면 측정을 시작하지 않고 안내하는지, 참고사항만
///         비었을 때는 시작하는지, 참고사항은 저장하지 않는지
void main() {
  setUp(() => MeasurementSession.instance.currentSite = null);

  testWidgets('저장된 현장 정보로 입력창과 선택지를 채운다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lastSite': jsonEncode({
        'jobNo': '2024F 1447R01',
        'siteName': '현장',
        'address': '서울시 강남구',
        'postalCode': '06236',
        'bottomFloor': '1',
        'topFloor': '8',
        'direction': '하강',
        'model': '줄-로우프, 2:1',
        'load': '4400',
        'loadUnit': 'lb',
        'analysisType': '브레이크 기능',
      }),
    });

    await _pumpHome(tester);

    expect(find.text('2024F 1447R01'), findsOneWidget);
    expect(find.text('서울시 강남구'), findsOneWidget);
    expect(find.text('06236'), findsOneWidget);
    expect(find.text('4400'), findsOneWidget);
    expect(find.text('줄-로우프, 2:1'), findsOneWidget);
    expect(find.text('브레이크 기능'), findsOneWidget);
    expect(find.text('Gen2'), findsNothing);
    final segment = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    ); // 운전 방향 선택 버튼
    expect(segment.selected, {'하강'});
  });

  testWidgets('하중 단위는 고르는 버튼 없이 kg 고정 글자로 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lastSite': jsonEncode({'load': '4400', 'loadUnit': 'lb'}),
    }); // 단위를 고를 수 있던 빌드가 남긴 저장값

    await _pumpHome(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('4400'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('lb'), findsNothing);
    expect(
      find.byType(SegmentedButton<String>),
      findsOneWidget,
      reason: '남은 버튼 묶음은 운전 방향 하나다',
    );
  });

  testWidgets('선택지에 없는 저장값은 버리고 기본값을 둔다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lastSite': jsonEncode({
        'direction': '하부 → 상부',
        'model': '없는 기종',
        'analysisType': '없어진 종류',
      }),
    });

    await _pumpHome(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Gen2'), findsOneWidget);
    expect(find.text('층간 시험'), findsOneWidget);
    final segment = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    ); // 운전 방향 선택 버튼
    expect(segment.selected, {'상승'});
  });

  testWidgets('입력하면 측정을 시작하지 않아도 바로 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpHome(tester);
    await tester.enterText(_field(0), 'J-77');
    await tester.enterText(_field(6), '1500');
    await tester.pumpAndSettle();

    final saved = await PrefsStore.instance.loadLastSite(); // 저장된 현장 정보
    expect(saved['jobNo'], 'J-77');
    expect(saved['load'], '1500');
  });

  testWidgets('예시 힌트 없이 주소 · 층수 · 하중 힌트만 둔다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpHome(tester);

    expect(find.textContaining('예:'), findsNothing);
    expect(find.text('도로명 주소'), findsOneWidget);
  });

  testWidgets('새 입력칸이 정한 차례대로 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpHome(tester);

    for (final label in <String>[
      '우편번호',
      '하중',
      'kg',
      '분석 내용',
      '해석 종류',
      '추가 참고사항 (선택)',
      '메일 본문에 들어갑니다',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byType(TextField), findsNWidgets(8));
    final top = <String, double>{
      for (final label in <String>['주소', '하중', '분석 내용', '추가 참고사항 (선택)'])
        label: tester.getTopLeft(find.text(label)).dy,
    }; // 라벨마다 세로 자리
    expect(top['주소']!, lessThan(top['하중']!));
    expect(top['하중']!, lessThan(top['분석 내용']!));
    expect(top['분석 내용']!, lessThan(top['추가 참고사항 (선택)']!));
  });

  testWidgets('주소 · 우편번호 · 하중이 빠지면 시작하지 않고 안내한다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpHome(tester);
    await tester.enterText(_field(0), 'J-1');
    await tester.enterText(_field(1), '현장');
    await tester.enterText(_field(4), '1');
    await tester.enterText(_field(5), '8');
    await tester.tap(find.text('측정 시작'));
    await tester.pumpAndSettle();

    expect(find.text(_startScreenText), findsNothing);
    expect(find.text('우편번호를 입력하세요\n주소를 입력하세요'), findsOneWidget);
    expect(find.text('하중을 입력하세요'), findsOneWidget);
    expect(MeasurementSession.instance.currentSite, isNull);
  });

  testWidgets('우편번호가 5자리가 아니거나 하중이 0 이면 안내한다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpHome(tester);
    await _fillRequired(tester);
    await tester.enterText(_field(2), '1057');
    await tester.enterText(_field(6), '0');
    await tester.tap(find.text('측정 시작'));
    await tester.pumpAndSettle();

    expect(find.text(_startScreenText), findsNothing);
    expect(find.text('우편번호는 숫자 5자리로 입력하세요'), findsOneWidget);
    expect(find.text('하중은 0 보다 큰 숫자로 입력하세요'), findsOneWidget);
  });

  testWidgets('참고사항만 비어 있으면 측정을 시작한다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpHome(tester);
    await _fillRequired(tester);
    await tester.tap(find.text('측정 시작'));
    await tester.pumpAndSettle();

    expect(find.text(_startScreenText), findsOneWidget);
    final site = MeasurementSession.instance.currentSite!; // 실린 현장 정보
    expect(site.postalCode, '10575');
    expect(site.load, '2000');
    expect(site.analysisType, '층간 시험');
    expect(site.notes, '');
  });

  testWidgets('참고사항은 측정에 실리지만 기기에는 저장하지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpHome(tester);
    await _fillRequired(tester);
    await tester.enterText(_field(7), '도어 쪽 소음 큼');
    await tester.tap(find.text('측정 시작'));
    await tester.pumpAndSettle();

    expect(MeasurementSession.instance.currentSite!.notes, '도어 쪽 소음 큼');
    final saved = await PrefsStore.instance.loadLastSite(); // 저장된 현장 정보
    expect(saved.containsKey('notes'), isFalse);
    expect(saved['jobNo'], 'J-1');
  });
}
