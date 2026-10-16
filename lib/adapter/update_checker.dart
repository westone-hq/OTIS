import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import 'package:vibration_checker/domain/update/update_config.dart';
import 'package:vibration_checker/domain/update/update_decision.dart';
import 'package:vibration_checker/domain/update/update_info.dart';

/// 작성: 2026-10-13 16:27:48 · nada
/// 클래스: UpdateCheckFailure
/// 목적: 업데이트를 확인하지 못한 갈래. 설정 화면의 수동 확인이 갈래마다
///       다른 문구를 띄운다 — 서버에 파일이 없는데 "인터넷 연결을 확인" 이라
///       하면 틀린 안내가 된다.
///       - `network` — 서버에 닿지 못했다(인터넷 없음 · 시간 초과)
///       - `server` — 서버가 200 이 아닌 응답을 줬다(배포 저장소 · 릴리스
///         없음 등)
///       - `invalid` — 받은 version.json 형식이 틀렸거나 설치된 빌드 번호를
///         읽지 못했다
enum UpdateCheckFailure { network, server, invalid }

/// 작성: 2026-10-13 14:18:51 · nada
/// 클래스: UpdateCheck
/// 목적: 업데이트 확인 한 번의 결과. 화면은 `decision` 으로 창을 고르고,
///       설정 화면의 수동 확인만 `failure` 를 보고 "확인하지 못함" 을
///       따로 알린다.
class UpdateCheck {
  /// 안내 종류. 확인하지 못했으면 `none`
  final UpdateDecision decision;

  /// 서버의 버전 정보. 받지 못했으면 null
  final UpdateInfo? info;

  /// 확인하지 못한 갈래. 확인했으면 null
  final UpdateCheckFailure? failure;

  /// 확인하지 못한 사유를 기록용으로 적은 말(응답 코드 · 예외 등).
  /// 확인했으면 null
  final String? failureDetail;

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 함수: UpdateCheck
  /// 목적: 결과를 담는다.
  /// 인자: decision, info, failure, failureDetail — 위 필드
  const UpdateCheck(
    this.decision, {
    this.info,
    this.failure,
    this.failureDetail,
  });
}

/// 작성: 2026-10-13 14:18:51 · nada
/// 클래스: UpdateChecker
/// 목적: 배포 서버의 version.json 을 받아 설치된 빌드와 견준다. 앱이 켜질
///       때 홈 화면이, 설정 화면의 "업데이트 확인" 이 부른다. 측정 · 결과
///       화면에서는 부르지 않는다.
///       인터넷이 없거나 서버가 응답하지 않으면 조용히 `none` 으로 보고
///       앱을 그대로 쓰게 한다 — 기계실처럼 인터넷이 없는 곳에서 측정을
///       막으면 안 된다. 사유는 기록(`debugPrint`)에만 남긴다.
class UpdateChecker {
  /// 작성: 2026-10-13 14:18:51 · nada
  /// 함수: UpdateChecker
  /// 목적: 확인기를 만든다. 시험이 바꿔 끼울 수 있는 것만 인자로 받는다.
  /// 인자: client — 내려받기에 쓸 HTTP 연결. 안 주면 확인할 때마다 새로
  ///       만들고 끝나면 닫는다
  ///       currentBuild — 설치된 빌드 번호를 읽는 함수. 안 주면
  ///       `PackageInfo.buildNumber`
  ///       now — 지금 시각을 주는 함수. 안 주면 `DateTime.now`
  UpdateChecker({
    this._client,
    Future<int?> Function()? currentBuild,
    DateTime Function()? now,
  }) : _currentBuild = currentBuild ?? _installedBuild,
       _now = now ?? DateTime.now;

  /// 밖에서 받은 HTTP 연결(시험용 가짜 서버). null 이면 확인마다 새로
  /// 만들어 쓰고 닫는다 — 닫지 않으면 연결이 앱이 끝날 때까지 남는다
  final http.Client? _client;

  /// 설치된 빌드 번호를 읽는 함수. 읽지 못하면 null
  final Future<int?> Function() _currentBuild;

  /// 지금 시각을 주는 함수. "나중에" 하루 규칙에 쓴다
  final DateTime Function() _now;

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 함수: _installedBuild
  /// 목적: 설치된 앱의 빌드 번호(pubspec `version:` 의 `+` 뒤)를 읽는다.
  /// 반환: 빌드 번호. 숫자가 아니면 null — 0 같은 값으로 채우면 서버의
  ///       어떤 번호보다 낮아 닫을 수 없는 필수 창이 뜬다
  static Future<int?> _installedBuild() async {
    final info = await PackageInfo.fromPlatform(); // 설치된 앱 정보
    return int.tryParse(info.buildNumber);
  }

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 함수: check
  /// 목적: 업데이트가 있는지 확인한다. 순서대로 진행한다.
  ///       1. version.json 을 `UpdateConfig.checkTimeout` 안에 받는다.
  ///          못 받거나 200 이 아니면 `none` 과 사유
  ///       2. `UpdateInfo.parse()` 로 읽는다. 형식 오류면 `none` 과 사유
  ///       3. 설치된 빌드와 견줘 `UpdateDecision.decide()` 로 고른다.
  ///          빌드 번호를 읽지 못하면 `none` 과 사유
  ///       4. 앱 시작 확인(`manual` false)에서 `optional` 이고, 같은 최신
  ///          번호로 "나중에" 를 누른 지 `UpdateConfig.snoozeDuration` 이
  ///          안 지났으면 `none` 으로 바꾼다. 누른 시각이 지금보다 뒤면
  ///          (기기 시계를 되돌림) 지난 것으로 본다 — 그러지 않으면 되돌린
  ///          만큼 창이 뜨지 않는다. `required` 는 매번 띄운다
  /// 인자: manual — 설정 화면에서 사용자가 직접 누른 확인이면 true.
  ///       "나중에" 기록을 보지 않는다
  /// 반환: 확인 결과
  Future<UpdateCheck> check({bool manual = false}) async {
    final String body; // 받은 version.json 내용
    final client = _client ?? http.Client(); // 이번 확인에 쓸 연결
    try {
      final response = await client
          .get(Uri.parse(UpdateConfig.versionJsonUrl))
          .timeout(UpdateConfig.checkTimeout); // 서버 응답
      if (response.statusCode != 200) {
        return _failed(UpdateCheckFailure.server, '응답 ${response.statusCode}');
      }
      body = utf8.decode(response.bodyBytes);
    } on TimeoutException {
      return _failed(UpdateCheckFailure.network, '시간 초과');
    } on Exception catch (e) {
      return _failed(UpdateCheckFailure.network, '받기 실패: $e');
    } finally {
      if (_client == null) client.close();
    }

    // → 로직 이동: UpdateInfo.parse()
    final parsed = UpdateInfo.parse(body);
    final info = parsed.info; // 읽은 버전 정보, 형식 오류면 null
    if (info == null) {
      return _failed(UpdateCheckFailure.invalid, '형식 오류: $parsed');
    }

    final build = await _currentBuild(); // 설치된 빌드 번호, 못 읽으면 null
    if (build == null) {
      return _failed(UpdateCheckFailure.invalid, '설치된 빌드 번호를 읽지 못함');
    }
    // → 로직 이동: UpdateDecision.decide()
    final decision = UpdateDecision.decide(build, info);
    if (!manual && decision == UpdateDecision.optional) {
      // → 로직 이동: PrefsStore.loadUpdateSnooze()
      final snooze = await PrefsStore.instance.loadUpdateSnooze();
      final since = snooze == null
          ? null
          : _now().difference(snooze.$2); // "나중에" 뒤 지난 시간
      if (snooze != null &&
          snooze.$1 == info.latest &&
          since != null &&
          !since.isNegative &&
          since < UpdateConfig.snoozeDuration) {
        return UpdateCheck(UpdateDecision.none, info: info);
      }
    }
    return UpdateCheck(decision, info: info);
  }

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 함수: snooze
  /// 목적: 선택 업데이트 창에서 "나중에" 를 누른 것을 기록한다. 같은
  ///       최신 번호의 창은 `UpdateConfig.snoozeDuration` 동안 앱 시작
  ///       때 다시 뜨지 않는다.
  /// 인자: info — 그 창이 안내한 버전 정보
  Future<void> snooze(UpdateInfo info) =>
      // → 로직 이동: PrefsStore.saveUpdateSnooze()
      PrefsStore.instance.saveUpdateSnooze(info.latest, _now());

  /// 작성: 2026-10-13 14:18:51 · nada
  /// 함수: _failed
  /// 목적: 확인하지 못한 결과를 만들고 사유를 기록에 남긴다.
  /// 인자: failure — 확인하지 못한 갈래
  ///       detail — 기록에 남길 사유
  /// 반환: `none` 과 사유를 담은 결과
  UpdateCheck _failed(UpdateCheckFailure failure, String detail) {
    debugPrint('UpdateChecker: 업데이트 확인 못 함 — ${failure.name}: $detail');
    return UpdateCheck(
      UpdateDecision.none,
      failure: failure,
      failureDetail: detail,
    );
  }
}
