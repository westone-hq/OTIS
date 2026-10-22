import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/update/update_checker.dart';
import 'package:vibration_checker/adapter/update/update_installer.dart';
import 'package:vibration_checker/domain/update/update_decision.dart';
import 'package:vibration_checker/domain/update/update_info.dart';
import 'package:vibration_checker/ui/features/settings/settings_screen.dart';
import 'package:vibration_checker/ui/features/update/update_prompt.dart';

/// 작성: 2026-10-13 14:27:24 · nada
/// 변수: _info
/// 목적: 안내할 버전 정보 (minimum 12, latest 13).
final UpdateInfo _info = UpdateInfo(
  latest: 13,
  latestName: '0.1.3',
  minimum: 12,
  apkUrl: Uri.parse('https://github.com/o/r/releases/download/v/v.apk'),
  sha256: 'ab' * 32,
  notes: '소음 표시를 고쳤습니다',
);

/// 작성: 2026-10-13 14:27:24 · nada
/// 클래스: _FakeInstaller
/// 목적: 안드로이드 통로 대신 쓰는 가짜 설치기. 설치 허용 · 내려받기 ·
///       설치 결과를 시험이 정하고, 불린 요청을 기록한다.
class _FakeInstaller implements UpdateInstaller {
  /// 설치가 허용돼 있는지
  bool allowed = true;

  /// 내려받기가 던질 실패 코드. null 이면 성공
  String? downloadError;

  /// 설치 결과
  InstallOutcome outcome = InstallOutcome.success;

  /// 불린 요청 이름을 차례대로 기록한다
  final List<String> calls = <String>[];

  /// 작성: 2026-10-13 14:27:24 · nada
  /// 함수: canInstall
  /// 목적: 설치 허용 여부를 `allowed` 로 답한다.
  @override
  Future<bool> canInstall() async {
    calls.add('canInstall');
    return allowed;
  }

  /// 작성: 2026-10-13 14:27:24 · nada
  /// 함수: openInstallSettings
  /// 목적: 설정 화면에서 돌아온 결과를 `allowed` 로 답한다.
  @override
  Future<bool> openInstallSettings() async {
    calls.add('openInstallSettings');
    return allowed;
  }

  /// 작성: 2026-10-13 14:27:24 · nada
  /// 함수: progress
  /// 목적: 50% 진행률 한 건을 흘려보낸다.
  @override
  Stream<DownloadProgress> progress() =>
      Stream<DownloadProgress>.value(const DownloadProgress(50, 100));

  /// 작성: 2026-10-13 14:27:24 · nada
  /// 함수: download
  /// 목적: `downloadError` 가 있으면 그 코드로 실패하고, 없으면 가짜 경로를
  ///       돌려준다.
  @override
  Future<String> download(UpdateInfo info) async {
    calls.add('download');
    final error = downloadError; // 던질 실패 코드
    if (error != null) throw UpdateDownloadException(error);
    return '/cache/update/vcheck-update.apk';
  }

  /// 작성: 2026-10-13 14:27:24 · nada
  /// 함수: cancelDownload
  /// 목적: 취소 요청을 기록한다.
  @override
  Future<void> cancelDownload() async => calls.add('cancelDownload');

  /// 작성: 2026-10-13 14:27:24 · nada
  /// 함수: install
  /// 목적: 설치 결과를 `outcome` 으로 답한다.
  @override
  Future<(InstallOutcome, String?)> install(String path) async {
    calls.add('install');
    return (outcome, null);
  }
}

/// 작성: 2026-10-13 14:27:24 · nada
/// 함수: _checker
/// 목적: 가짜 서버로 확인기를 만든다.
/// 인자: respond — 서버 응답. 안 주면 latest 13 · minimum 12 정상 응답
///       build — 설치된 빌드 번호
/// 반환: 시험용 확인기
UpdateChecker _checker({
  Future<http.Response> Function(http.Request)? respond,
  int build = 12,
}) {
  final body = jsonEncode({
    'latest': 13,
    'latestName': '0.1.3',
    'minimum': 12,
    'apkUrl': 'https://github.com/o/r/releases/download/v/v.apk',
    'sha256': 'ab' * 32,
    'notes': '',
  }); // 정상 version.json
  return UpdateChecker(
    client: MockClient(
      respond ?? (_) async => http.Response.bytes(utf8.encode(body), 200),
    ),
    currentBuild: () async => build,
    now: () => DateTime(2026, 10, 13, 9),
  );
}

/// 작성: 2026-10-13 14:27:24 · nada
/// 함수: _pumpHost
/// 목적: 창을 띄울 빈 화면을 띄우고 그 위치 정보를 돌려준다.
/// 인자: tester — 위젯 시험 도구
/// 반환: 빈 화면의 위치 정보
Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext ctx; // 빈 화면의 위치 정보
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return ctx;
}

/// 작성: 2026-10-13 14:27:24 · nada
/// 함수: main
/// 목적: 업데이트 안내 창을 시험한다.
///       - 선택 창: "나중에" 로 닫히고 기록이 남는지, "업데이트" 가 허용
///         확인 → 내려받기 → 설치로 이어지는지, 지문 불일치 · 서명 충돌
///         안내가 뜨는지
///       - 필수 창: "나중에" 가 없고 뒤로가기로 닫히지 않는지, 설치가
///         취소되면 다시 뜨는지
///       - 설치 허용이 꺼져 있으면 설정 안내를 띄우는지
///       - 설정 화면 "업데이트 확인" 의 최신 · 인터넷 · 서버 문구
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('선택 창은 "나중에" 로 닫히고 같은 번호를 기록한다', (tester) async {
    final ctx = await _pumpHost(tester); // 창을 띄울 자리
    final installer = _FakeInstaller(); // 가짜 설치기
    final prompt = UpdatePrompt(checker: _checker(), installer: installer);

    unawaited(
      prompt.offer(ctx, UpdateCheck(UpdateDecision.optional, info: _info)),
    );
    await tester.pumpAndSettle();

    expect(find.text('새 버전이 있습니다'), findsOneWidget);
    expect(find.textContaining('새 버전 0.1.3'), findsOneWidget);
    expect(find.textContaining('소음 표시를 고쳤습니다'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    expect(find.text('새 버전이 있습니다'), findsNothing);
    expect(installer.calls, isEmpty);
    final prefs = await SharedPreferences.getInstance(); // 기기 저장소
    expect(prefs.getInt('updateSnoozeLatest'), 13);
  });

  testWidgets('필수 창은 "나중에" 가 없고 뒤로가기로 닫히지 않는다', (tester) async {
    final ctx = await _pumpHost(tester); // 창을 띄울 자리
    final prompt = UpdatePrompt(
      checker: _checker(),
      installer: _FakeInstaller(),
    );

    unawaited(
      prompt.offer(ctx, UpdateCheck(UpdateDecision.required, info: _info)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('이 버전은 더 이상 사용할 수 없습니다'), findsOneWidget);
    expect(find.text('나중에'), findsNothing);
    await tester.binding.handlePopRoute(); // 시스템 뒤로가기
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있습니다'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // 창 바깥
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있습니다'), findsOneWidget);
  });

  testWidgets('"업데이트" 는 허용 확인 → 내려받기 → 설치로 이어진다', (tester) async {
    final ctx = await _pumpHost(tester); // 창을 띄울 자리
    final installer = _FakeInstaller(); // 가짜 설치기
    final prompt = UpdatePrompt(checker: _checker(), installer: installer);

    unawaited(
      prompt.offer(ctx, UpdateCheck(UpdateDecision.optional, info: _info)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('업데이트'));
    await tester.pumpAndSettle();

    expect(installer.calls, ['canInstall', 'download', 'install']);
    expect(find.text('새 버전이 있습니다'), findsNothing);
  });

  testWidgets('필수 업데이트 설치를 취소하면 창이 다시 뜬다', (tester) async {
    final ctx = await _pumpHost(tester); // 창을 띄울 자리
    final installer = _FakeInstaller()
      ..outcome = InstallOutcome.aborted; // 확인 화면에서 취소
    final prompt = UpdatePrompt(checker: _checker(), installer: installer);

    unawaited(
      prompt.offer(ctx, UpdateCheck(UpdateDecision.required, info: _info)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('업데이트'));
    await tester.pumpAndSettle();

    expect(installer.calls, ['canInstall', 'download', 'install']);
    expect(find.text('새 버전이 있습니다'), findsOneWidget);
  });

  testWidgets('설치 허용이 꺼져 있으면 설정 안내 후 설정 화면을 연다', (tester) async {
    final ctx = await _pumpHost(tester); // 창을 띄울 자리
    final installer = _FakeInstaller()..allowed = false; // 허용 꺼짐
    final prompt = UpdatePrompt(checker: _checker(), installer: installer);

    unawaited(
      prompt.offer(ctx, UpdateCheck(UpdateDecision.optional, info: _info)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('업데이트'));
    await tester.pumpAndSettle();

    expect(find.text("설정에서 'V-Check 의 앱 설치 허용'을 켠 뒤 돌아오세요."), findsOneWidget);
    await tester.tap(find.text('설정 열기'));
    await tester.pumpAndSettle();

    expect(installer.calls, ['canInstall', 'openInstallSettings']);
    expect(find.text('설치 허용이 꺼져 있어 업데이트하지 않았습니다.'), findsOneWidget);
  });

  testWidgets('받은 파일 지문이 다르면 설치하지 않고 알린다', (tester) async {
    final ctx = await _pumpHost(tester); // 창을 띄울 자리
    final installer = _FakeInstaller()..downloadError = 'sha256Mismatch';
    final prompt = UpdatePrompt(checker: _checker(), installer: installer);

    unawaited(
      prompt.offer(ctx, UpdateCheck(UpdateDecision.optional, info: _info)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('업데이트'));
    await tester.pumpAndSettle();

    expect(installer.calls, ['canInstall', 'download']);
    expect(find.text('받은 파일이 손상되어 설치하지 않았습니다. 다시 시도하세요.'), findsOneWidget);
  });

  testWidgets('서명이 달라 거절되면 지우고 새로 설치하라고 안내한다', (tester) async {
    final ctx = await _pumpHost(tester); // 창을 띄울 자리
    final installer = _FakeInstaller()..outcome = InstallOutcome.conflict;
    final prompt = UpdatePrompt(checker: _checker(), installer: installer);

    unawaited(
      prompt.offer(ctx, UpdateCheck(UpdateDecision.optional, info: _info)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('업데이트'));
    await tester.pumpAndSettle();

    expect(find.text('새로 설치가 필요합니다'), findsOneWidget);
    expect(find.textContaining('기존 앱을 지우고 새로 설치해야 합니다'), findsOneWidget);
  });

  group('설정 화면 업데이트 확인', () {
    testWidgets('최신이면 "최신 버전입니다"', (tester) async {
      final prompt = UpdatePrompt(
        checker: _checker(build: 13),
        installer: _FakeInstaller(),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(updatePrompt: prompt)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('업데이트 확인'));
      await tester.tap(find.text('업데이트 확인'));
      await tester.pumpAndSettle();

      expect(find.text('최신 버전입니다'), findsOneWidget);
    });

    testWidgets('서버에 닿지 못하면 확인하지 못했다고 알린다', (tester) async {
      final prompt = UpdatePrompt(
        checker: _checker(
          respond: (_) async => throw http.ClientException('offline'),
        ),
        installer: _FakeInstaller(),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(updatePrompt: prompt)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('업데이트 확인'));
      await tester.tap(find.text('업데이트 확인'));
      await tester.pumpAndSettle();

      expect(find.text('업데이트를 확인하지 못했습니다. 인터넷 연결을 확인하세요.'), findsOneWidget);
    });

    testWidgets('서버에 버전 정보가 없으면(404) 인터넷이 아니라 서버 문제로 알린다', (tester) async {
      final prompt = UpdatePrompt(
        checker: _checker(respond: (_) async => http.Response('', 404)),
        installer: _FakeInstaller(),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(updatePrompt: prompt)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('업데이트 확인'));
      await tester.tap(find.text('업데이트 확인'));
      await tester.pumpAndSettle();

      expect(find.text('업데이트 서버에서 버전 정보를 찾지 못했습니다.'), findsOneWidget);
    });

    testWidgets('새 버전이 있으면 업데이트 창을 띄운다', (tester) async {
      final prompt = UpdatePrompt(
        checker: _checker(build: 12),
        installer: _FakeInstaller(),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(updatePrompt: prompt)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('업데이트 확인'));
      await tester.tap(find.text('업데이트 확인'));
      await tester.pumpAndSettle();

      expect(find.text('새 버전이 있습니다'), findsOneWidget);
    });
  });
}
