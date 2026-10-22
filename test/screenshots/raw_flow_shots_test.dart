@Tags(['screenshot'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/login_store.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import 'package:vibration_checker/adapter/sensor_channel.dart';
import 'package:vibration_checker/adapter/update_checker.dart';
import 'package:vibration_checker/adapter/update_installer.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/capture/noise_offset.dart';
import 'package:vibration_checker/domain/capture/ride_weighting.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';
import 'package:vibration_checker/domain/report/measurement_assembler.dart';
import 'package:vibration_checker/domain/report/motion_zones.dart';
import 'package:vibration_checker/domain/session/login_session.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/model/measurement_result.dart';
import 'package:vibration_checker/model/worker.dart';
import 'package:vibration_checker/ui/features/history/history_screen.dart';
import 'package:vibration_checker/ui/features/home/home_screen.dart';
import 'package:vibration_checker/ui/features/login/login_screen.dart';
import 'package:vibration_checker/ui/features/measure/measuring_screen.dart';
import 'package:vibration_checker/ui/features/measure/placement_sheet.dart';
import 'package:vibration_checker/ui/features/measure/start_screen.dart';
import 'package:vibration_checker/ui/features/result/result_screen.dart';
import 'package:vibration_checker/ui/features/settings/settings_screen.dart';
import 'package:vibration_checker/ui/features/update/update_prompt.dart';

import '../support/fake_worker_bundle.dart';
import 'shot_harness.dart';

/// 작성: 2026-10-15 22:01:43 · nada
/// 클래스: _FakeSensors
/// 목적: 안드로이드 대신 쓰는 센서 통로. 센서 · 마이크 권한은 늘 있다고
///       답하고, `events` 를 흘려보낸다. 측정 화면의 현재 속도가 이 값으로
///       나온다(저장하는 측정 값은 로우 데이터 파일에서 바로 온다).
class _FakeSensors extends SensorChannelManager {
  /// 수집이 시작되면 흘려보낼 이벤트
  List<NativeEvent> events = const <NativeEvent>[];

  /// 작성: 2026-10-15 22:01:43 · nada
  /// 함수: checkSensorsAvailable
  /// 목적: 센서가 있다고 답한다.
  @override
  Future<bool> checkSensorsAvailable() async => true;

  /// 작성: 2026-10-15 22:01:43 · nada
  /// 함수: requestAudioPermission
  /// 목적: 마이크 권한을 받았다고 답한다.
  @override
  Future<bool> requestAudioPermission() async => true;

  /// 작성: 2026-10-15 22:01:43 · nada
  /// 함수: startCapture
  /// 목적: 아무것도 하지 않는다.
  @override
  Future<void> startCapture({
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 0.0,
  }) async {}

  /// 작성: 2026-10-15 22:01:43 · nada
  /// 함수: stopCapture
  /// 목적: 원본 기록 없이 멈춘다.
  @override
  Future<void> stopCapture() async => lastRecordPath = null;

  /// 작성: 2026-10-15 22:01:43 · nada
  /// 함수: setVolumeKeyCaptureEnabled
  /// 목적: 아무것도 하지 않는다.
  @override
  Future<void> setVolumeKeyCaptureEnabled(bool enabled) async {}

  /// 작성: 2026-10-15 22:01:43 · nada
  /// 함수: volumeKeyPresses
  /// 목적: 눌리지 않는 볼륨키.
  @override
  Stream<void> get volumeKeyPresses => const Stream<void>.empty();

  /// 작성: 2026-10-15 22:01:43 · nada
  /// 함수: nativeEventStream
  /// 목적: `events` 를 흘려보낸다.
  @override
  Stream<NativeEvent> get nativeEventStream =>
      Stream<NativeEvent>.fromIterable(events);
}

/// 작성: 2026-10-15 22:01:43 · nada
/// 클래스: _NoInstaller
/// 목적: 쓰이지 않는 업데이트 설치 통로(확인이 늘 실패해 창이 뜨지 않는다).
class _NoInstaller implements UpdateInstaller {
  /// 작성: 2026-10-15 22:01:43 · nada
  /// 함수: noSuchMethod
  /// 목적: 불리면 시험이 잘못된 것이라 바로 실패시킨다.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('업데이트 설치 통로가 불렸다: ${invocation.memberName}');
}

/// 작성: 2026-10-15 22:01:43 · nada
/// 함수: _offlinePrompt
/// 목적: 서버에 닿지 않는 업데이트 흐름. 홈 · 설정 화면이 창을 띄우지 않게
///       한다.
/// 반환: 확인이 늘 실패하는 흐름
UpdatePrompt _offlinePrompt() => UpdatePrompt(
  checker: UpdateChecker(
    client: MockClient((_) async => http.Response('', 404)),
    currentBuild: () async => 1,
  ),
  installer: _NoInstaller(),
);

/// 작성: 2026-10-15 22:01:43 · nada
/// 함수: _readGrid
/// 목적: 로우 데이터(raw.txt 꼴 EVIMP1, 256Hz 격자)를 격자 결과로 읽는다.
///       앱이 저장 때 `GridResampler` 에서 받는 것과 같은 꼴이다.
/// 인자: text — 파일 내용
/// 반환: 256Hz 격자
GridResampleResult _readGrid(String text) {
  final lines = const LineSplitter()
      .convert(text)
      .where((line) => line.trim().isNotEmpty)
      .toList(); // 파일 줄
  assert(lines[0].trim() == 'EVIMP1' && lines[1].trim() == '256'); // 머리 두 줄
  final rows = <GridSample>[
    for (final line in lines.sublist(2))
      () {
        final f = line.trim().split(RegExp(r'\s+')); // 열 값
        return GridSample(
          xMg: double.parse(f[0]),
          yMg: double.parse(f[1]),
          zMg: double.parse(f[2]),
          noiseDba: double.parse(f[3]),
        );
      }(),
  ]; // 256Hz 격자 행
  return GridResampleResult(
    samples: rows,
    t0Ns: 0,
    gridIntervalNs: 3906250,
    rawUsedCount: rows.length,
    gravityUsedCount: rows.length,
    droppedZeroCount: 0,
    droppedBackwardCount: 0,
    droppedLinearCount: 0,
    headTrimmedRows: 0,
    tailTrimmedRows: 0,
    rawMaxSpanNs: 0,
    gravityMaxSpanNs: 0,
    degenerateSpanCount: 0,
  );
}

/// 작성: 2026-10-15 22:32:44 · nada
/// 함수: _eventsFromRaw
/// 목적: 로우 데이터 앞 `seconds` 초를 안드로이드 이벤트처럼 바꾼다. 측정
///       화면의 현재 속도(`CaptureSession.liveSpeedMps`)를 그 자료로 내게
///       한다. 화면을 아래로 놓은 거치(중력 Z −1000 mg)로 두고, 격자의
///       Y · Z 가 `-(raw - gravity)` 이므로 raw Y 는 부호를 뒤집고 raw Z 는
///       −1000 − Z 로 준다.
/// 인자: grid — 로우 데이터 격자
///       seconds — 앞에서부터 쓸 길이 (초)
/// 반환: 중력 한 건 + 256Hz raw 이벤트
List<NativeEvent> _eventsFromRaw(GridResampleResult grid, double seconds) {
  const stepUs = 3906; // 256Hz 간격 (마이크로초)
  final count = (seconds * 256).round().clamp(0, grid.samples.length); // 쓸 행 수
  return <NativeEvent>[
    const NativeEvent(
      type: NativeEventType.gravity,
      tsUs: 0,
      xMg: 0,
      yMg: 0,
      zMg: -1000,
      dtUs: 0,
    ),
    for (var i = 0; i < count; i++)
      NativeEvent(
        type: NativeEventType.accel,
        tsUs: (i + 1) * stepUs,
        xMg: grid.samples[i].xMg,
        yMg: -grid.samples[i].yMg,
        zMg: -1000 - grid.samples[i].zMg,
        dtUs: stepUs,
      ),
  ];
}

/// 작성: 2026-10-15 22:01:43 · nada
/// 함수: _recordFromRaw
/// 목적: 측정 화면이 볼륨키로 끝났을 때 저장 절차가 하는 일을 로우 데이터로
///       한다. 홈에서 입력한 현장 정보(`MeasurementSession`)를 그대로 쓴다.
///       - 신호 처리 → 지표 조립 → 처리 방식 표시 → 결과 저장
///       - raw.txt 를 측정 폴더에 둔다(메일 첨부)
///       - 앱과 같은 길(`ensureReportPdf`)로 리포트 PDF 를 만들어 `pdfOut` 에
///         옮긴다
/// 인자: rawText — 로우 데이터 파일 내용
///       id — 측정 ID
///       measuredAt — 측정 시각
///       pdfOut — 리포트 사본 경로
/// 반환: 저장한 결과
Future<MeasurementResult> _recordFromRaw(
  String rawText,
  String id,
  DateTime measuredAt,
  String pdfOut,
) async {
  const conditioner = SignalConditioner(config: CaptureConfig()); // 신호 처리
  final assembled = MeasurementAssembler.assemble(
    grid: conditioner.condition(_readGrid(rawText)).grid,
    site: MeasurementSession.instance.currentSite!,
    id: id,
    measuredAt: measuredAt,
    worker: const Worker(employeeId: 'T00001', name: '홍길동'),
  ); // 조립 결과
  final result = assembled.result!.copyWith(
    signalConditioning:
        '${conditioner.methodLabel}+${RideWeighting.methodLabel}'
        '+${MeasurementAssembler.verticalLowpassMethodLabel}'
        '+${MeasurementAssembler.kinematicsMethodLabel}'
        '+${MeasurementAssembler.jerkMethodLabel}'
        '+${MeasurementAssembler.accelChartMethodLabel}'
        '+${MotionZones.methodLabel}'
        '+${noiseMethodLabel(48000)}',
  ); // 저장 절차와 같이 처리 방식을 실은 측정 결과
  final repo = MeasurementRepository.instance; // 저장소
  final dir = await repo.save(result); // 측정 폴더
  File(
    '${dir.path}/${MeasurementRepository.rawFileName}',
  ).writeAsStringSync(rawText);
  final pdf = await repo.ensureReportPdf(id); // 앱이 만든 리포트
  await pdf!.copy(pdfOut);
  return result;
}

/// 작성: 2026-10-15 22:01:43 · nada
/// 함수: _summary
/// 목적: 결과 지표를 사람이 읽을 한 덩어리 JSON 으로 만든다.
/// 인자: r — 측정 결과
/// 반환: 지표 지도
Map<String, Object?> _summary(MeasurementResult r) => <String, Object?>{
  'id': r.id,
  'xPtp': r.xPtp,
  'yPtp': r.yPtp,
  'zPtp': r.zPtp,
  'xA95': r.xA95,
  'yA95': r.yA95,
  'zA95': r.zA95,
  'noiseMax': r.noiseMax,
  'distance': r.distance,
  'maxSpeed': r.maxSpeed,
  'travelWindow': r.travelWindow?.toMap(),
  'travelWindowFailure': r.travelWindowFailure,
  'signalConditioning': r.signalConditioning,
  'seriesLength': r.zSeries.length,
};

/// 작성: 2026-10-15 22:01:43 · nada
/// 수정: 2026-10-18 11:20:05 · nada
/// 함수: main
/// 목적: 로우 데이터 두 개(`RAW_DIR` 의 오티스꺼.txt · 우리꺼.txt)로 사람이
///       앱을 쓰는 순서대로 화면을 찍는다. 로그인 → 홈 입력 → 측정 시작 →
///       측정 화면 → 결과 → 메일 → (두 번째) 결과 비교 → 설정 → 저장 결과
///       목록. 로그인은 시험용 명단(`FakeWorkerBundle`)으로 한다. 측정 화면을
///       볼륨키로 끝내는 대신 그 자리에서 로우 데이터로 저장 절차를 돈다.
///       리포트 PDF 는 `SHOT_DIR/pdf/` 에, 지표는 `SHOT_DIR/지표.json` 에
///       쓴다. `RAW_DIR` 이 없으면 건너뛴다. `RAW_RUNS`(예: "우리앱")를
///       주면 그 측정만 돌린다 — 하나만 돌리면 결과 비교 단계는 없다.
void main() {
  late Directory temp; // 이번 캡처가 쓸 임시 저장소
  final rawDir = Platform.environment['RAW_DIR']; // 로우 데이터 폴더
  final only = Platform.environment['RAW_RUNS']; // 돌릴 측정 이름, 없으면 모두

  setUpAll(loadShotFonts);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('otis_raw_flow');
    PathProviderPlatform.instance = TempPathProvider(temp.path);
    PackageInfo.setMockInitialValues(
      appName: 'OTIS V-Check',
      packageName: 'com.otis.vibration_checker',
      version: '0.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({
      'emails': <String>['engineer@example.com', 'office@example.com'],
    });
    LoginSession.instance.current = const Worker(
      employeeId: 'T00001',
      name: '홍길동',
      company: '(주)시험승강기',
      team: '설치1팀',
    );
  });

  testWidgets('로우 데이터 흐름', (tester) async {
    if (rawDir == null) {
      markTestSkipped('RAW_DIR 이 없다');
      return;
    }
    const size = Size(412, 915); // 화면 크기
    setShotSize(tester, size);
    final out = shotOutputDir(); // 쓸 폴더
    final pdfDir = Directory('${out.path}/pdf')..createSync(recursive: true);
    final sensors = _FakeSensors(); // 가짜 센서
    LoginSession.instance.current = null; // 로그인 화면부터 찍는다
    final loginStore = LoginStore(bundle: FakeWorkerBundle()); // 시험용 명단
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginScreen(store: loginStore),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => HomeScreen(updatePrompt: _offlinePrompt()),
        ),
        GoRoute(
          path: '/start',
          builder: (_, _) => StartScreen(sensorManager: sensors),
        ),
        GoRoute(
          path: '/measuring',
          builder: (_, _) => MeasuringScreen(sensorManager: sensors),
        ),
        GoRoute(
          path: '/result/:id',
          builder: (_, s) => ResultScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
        GoRoute(
          path: '/settings',
          builder: (_, _) => SettingsScreen(updatePrompt: _offlinePrompt()),
        ),
      ],
    ); // 앱과 같은 경로 (가짜 센서 · 업데이트만 바꿈)
    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: shotTheme(),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);

    var count = 0; // 찍은 장 수
    Future<void> shot(String name) =>
        capture(tester, '${(++count).toString().padLeft(2, '0')}_$name');
    Future<void> scrollDown() async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await settle(tester, rounds: 5);
    }

    // 로그인 — 비밀번호는 사번과 같다
    final loginFields = find.byType(TextField); // 사번 · 비밀번호 칸
    await tester.enterText(loginFields.at(0), 'T00001');
    await tester.enterText(loginFields.at(1), 'T00001');
    await settle(tester, rounds: 5);
    await shot('로그인');
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester, rounds: 20);

    final summaries = <String, Object?>{}; // 지표 모음
    final runs =
        <({String label, String file, String id, DateTime at})>[
              (
                label: '오티스',
                file: '오티스꺼.txt',
                id: '20261015-140000',
                at: DateTime.utc(2026, 10, 15, 5),
              ),
              (
                label: '우리앱',
                file: '우리꺼.txt',
                id: '20261015-140100',
                at: DateTime.utc(2026, 10, 15, 5, 1),
              ),
            ]
            .where((run) => only == null || only.split(',').contains(run.label))
            .toList(); // 측정 (`RAW_RUNS` 로 고른 것만)
    for (final (index, run) in runs.indexed) {
      final first = index == 0; // 첫 측정이면 빈 홈부터 찍는다
      final raw = await tester.runAsync(
        () => File('$rawDir/${run.file}').readAsString(),
      ); // 로우 데이터

      // 홈 — 현장 정보 입력
      final fields = find.byType(TextField); // 입력칸들
      if (first) {
        await shot('${run.label}_홈_빈칸');
        await tester.enterText(fields.at(0), '2025F 1234R01');
        await tester.enterText(fields.at(1), '시험 현장');
        await tester.enterText(fields.at(2), '10575');
        await tester.enterText(fields.at(3), '경기도 고양시 덕양구 오금동');
        await tester.enterText(fields.at(4), '1');
        await tester.enterText(fields.at(5), '8');
        await tester.enterText(fields.at(6), '2000');
      }
      // 메일 본문에 들어가는 참고사항. 현장에서 적을 법한 문구로 둔다
      await tester.enterText(fields.last, '카 바닥 중앙 거치, 문 닫힘 상태에서 측정');
      await settle(tester, rounds: 5);
      // 입력하며 내려간 화면을 맨 위로 올려, 아래 장과 겹치지 않게 찍는다
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await settle(tester, rounds: 5);
      await shot('${run.label}_홈_입력완료');
      if (first) {
        await scrollDown();
        await shot('${run.label}_홈_입력완료_아래');
      }

      // 측정 시작 — 거치 안내 · 대기 시간
      await tester.ensureVisible(find.text('측정 시작'));
      await tester.tap(find.text('측정 시작'));
      await settle(tester, rounds: 20);
      if (find.byType(PlacementSheet).evaluate().isNotEmpty) {
        if (first) await shot('${run.label}_거치안내');
        Navigator.of(tester.element(find.byType(PlacementSheet))).pop();
        await settle(tester, rounds: 5);
      }
      if (first) await shot('${run.label}_측정시작');

      // 측정 화면 — 카운트다운 → 수집 중. 현재 속도는 정속 구간까지
      // (앞 12초) 흘려보낸 값으로 나온다
      sensors.events = _eventsFromRaw(_readGrid(raw!), 12);
      await tester.ensureVisible(find.text('측정 시작'));
      await tester.tap(find.text('측정 시작'));
      await settle(tester, rounds: 20);
      if (first) await shot('${run.label}_측정_카운트다운');
      for (var second = 0; second < 8; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await settle(tester, rounds: 5);
      await shot('${run.label}_측정_수집중');

      // 볼륨키로 끝낸 자리 — 로우 데이터로 저장하고 결과 화면으로
      final result = await tester.runAsync(
        () => _recordFromRaw(
          raw,
          run.id,
          run.at,
          '${pdfDir.path}/${run.label}.pdf',
        ),
      ); // 저장한 결과
      summaries[run.label] = _summary(result!);
      router.pushReplacement('/result/${run.id}');
      await settle(tester, rounds: 60);
      await shot('${run.label}_결과');
      await scrollDown();
      await shot('${run.label}_결과_아래');

      if (!first) {
        // 결과 비교 — 첫 측정과 나란히
        await tester.ensureVisible(find.text('결과 비교'));
        await tester.tap(find.text('결과 비교'));
        await settle(tester, rounds: 200);
        final pick = find.textContaining('2026-10-15 14:00').last; // 고를 줄
        await tester.ensureVisible(pick);
        await tester.tap(pick);
        await settle(tester, rounds: 10);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await settle(tester, rounds: 5);
        await shot('${run.label}_결과비교');
        await scrollDown();
        await shot('${run.label}_결과비교_아래');
      }

      // 메일 발송 시트
      await tester.ensureVisible(find.text('메일 발송'));
      await tester.tap(find.text('메일 발송'));
      await settle(tester, rounds: 100);
      await tester.tap(find.text('engineer@example.com')); // 받는 사람 고르기
      await settle(tester, rounds: 5);
      await shot('${run.label}_메일시트');
      await tester.tapAt(const Offset(200, 40)); // 시트 바깥을 눌러 닫는다
      await settle(tester, rounds: 10);

      router.go('/home');
      await settle(tester, rounds: 20);
    }

    // 설정 — 로그인 작업자 · 수신 이메일 · 앱 버전
    router.push('/settings');
    await settle(tester, rounds: 20);
    await shot('설정');
    router.pop();
    await settle(tester, rounds: 10);

    // 저장 결과 목록
    router.push('/history');
    await settle(tester, rounds: 200);
    await shot('저장결과목록');

    File(
      '${out.path}/지표.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summaries));
    await tester.pumpWidget(const SizedBox());
    await settle(tester, rounds: 2);
  });

  tearDown(() {
    // 캡처 중 연 파일이 아직 잡혀 있을 수 있어 지우지 못해도 넘어간다
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });
}
