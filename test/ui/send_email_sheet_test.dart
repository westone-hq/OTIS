import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender_platform_interface/flutter_email_sender_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/model/measurement_result.dart';
import 'package:vibration_checker/ui/features/shared/send_email_sheet.dart';

/// 작성: 2026-10-10 13:54:43 · nada
/// 변수: _jobId
/// 목적: 시험에서 저장하고 메일로 보낼 측정의 식별자.
const String _jobId = '20260114-110359';

/// 작성: 2026-10-10 13:54:43 · nada
/// 클래스: _TempPathProvider
/// 목적: 저장소의 기준 폴더와 메일 첨부 사본 폴더를 시험마다 새로 만든 임시
///       폴더로 바꿔 끼운다.
class _TempPathProvider extends PathProviderPlatform {
  /// 임시 폴더 경로
  final String root;

  /// 작성: 2026-10-10 13:54:43 · nada
  /// 함수: _TempPathProvider
  /// 목적: 돌려줄 임시 폴더 경로를 받는다.
  /// 인자: root — 임시 폴더 경로
  _TempPathProvider(this.root);

  /// 작성: 2026-10-10 13:54:43 · nada
  /// 함수: getExternalStoragePath
  /// 목적: 외부 저장소 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getExternalStoragePath() async => root;

  /// 작성: 2026-10-10 13:54:43 · nada
  /// 함수: getApplicationDocumentsPath
  /// 목적: 앱 문서 폴더 자리 대신 임시 폴더를 돌려준다.
  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  /// 작성: 2026-10-10 13:54:43 · nada
  /// 함수: getTemporaryPath
  /// 목적: 메일 첨부 사본을 놓는 앱 임시 폴더 자리 대신 임시 폴더 안
  ///       `tmp` 를 돌려준다.
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

/// 작성: 2026-10-10 13:54:43 · nada
/// 클래스: _RecordingEmailSender
/// 목적: 기기 메일 앱 작성창 자리에 끼워, 넘어온 메일을 받아 두기만 한다.
///       시험이 첨부 · 본문을 눈으로 대신 확인한다.
class _RecordingEmailSender extends FlutterEmailSenderPlatform {
  /// 받은 메일. 아직 보내기 전이면 null
  Email? sent;

  /// 작성: 2026-10-10 13:54:43 · nada
  /// 함수: send
  /// 목적: 넘어온 메일을 받아 둔다.
  /// 인자: email — 시트가 조립한 메일
  @override
  Future<void> send(Email email) async => sent = email;

  /// 작성: 2026-10-10 13:54:43 · nada
  /// 함수: getCapabilities
  /// 목적: 메일 앱이 할 수 있는 것을 알린다. 시트는 묻지 않는다.
  @override
  Future<EmailCapabilities> getCapabilities() async =>
      const EmailCapabilities.none();
}

/// 작성: 2026-10-10 13:54:43 · nada
/// 수정: 2026-10-11 19:17:58 · nada
/// 함수: _result
/// 목적: 메일로 보낼 측정 결과를 꾸민다.
/// 인자: notes — 추가 참고사항. 없으면 null
/// 반환: 측정 결과
MeasurementResult _result({String? notes}) {
  return MeasurementResult(
    id: _jobId,
    jobNo: 'J-1',
    siteName: '현장',
    bottomFloor: 1,
    topFloor: 8,
    direction: '상승',
    notes: notes,
    dateTime: DateTime(2026, 1, 14, 11, 3, 59),
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

/// 작성: 2026-10-10 13:54:43 · nada
/// 함수: _saveJob
/// 목적: 측정 한 건을 저장소에 저장하고, 측정 폴더에 리포트 · 원본 파일을
///       놓는다. 리포트를 미리 놓아 시험이 실제 PDF 를 그리지 않게 한다.
///       안드로이드 원본(`native_raw.txt`)은 늘 놓는다 — 붙지 않는지 봐야
///       한다.
/// 인자: withRaw — `raw.txt` 를 놓을지
///       notes — 결과에 실을 추가 참고사항. 없으면 null
Future<void> _saveJob({required bool withRaw, String? notes}) async {
  final repo = MeasurementRepository.instance; // 시험할 저장소
  final dir = await repo.save(_result(notes: notes)); // 이 측정의 폴더
  await File(
    '${dir.path}/${MeasurementRepository.reportFileName}',
  ).writeAsString('%PDF-1.4');
  await File(
    '${dir.path}/${MeasurementRepository.nativeRawFileName}',
  ).writeAsString('native');
  if (withRaw) {
    await File(
      '${dir.path}/${MeasurementRepository.rawFileName}',
    ).writeAsString('EVIMP1\n256\n');
  }
}

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
            onPressed: () => showSendEmailSheet(context, jobId: _jobId),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

/// 작성: 2026-10-10 13:54:43 · nada
/// 함수: _sendAndCapture
/// 목적: "보내기" 를 누르고, 파일 읽기 · 복사처럼 시험 시계 밖에서 도는
///       작업이 끝날 틈을 준 뒤 메일 앱 자리에 넘어온 메일을 돌려준다.
/// 인자: tester — 위젯 시험 도구
///       sender — 메일 앱 자리에 끼운 가짜
/// 반환: 넘어온 메일
Future<Email> _sendAndCapture(
  WidgetTester tester,
  _RecordingEmailSender sender,
) async {
  await tester.tap(find.widgetWithText(ElevatedButton, '보내기'));
  for (var round = 0; round < 40 && sender.sent == null; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(sender.sent, isNotNull, reason: '메일 앱 작성창을 부르지 않았다');
  return sender.sent!;
}

/// 작성: 2026-10-10 13:54:43 · nada
/// 함수: _names
/// 목적: 첨부 경로에서 파일 이름만 뽑는다.
/// 인자: email — 넘어온 메일
/// 반환: 첨부 파일 이름 목록
List<String> _names(Email email) => <String>[
  for (final path in email.attachmentPaths ?? const <String>[])
    path.split(RegExp(r'[\\/]')).last,
];

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
/// 수정: 2026-10-10 13:54:43 · nada
/// 함수: main
/// 목적: 메일 시트를 시험한다.
///       - 받는 사람: 지난번 보낸 주소만 미리 고르는지, 여러 개를 고를 수
///         있는지
///       - 보낼 항목: PDF 리포트와 로우 데이터 두 줄이고 기본으로 체크돼
///         있는지, 둘 다 해제하면 보내기를 막는지
///       - 첨부: 고른 항목만 제번 · 측정 ID 이름으로 붙는지, `raw.txt` 가
///         없으면 본문에 누락을 밝히는지, 안드로이드 원본은 어떤 경우에도
///         붙지 않는지
///       - 보내기 버튼이 아래쪽 시스템 영역에 가리지 않는지
void main() {
  late Directory temp; // 이번 시험이 쓸 임시 폴더
  late _RecordingEmailSender sender; // 메일 앱 자리에 끼운 가짜

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('otis_send_email');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
    sender = _RecordingEmailSender();
    FlutterEmailSenderPlatform.instance = sender;
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

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

  testWidgets('보낼 항목은 PDF 리포트와 로우 데이터이고 둘 다 체크돼 있다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });

    await _openSheet(tester);

    expect(_checked(tester, 'PDF 리포트'), isTrue);
    expect(_checked(tester, '로우 데이터 (raw.txt)'), isTrue);
    expect(find.textContaining('native'), findsNothing);
  });

  testWidgets('PDF 와 로우 데이터를 제번 · 측정 ID 이름으로 함께 붙인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });
    await tester.runAsync(() => _saveJob(withRaw: true));

    await _openSheet(tester);
    final email = await _sendAndCapture(tester, sender);

    expect(_names(email), <String>[
      'TUNE_J-1_$_jobId.pdf',
      'RAW_J-1_$_jobId.txt',
    ]);
    expect(
      email.body,
      contains('- RAW_J-1_$_jobId.txt: 256Hz 원시값(EVIMP1, 필터 · 기준선 보정 없음)'),
    );
    expect(email.body, contains('※ 첨부 2개'));
    expect(email.body, isNot(contains('누락')));
  });

  testWidgets('참고사항이 있으면 첨부 목록 앞에 머리줄과 함께 넣는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });
    await tester.runAsync(
      () => _saveJob(withRaw: true, notes: '도어 쪽 소음 큼\n다음 점검 때 재측정'),
    );

    await _openSheet(tester);
    final email = await _sendAndCapture(tester, sender);

    expect(
      email.body,
      startsWith(
        'OTIS 승강기 진동 측정 리포트입니다.\n\n[참고사항]\n'
        '도어 쪽 소음 큼\n다음 점검 때 재측정\n\n- TUNE_',
      ),
    );
  });

  testWidgets('참고사항이 없으면 그 덩어리를 통째로 뺀다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });
    await tester.runAsync(() => _saveJob(withRaw: true));

    await _openSheet(tester);
    final email = await _sendAndCapture(tester, sender);

    expect(email.body, isNot(contains('[참고사항]')));
    expect(email.body, startsWith('OTIS 승강기 진동 측정 리포트입니다.\n- TUNE_'));
  });

  testWidgets('로우 데이터만 고르면 그것 하나만 붙인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });
    await tester.runAsync(() => _saveJob(withRaw: true));

    await _openSheet(tester);
    await tester.tap(find.text('PDF 리포트'));
    await tester.pumpAndSettle();
    final email = await _sendAndCapture(tester, sender);

    expect(_names(email), <String>['RAW_J-1_$_jobId.txt']);
    expect(email.body, contains('※ 첨부 1개'));
  });

  testWidgets('raw.txt 가 없는 측정은 본문에 누락을 밝힌다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });
    await tester.runAsync(() => _saveJob(withRaw: false));

    await _openSheet(tester);
    final email = await _sendAndCapture(tester, sender);

    expect(_names(email), <String>['TUNE_J-1_$_jobId.pdf']);
    expect(email.body, contains('누락: ${MeasurementRepository.rawFileName}'));
  });

  testWidgets('안드로이드 원본은 어떤 조합에서도 붙지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });
    await tester.runAsync(() => _saveJob(withRaw: true));

    for (final uncheck in <String?>[null, 'PDF 리포트', '로우 데이터 (raw.txt)']) {
      sender.sent = null;
      await _openSheet(tester);
      if (uncheck != null) {
        await tester.tap(find.text(uncheck));
        await tester.pumpAndSettle();
      }
      final email = await _sendAndCapture(tester, sender);

      expect(
        email.attachmentPaths,
        everyElement(isNot(contains(MeasurementRepository.nativeRawFileName))),
        reason: '$uncheck 해제',
      );
      expect(email.body, isNot(contains('native')), reason: '$uncheck 해제');
    }
  });

  testWidgets('보낼 항목을 모두 해제하면 경고하고 보내기를 막는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'emails': <String>['a@otis.com'],
    });

    await _openSheet(tester);
    await tester.tap(find.text('PDF 리포트'));
    await tester.tap(find.text('로우 데이터 (raw.txt)'));
    await tester.pumpAndSettle();

    expect(find.text('보낼 항목을 선택하세요'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '보내기'),
    ); // 보내기 버튼
    expect(button.onPressed, isNull);
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
