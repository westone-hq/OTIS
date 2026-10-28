import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vibration_checker/adapter/update/update_checker.dart';

/// 작성: 2026-10-28 10:50:00 · 박건준
/// 클래스: FakeUpdateServer
/// 목적: 시작 확인 시험용 가짜 배포 서버. latest 13 · minimum 12 인
///       version.json 을 돌려주고, 받은 요청 수를 센다. `gate` 를 주면 그
///       일이 끝날 때까지 응답을 미뤄, 확인하는 동안 화면을 옮기는 경우를
///       만든다.
class FakeUpdateServer {
  /// 작성: 2026-10-28 10:50:00 · 박건준
  /// 함수: FakeUpdateServer
  /// 목적: 가짜 서버를 만든다.
  /// 인자: gate — 응답을 미룰 일. null 이면 바로 응답한다
  FakeUpdateServer({this.gate});

  /// 응답을 미룰 일. null 이면 바로 응답한다
  final Future<void>? gate;

  /// 지금까지 받은 version.json 요청 수
  int requests = 0;

  /// 작성: 2026-10-28 10:50:00 · 박건준
  /// 함수: checker
  /// 목적: 이 서버에 묻는 확인기를 만든다.
  /// 인자: build — 설치된 빌드 번호. 12 면 선택, 11 이면 필수 업데이트
  /// 반환: 시험용 확인기
  UpdateChecker checker({required int build}) {
    final body = jsonEncode({
      'latest': 13,
      'latestName': '0.1.3',
      'minimum': 12,
      'apkUrl': 'https://github.com/o/r/releases/download/v/v.apk',
      'sha256': 'ab' * 32,
      'notes': '',
    }); // 정상 version.json
    return UpdateChecker(
      client: MockClient((_) async {
        requests++;
        await gate;
        return http.Response.bytes(utf8.encode(body), 200);
      }),
      currentBuild: () async => build,
      now: () => DateTime(2026, 10, 28, 9),
    );
  }
}
