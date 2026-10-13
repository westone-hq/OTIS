import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/update_checker.dart';
import 'package:vibration_checker/domain/update/update_config.dart';
import 'package:vibration_checker/domain/update/update_decision.dart';

/// 작성: 2026-10-13 14:18:51 · nada
/// 변수: _body
/// 목적: 서버가 돌려줄 정상 version.json (minimum 12, latest 13).
final String _body = jsonEncode({
  'latest': 13,
  'latestName': '0.1.3',
  'minimum': 12,
  'apkUrl': 'https://github.com/o/r/releases/download/v0.1.3/v.apk',
  'sha256': 'ab' * 32,
  'notes': '고침',
});

/// 작성: 2026-10-13 14:18:51 · nada
/// 함수: _checker
/// 목적: 가짜 서버 응답 · 빌드 번호 · 시각으로 확인기를 만든다.
/// 인자: respond — 요청 하나에 돌려줄 응답을 만드는 함수
///       build — 설치된 빌드 번호
///       now — 지금 시각을 주는 함수. 안 주면 2026-10-13 09:00
/// 반환: 시험용 확인기
UpdateChecker _checker(
  Future<http.Response> Function(http.Request) respond, {
  int build = 12,
  DateTime Function()? now,
}) {
  return UpdateChecker(
    client: MockClient(respond),
    currentBuild: () async => build,
    now: now ?? () => DateTime(2026, 10, 13, 9),
  );
}

/// 작성: 2026-10-13 14:18:51 · nada
/// 함수: _ok
/// 목적: 정상 version.json 을 200 으로 돌려주는 가짜 응답.
/// 인자: request — 받은 요청
/// 반환: 응답
Future<http.Response> _ok(http.Request request) async =>
    http.Response.bytes(utf8.encode(_body), 200);

/// 작성: 2026-10-13 14:18:51 · nada
/// 함수: main
/// 목적: `UpdateChecker` 를 시험한다. 성공 · 시간 초과 · 404 · 깨진 JSON
///       에서 앞의 셋이 앱을 막지 않는 `none` 인지, 판정이 맞는지, "나중에"
///       하루 한 번 규칙과 수동 확인 · 필수 업데이트 · 시계 되돌림의
///       예외, 빌드 번호를 못 읽을 때를 본다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('정상 응답이면 서버 정보로 판정하고, 요청 주소는 설정값이다', () async {
    Uri? asked; // 요청한 주소
    final checker = _checker((request) async {
      asked = request.url;
      return _ok(request);
    }); // 빌드 12 → optional

    final result = await checker.check(); // 확인 결과

    expect(asked.toString(), UpdateConfig.versionJsonUrl);
    expect(result.decision, UpdateDecision.optional);
    expect(result.info!.latest, 13);
    expect(result.failure, isNull);
  });

  test(
    '시간 초과 · 404 · 연결 실패 · 깨진 JSON 은 none 과 갈래별 사유',
    () async {
      final cases =
          <
            String,
            (Future<http.Response> Function(http.Request), UpdateCheckFailure)
          >{
            '시간 초과': (
              (_) => Completer<http.Response>().future,
              UpdateCheckFailure.network,
            ),
            '404': (
              (_) async => http.Response('Not Found', 404),
              UpdateCheckFailure.server,
            ),
            '연결 실패': (
              (_) async => throw http.ClientException('offline'),
              UpdateCheckFailure.network,
            ),
            '깨진 JSON': (
              (_) async => http.Response('{"latest":', 200),
              UpdateCheckFailure.invalid,
            ),
          }; // 상황 → (가짜 응답, 기대 갈래)
      for (final entry in cases.entries) {
        final (respond, kind) = entry.value; // 가짜 응답과 기대 갈래
        final result = await _checker(respond, build: 1).check(); // 결과
        expect(result.decision, UpdateDecision.none, reason: entry.key);
        expect(result.failure, kind, reason: entry.key);
        expect(result.failureDetail, isNotNull, reason: entry.key);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('빌드가 minimum 보다 낮으면 required, 최신이면 none', () async {
    expect(
      (await _checker(_ok, build: 11).check()).decision,
      UpdateDecision.required,
    );
    expect(
      (await _checker(_ok, build: 13).check()).decision,
      UpdateDecision.none,
    );
  });

  test('"나중에" 를 누르면 같은 번호의 선택 창은 하루 동안 앱 시작 때 안 뜬다', () async {
    var now = DateTime(2026, 10, 13, 9); // 가짜 지금 시각
    final checker = _checker(_ok, now: () => now); // 빌드 12
    final first = await checker.check(); // 처음 확인
    await checker.snooze(first.info!);

    now = DateTime(2026, 10, 14, 8, 59);
    expect((await checker.check()).decision, UpdateDecision.none);
    expect(
      (await checker.check(manual: true)).decision,
      UpdateDecision.optional,
      reason: '설정의 수동 확인은 "나중에" 를 보지 않는다',
    );

    now = DateTime(2026, 10, 14, 9);
    expect((await checker.check()).decision, UpdateDecision.optional);
  });

  test('"나중에" 기록이 예전 번호면 새 번호의 창은 바로 뜬다', () async {
    SharedPreferences.setMockInitialValues({
      'updateSnoozeLatest': 12,
      'updateSnoozeAtMs': DateTime(2026, 10, 13, 8).millisecondsSinceEpoch,
    }); // 한 시간 전 latest 12 일 때 "나중에" 를 누른 기록
    final checker = _checker(_ok, build: 12); // 서버 latest 는 13

    expect((await checker.check()).decision, UpdateDecision.optional);
  });

  test('설치된 빌드 번호를 읽지 못하면 필수 창 대신 none 과 사유', () async {
    final checker = UpdateChecker(
      client: MockClient(_ok),
      currentBuild: () async => null,
    ); // 빌드 번호를 못 읽는 확인기

    final result = await checker.check(); // 확인 결과
    expect(result.decision, UpdateDecision.none);
    expect(result.failure, UpdateCheckFailure.invalid);
  });

  test('기기 시계를 "나중에" 이전으로 되돌리면 창을 다시 띄운다', () async {
    var now = DateTime(2026, 10, 13, 9); // 가짜 지금 시각
    final checker = _checker(_ok, now: () => now); // 빌드 12
    await checker.snooze((await checker.check()).info!);

    now = DateTime(2026, 10, 12, 9); // 하루 뒤로 되돌림
    expect((await checker.check()).decision, UpdateDecision.optional);
  });

  test('필수 업데이트는 "나중에" 기록이 있어도 매번 띄운다', () async {
    final checker = _checker(_ok, build: 11); // minimum 12 보다 낮다
    await checker.snooze((await checker.check()).info!);

    expect((await checker.check()).decision, UpdateDecision.required);
  });
}
