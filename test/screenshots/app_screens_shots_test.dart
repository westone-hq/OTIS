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
import 'package:vibration_checker/adapter/sensor/sensor_channel.dart';
import 'package:vibration_checker/adapter/storage/measurement_repository.dart';
import 'package:vibration_checker/adapter/update/update_checker.dart';
import 'package:vibration_checker/adapter/update/update_installer.dart';
import 'package:vibration_checker/domain/analysis/travel_window.dart';
import 'package:vibration_checker/domain/auth/login_session.dart';
import 'package:vibration_checker/domain/auth/worker.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/session/measurement_session.dart';
import 'package:vibration_checker/domain/session/site_info.dart';
import 'package:vibration_checker/domain/update/update_decision.dart';
import 'package:vibration_checker/domain/update/update_info.dart';
import 'package:vibration_checker/ui/core/widgets/app_layout.dart';
import 'package:vibration_checker/ui/features/history/history_screen.dart';
import 'package:vibration_checker/ui/features/home/home_screen.dart';
import 'package:vibration_checker/ui/features/login/login_screen.dart';
import 'package:vibration_checker/ui/features/measure/measuring_screen.dart';
import 'package:vibration_checker/ui/features/measure/mic_permission.dart';
import 'package:vibration_checker/ui/features/measure/placement_sheet.dart';
import 'package:vibration_checker/ui/features/measure/start_screen.dart';
import 'package:vibration_checker/ui/features/result/result_screen.dart';
import 'package:vibration_checker/ui/features/result/send_email_sheet.dart';
import 'package:vibration_checker/ui/features/settings/settings_screen.dart';
import 'package:vibration_checker/ui/features/update/update_prompt.dart';

import 'shot_harness.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: _FakeSensors
/// 목적: 안드로이드 대신 쓰는 센서 통로. 센서는 늘 있다고 답하고, 마이크
///       권한은 `micGranted` 로, 볼륨키는 `pressVolumeKey()` 로 흉내 낸다.
class _FakeSensors extends SensorChannelManager {
  /// 마이크 권한 요청에 돌려줄 답
  bool micGranted = true;

  /// 볼륨키 눌림을 흘려보내는 통로
  final StreamController<void> _volume = StreamController<void>.broadcast();

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: pressVolumeKey
  /// 목적: 볼륨키를 한 번 누른 것처럼 알린다.
  void pressVolumeKey() => _volume.add(null);

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: checkSensorsAvailable
  /// 목적: 센서가 있다고 답한다.
  @override
  Future<bool> checkSensorsAvailable() async => true;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: requestAudioPermission
  /// 목적: `micGranted` 로 답한다.
  @override
  Future<bool> requestAudioPermission() async => micGranted;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: startCapture
  /// 목적: 아무것도 하지 않는다.
  @override
  Future<void> startCapture({
    double calibrationOffsetDba = 0.0,
    double micDbfsToDbaOffset = 0.0,
  }) async {}

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: stopCapture
  /// 목적: 원본 기록 없이 멈춘다.
  @override
  Future<void> stopCapture() async => lastRecordPath = null;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: setVolumeKeyCaptureEnabled
  /// 목적: 아무것도 하지 않는다.
  @override
  Future<void> setVolumeKeyCaptureEnabled(bool enabled) async {}

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: volumeKeyPresses
  /// 목적: `pressVolumeKey()` 가 흘려보내는 눌림.
  @override
  Stream<void> get volumeKeyPresses => _volume.stream;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: nativeEventStream
  /// 목적: 값이 오지 않는 빈 흐름. 저장 때 "표본 없음" 실패가 난다.
  @override
  Stream<NativeEvent> get nativeEventStream =>
      const Stream<NativeEvent>.empty();
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 클래스: _FakeInstaller
/// 목적: 안드로이드 대신 쓰는 업데이트 통로. 받기는 끝나지 않게 붙잡아 진행
///       막대가 보이게 한다.
class _FakeInstaller implements UpdateInstaller {
  /// 설치가 허용돼 있는지
  bool allowed = true;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: canInstall
  /// 목적: `allowed` 로 답한다.
  @override
  Future<bool> canInstall() async => allowed;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: openInstallSettings
  /// 목적: 설정 화면에서 돌아오지 않은 채로 둔다.
  @override
  Future<bool> openInstallSettings() => Completer<bool>().future;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: progress
  /// 목적: 42% 진행률 한 건을 흘려보낸다.
  @override
  Stream<DownloadProgress> progress() =>
      Stream<DownloadProgress>.value(const DownloadProgress(42, 100));

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: download
  /// 목적: 끝나지 않는 내려받기.
  @override
  Future<String> download(UpdateInfo info) => Completer<String>().future;

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: cancelDownload
  /// 목적: 아무것도 하지 않는다.
  @override
  Future<void> cancelDownload() async {}

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: install
  /// 목적: 설치됐다고 답한다.
  @override
  Future<(InstallOutcome, String?)> install(String path) async =>
      (InstallOutcome.success, null);
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 변수: _info
/// 목적: 업데이트 창에 띄울 버전 정보.
final UpdateInfo _info = UpdateInfo(
  latest: 2,
  latestName: '0.0.1',
  minimum: 1,
  apkUrl: Uri.parse('https://github.com/o/r/releases/download/v0.0.1/a.apk'),
  sha256: 'ab' * 32,
  notes: '리포트 진동 지표를 원본 리포트와 같은 방식으로 냅니다',
);

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _offlinePrompt
/// 목적: 서버에 닿지 않는 업데이트 흐름. 홈 · 설정 화면이 캡처 중에 창을
///       띄우지 않게 한다.
/// 반환: 확인이 늘 실패하는 흐름
UpdatePrompt _offlinePrompt() => UpdatePrompt(
  checker: UpdateChecker(
    client: MockClient((_) async => http.Response('', 404)),
    currentBuild: () async => 1,
  ),
  installer: _FakeInstaller(),
);

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _series
/// 목적: 결과 파일에 실을 짧은 시계열.
/// 반환: 100표본 사인
List<double> _series() =>
    List<double>.generate(100, (i) => (i % 10 - 5).toDouble());

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _mock
/// 목적: 목업 측정 결과 하나를 만든다.
/// 인자: id — 측정 ID
///       when — 측정 시각
///       jobNo, siteName, address — 현장 정보
///       x, y, z — 축별 최대 P2P (mg). null 이면 미측정
///       noise — 소음 최대 (dBA)
///       loadUnit — 하중 단위
///       legacy — true 면 신호 처리 · 새 항목 전의 예전 결과
///       failed — true 면 운행 구간을 못 정한 결과
/// 반환: 측정 결과
MeasurementResult _mock(
  String id,
  DateTime when, {
  String jobNo = '2025F 1234R01',
  String siteName = '시험 현장',
  String address = '경기도 고양시 덕양구 오금동',
  double? x = 6.6,
  double? y = 11.1,
  double? z = 5.5,
  double? noise = 48.7,
  String loadUnit = 'kg',
  bool legacy = false,
  bool failed = false,
}) {
  return MeasurementResult(
    id: id,
    jobNo: jobNo,
    siteName: siteName,
    address: address,
    bottomFloor: 1,
    topFloor: 8,
    direction: SiteInfo.directionUp,
    model: 'Gen2',
    load: legacy ? null : 2000,
    loadUnit: legacy ? null : loadUnit,
    analysisType: legacy ? null : '층간 시험',
    postalCode: legacy ? null : '10575',
    engineerName: legacy ? null : '홍길동',
    dateTime: when,
    xPtp: failed ? null : x,
    yPtp: failed ? null : y,
    zPtp: failed ? null : z,
    xA95: failed || x == null ? null : x * 0.7,
    yA95: failed || y == null ? null : y * 0.45,
    zA95: failed || z == null ? null : z * 0.67,
    noiseMax: failed ? null : noise,
    distance: 57.1,
    maxSpeed: 1.74,
    xSeries: _series(),
    ySeries: _series(),
    zSeries: _series(),
    noiseSeries: List<double>.filled(100, 45.0),
    positionSeries: _series(),
    speedSeries: _series(),
    accelSeries: _series(),
    jerkSeries: _series(),
    sampleRate: legacy ? 256 : 100,
    signalConditioning: legacy
        ? null
        : 'baseline+lp40bw4zp+rs100+iso18738(wd,zhp1wk)',
    travelWindow: legacy || failed
        ? null
        : const TravelWindow(
            startIndex: 10,
            endIndex: 90,
            startSec: 0.1,
            endSec: 0.9,
            startM: 0.5,
            endM: 56.6,
          ),
    travelWindowFailure: failed ? '운행 거리가 1.0m 이하다: 0.012m' : null,
  );
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _seed
/// 목적: 목업 결과들을 저장소에 넣는다. 정상 · 황색 · 적색 · 미측정 · 아주
///       긴 현장명 · lb 예전 결과 · 처리 전 예전 결과, 그리고 측정 일시가
///       깨진 결과 하나.
/// 인자: root — 저장소 임시 폴더
Future<void> _seed(String root) async {
  final repo = MeasurementRepository.instance; // 저장소
  await repo.save(_mock('20261015-090000', DateTime(2026, 10, 15, 9)));
  await repo.save(
    _mock('20261015-091000', DateTime(2026, 10, 15, 9, 10), z: 21.0, x: 18.0),
  );
  await repo.save(
    _mock(
      '20261015-092000',
      DateTime(2026, 10, 15, 9, 20),
      z: 31.0,
      x: 26.0,
      noise: 76.0,
    ),
  );
  await repo.save(
    _mock('20261015-093000', DateTime(2026, 10, 15, 9, 30), failed: true),
  );
  await repo.save(
    _mock(
      '20261015-094000',
      DateTime(2026, 10, 15, 9, 40),
      jobNo: '2025F 9999R99-LONG',
      siteName: '서울특별시 강남구 테헤란로 아주아주 긴 현장 이름 복합 업무 시설 신축공사 A동',
      address: '서울특별시 강남구 테헤란로 123 아주 긴 주소 빌딩 지하 3층 기계실 옆 승강기',
    ),
  );
  await repo.save(
    _mock('20261013-150000', DateTime(2026, 10, 13, 15), loadUnit: 'lb'),
  );
  await repo.save(
    _mock('20261001-100000', DateTime(2026, 10, 1, 10), legacy: true),
  );
  await repo.save(_mock('20260930-100000', DateTime(2026, 9, 30, 10)));
  final broken = File(
    '$root/captures/20260930-100000/${MeasurementRepository.resultFileName}',
  ); // 일시를 망가뜨릴 정본
  final map = jsonDecode(broken.readAsStringSync()) as Map<String, dynamic>;
  map.remove('dateTime');
  broken.writeAsStringSync(jsonEncode(map));
  File(
    '$root/captures/20260930-100000/${MeasurementRepository.summaryFileName}',
  ).deleteSync();
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _app
/// 목적: 캡처 경계로 감싼 앱을 만든다.
/// 인자: home — 첫 화면
/// 반환: 앱
Widget _app(Widget home) => RepaintBoundary(
  key: shotKey,
  child: MaterialApp(theme: shotTheme(), home: home),
);

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _routerApp
/// 목적: 화면 이동이 필요한 화면(시작 · 측정 · 결과)을 경로로 띄운다.
/// 인자: initial — 처음 경로
///       sensors — 측정 화면에 끼울 가짜 센서
/// 반환: 앱
Widget _routerApp(String initial, {_FakeSensors? sensors}) {
  final router = GoRouter(
    initialLocation: '/stub',
    routes: [
      GoRoute(path: '/stub', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/start', builder: (_, _) => const StartScreen()),
      GoRoute(
        path: '/measuring',
        builder: (_, _) => MeasuringScreen(sensorManager: sensors),
      ),
      GoRoute(
        path: '/result/:id',
        builder: (_, s) => ResultScreen(id: s.pathParameters['id']!),
      ),
    ],
  ); // 시험용 경로
  scheduleMicrotask(() => router.push(initial));
  return RepaintBoundary(
    key: shotKey,
    child: MaterialApp.router(theme: shotTheme(), routerConfig: router),
  );
}

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _contextOf
/// 목적: 화면 안 위치 정보를 얻는다(대화상자 · 시트를 띄울 자리).
/// 인자: tester — 위젯 시험 도구
/// 반환: 맨 위 `Scaffold` 의 위치 정보
BuildContext _contextOf(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: main
/// 목적: 화면 · 상태별 목업 캡처를 두 화면 크기로 남긴다. 일반 시험에서
///       빠진다(`dart_test.yaml` 의 `screenshot` 태그). 돌리는 법:
///       `flutter test --tags screenshot --run-skipped test/screenshots`
///       (`SHOT_DIR` 환경 변수로 쓸 폴더를 정한다)
void main() {
  late Directory temp; // 이번 캡처가 쓸 임시 저장소

  setUpAll(loadShotFonts);

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('otis_shots');
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
    MeasurementSession.instance.currentSite = const SiteInfo(
      jobNo: '2025F 1234R01',
      siteName: '시험 현장',
      address: '경기도 고양시 덕양구 오금동',
      postalCode: '10575',
      bottomFloor: '1',
      topFloor: '8',
      direction: SiteInfo.directionUp,
      model: 'Gen2',
      load: '2000',
    );
  });

  tearDown(() {
    // 캡처 중 연 파일이 아직 잡혀 있을 수 있어 지우지 못해도 넘어간다
    // (운영체제 임시 폴더라 나중에 정리된다)
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  for (final size in shotSizes) {
    group('${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('홈', (tester) async {
        setShotSize(tester, size);
        await tester.pumpWidget(
          _app(HomeScreen(updatePrompt: _offlinePrompt())),
        );
        await settle(tester);
        await capture(tester, shotName('01_홈_빈칸', size));

        final fields = find.byType(TextField); // 입력칸들
        await tester.enterText(fields.at(0), '2025F 1234R01');
        await tester.enterText(fields.at(1), '시험 현장');
        await tester.enterText(fields.at(2), '10575');
        await tester.enterText(fields.at(3), '경기도 고양시 덕양구 오금동');
        await tester.enterText(fields.at(4), '1');
        await tester.enterText(fields.at(5), '8');
        await tester.enterText(fields.at(6), '2000');
        await settle(tester, rounds: 5);
        await capture(tester, shotName('02_홈_입력완료', size));

        await tester.enterText(fields.at(2), '123');
        await tester.enterText(fields.at(6), '');
        await tester.ensureVisible(find.text('측정 시작'));
        await tester.tap(find.text('측정 시작'));
        await settle(tester, rounds: 5);
        await capture(tester, shotName('03_홈_검증오류', size));
      });

      testWidgets('시작 · 거치 안내', (tester) async {
        setShotSize(tester, size);
        await tester.pumpWidget(_app(const Scaffold()));
        showAppSheet(
          _contextOf(tester),
          builder: (_) => const PlacementSheet(),
        );
        await settle(tester, rounds: 5);
        await capture(tester, shotName('05_거치안내', size));

        await tester.pumpWidget(_routerApp('/start'));
        await settle(tester, rounds: 10);
        if (find.byType(PlacementSheet).evaluate().isNotEmpty) {
          Navigator.of(tester.element(find.byType(PlacementSheet))).pop();
          await settle(tester, rounds: 5);
        }
        await capture(tester, shotName('04_시작', size));
      });

      testWidgets('마이크 권한 안내', (tester) async {
        setShotSize(tester, size);
        await tester.pumpWidget(_app(const Scaffold()));
        final sensors = _FakeSensors()..micGranted = false; // 권한 거절
        unawaited(ensureMicPermission(_contextOf(tester), sensors));
        await settle(tester, rounds: 5);
        await capture(tester, shotName('06_마이크권한', size));
      });

      testWidgets('측정 화면', (tester) async {
        setShotSize(tester, size);
        MeasurementSession.instance.delaySec = 5;
        await tester.pumpWidget(
          _routerApp('/measuring', sensors: _FakeSensors()),
        );
        await settle(tester, rounds: 5);
        await capture(tester, shotName('07_측정_카운트다운', size));
        await tester.pumpWidget(const SizedBox());
        await settle(tester, rounds: 2);

        MeasurementSession.instance.delaySec = 0;
        final sensors = _FakeSensors(); // 볼륨키를 누를 센서
        await tester.pumpWidget(_routerApp('/measuring', sensors: sensors));
        await settle(tester, rounds: 5);
        await tester.pump(const Duration(seconds: 3));
        await capture(tester, shotName('08_측정_수집중', size));

        sensors.pressVolumeKey();
        await settle(tester, rounds: 40);
        await capture(tester, shotName('09_측정_실패', size));
        await tester.pumpWidget(const SizedBox());
        await settle(tester, rounds: 2);
      });

      testWidgets('결과 · 목록 · 메일', (tester) async {
        setShotSize(tester, size);
        await tester.runAsync(() => _seed(temp.path));

        for (final entry in <String, String>{
          '10_결과_정상': '20261015-090000',
          '11_결과_초과': '20261015-092000',
          '12_결과_미측정': '20261015-093000',
        }.entries) {
          await tester.pumpWidget(_routerApp('/result/${entry.value}'));
          await settle(tester);
          await capture(tester, shotName(entry.key, size));
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          _app(const ResultScreen(id: '20261015-092000')),
        );
        await settle(tester);
        await tester.tap(find.text('결과 비교'));
        // 저장 결과 여러 개를 읽는다. 시험 시계에서는 파일 읽기 한 번이 한
        // 차례씩 나아가 넉넉히 기다린다
        await settle(tester, rounds: 200);
        final pick = find.textContaining('2026-10-15 09:00').last; // 고를 줄
        await tester.ensureVisible(pick);
        await tester.tap(pick);
        await settle(tester, rounds: 10);
        await capture(tester, shotName('13_결과_비교', size));

        await tester.pumpWidget(_app(const HistoryScreen()));
        await settle(tester, rounds: 200);
        await capture(tester, shotName('14_목록_위', size));
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await settle(tester, rounds: 5);
        await capture(tester, shotName('15_목록_아래_읽을수없는결과', size));

        await tester.pumpWidget(_app(const Scaffold()));
        unawaited(
          showSendEmailSheet(_contextOf(tester), jobId: '20261015-090000'),
        );
        await settle(tester, rounds: 100);
        await capture(tester, shotName('17_메일시트', size));
      });

      testWidgets('로그인', (tester) async {
        setShotSize(tester, size);
        await tester.pumpWidget(_app(const LoginScreen()));
        await settle(tester);
        await capture(tester, shotName('00_로그인', size));
      });

      testWidgets('설정', (tester) async {
        setShotSize(tester, size);
        await tester.pumpWidget(
          _app(SettingsScreen(updatePrompt: _offlinePrompt())),
        );
        await settle(tester);
        await capture(tester, shotName('16_설정', size));
      });

      testWidgets('업데이트 창', (tester) async {
        setShotSize(tester, size);
        for (final entry in <String, UpdateDecision>{
          '18_업데이트_선택': UpdateDecision.optional,
          '19_업데이트_필수': UpdateDecision.required,
        }.entries) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(_app(const Scaffold()));
          final prompt = UpdatePrompt(
            checker: UpdateChecker(
              client: MockClient((_) async => http.Response('', 404)),
            ),
            installer: _FakeInstaller(),
          ); // 업데이트 흐름
          unawaited(
            prompt.offer(
              _contextOf(tester),
              UpdateCheck(entry.value, info: _info),
            ),
          );
          await settle(tester, rounds: 5);
          await capture(tester, shotName(entry.key, size));
          if (entry.value == UpdateDecision.optional) {
            await tester.tap(find.text('업데이트'));
            await settle(tester, rounds: 5);
            await capture(tester, shotName('20_업데이트_내려받는중', size));
          }
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_app(const Scaffold()));
        final blocked = UpdatePrompt(
          checker: UpdateChecker(
            client: MockClient((_) async => http.Response('', 404)),
          ),
          installer: _FakeInstaller()..allowed = false,
        ); // 설치 허용이 꺼진 흐름
        unawaited(
          blocked.offer(
            _contextOf(tester),
            UpdateCheck(UpdateDecision.optional, info: _info),
          ),
        );
        await settle(tester, rounds: 5);
        await tester.tap(find.text('업데이트'));
        await settle(tester, rounds: 5);
        await capture(tester, shotName('21_업데이트_설치허용안내', size));
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
