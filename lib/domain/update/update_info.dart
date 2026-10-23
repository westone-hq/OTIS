import 'dart:convert';

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: UpdateInfoError
/// 목적: 배포 서버의 버전 안내 파일(version.json)을 읽지 못한 사유.
///       - `notJson` — JSON 이 아니거나 맨 바깥이 표(객체)가 아니다
///       - `missingField` — 필수 항목이 없다
///       - `wrongType` — 항목의 자료형이 다르다(번호가 정수가 아님 등)
///       - `notHttps` — `apkUrl` 이 https 주소가 아니다
///       - `badSha256` — `sha256` 이 16진수 소문자 64자가 아니다
///       - `minimumAboveLatest` — `minimum` 이 `latest` 보다 크다
///       - `notPositive` — 빌드 번호가 1 보다 작다
enum UpdateInfoError {
  notJson,
  missingField,
  wrongType,
  notHttps,
  badSha256,
  minimumAboveLatest,
  notPositive,
}

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: UpdateInfoParseResult
/// 목적: version.json 읽기 결과. 성공이면 `info`, 실패면 `error` 와
///       `detail` 하나만 채운다. 형식이 틀린 파일을 빈 값으로 바꿔 삼키지
///       않고 사유를 올린다.
class UpdateInfoParseResult {
  /// 읽은 버전 정보. 실패면 null
  final UpdateInfo? info;

  /// 실패 사유. 성공이면 null
  final UpdateInfoError? error;

  /// 실패 사유를 사람이 읽을 수 있게 덧붙인 말(어느 항목인지 등). 성공이면
  /// null
  final String? detail;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: UpdateInfoParseResult.success
  /// 목적: 성공 결과를 만든다.
  /// 인자: info — 읽은 버전 정보
  const UpdateInfoParseResult.success(UpdateInfo this.info)
    : error = null,
      detail = null;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: UpdateInfoParseResult.failure
  /// 목적: 실패 결과를 만든다.
  /// 인자: error — 실패 사유
  ///       detail — 덧붙일 설명
  const UpdateInfoParseResult.failure(UpdateInfoError this.error, this.detail)
    : info = null;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: toString
  /// 목적: 실패 사유를 기록(`debugPrint`)에 남길 한 줄로 만든다.
  @override
  String toString() => info != null
      ? 'UpdateInfoParseResult(ok, latest ${info!.latest})'
      : 'UpdateInfoParseResult(${error!.name}: $detail)';
}

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: UpdateInfo
/// 목적: 배포 서버(GitHub Releases)에 올린 version.json 한 건. 앱이 켜질
///       때 이것을 받아 새 버전이 있는지(`UpdateDecision`) 고른다.
///       번호는 모두 빌드 번호(pubspec.yaml `version:` 의 `+` 뒤 숫자)다.
/// 근거: 인용 — 2026-10-13 개선 지시 ③ 의 version.json 형식
class UpdateInfo {
  /// 최신 빌드 번호. 1 이상
  final int latest;

  /// 최신 버전 이름(pubspec `version:` 의 `+` 앞, 예: "0.0.1"). 화면에
  /// 보여 주는 용도
  final String latestName;

  /// 쓸 수 있는 가장 낮은 빌드 번호. 이보다 낮은 빌드는 업데이트하기
  /// 전까지 쓸 수 없다. 1 이상이고 `latest` 이하
  final int minimum;

  /// 최신 APK 를 받을 https 주소
  final Uri apkUrl;

  /// 최신 APK 의 SHA-256 (16진수 소문자 64자). 받은 파일을 이 값과 맞춰
  /// 본 뒤에만 설치한다
  final String sha256;

  /// 사용자에게 보여 줄 바뀐 점 한두 줄. 비어 있을 수 있다
  final String notes;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: UpdateInfo
  /// 목적: 검사를 마친 값으로 버전 정보를 만든다. 외부 파일에서 읽을 때는
  ///       `UpdateInfo.parse()` 를 거친다.
  /// 인자: latest, latestName, minimum, apkUrl, sha256, notes — 위 필드
  const UpdateInfo({
    required this.latest,
    required this.latestName,
    required this.minimum,
    required this.apkUrl,
    required this.sha256,
    required this.notes,
  });

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 변수: _sha256Pattern
  /// 목적: SHA-256 16진수 표기 검사. `sha256sum` 이 내는 소문자 64자만
  ///       받는다 — 대문자를 섞어 받으면 비교할 때 한쪽만 바꾸는 실수가
  ///       생긴다.
  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: parse
  /// 목적: version.json 본문을 읽어 검사한다. 순서대로 본다.
  ///       1. JSON 이고 맨 바깥이 표인지
  ///       2. 여섯 항목(`latest` · `latestName` · `minimum` · `apkUrl` ·
  ///          `sha256` · `notes`)이 모두 있고 자료형이 맞는지
  ///       3. 빌드 번호가 1 이상이고 `minimum` ≤ `latest` 인지
  ///       4. `apkUrl` 이 https 이고 주소 자리(host)가 있는지 — 받는 파일은
  ///          곧 설치되므로 가로챌 수 있는 http 를 받지 않는다
  ///       5. `sha256` 형식
  /// 인자: body — 받은 파일 내용(UTF-8 문자열)
  /// 반환: 성공이면 버전 정보, 아니면 처음 걸린 사유
  static UpdateInfoParseResult parse(String body) {
    Object? decoded; // JSON 을 읽은 값
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      return UpdateInfoParseResult.failure(UpdateInfoError.notJson, e.message);
    }
    if (decoded is! Map<String, dynamic>) {
      return const UpdateInfoParseResult.failure(
        UpdateInfoError.notJson,
        '맨 바깥이 표가 아니다',
      );
    }

    const fields = <String, Type>{
      'latest': int,
      'latestName': String,
      'minimum': int,
      'apkUrl': String,
      'sha256': String,
      'notes': String,
    }; // 필수 항목과 자료형
    for (final entry in fields.entries) {
      final value = decoded[entry.key]; // 항목 값, 없으면 null
      if (value == null) {
        return UpdateInfoParseResult.failure(
          UpdateInfoError.missingField,
          entry.key,
        );
      }
      final typeOk = entry.value == int ? value is int : value is String;
      if (!typeOk) {
        return UpdateInfoParseResult.failure(
          UpdateInfoError.wrongType,
          '${entry.key}: ${value.runtimeType}',
        );
      }
    }

    final latest = decoded['latest'] as int; // 최신 빌드 번호
    final minimum = decoded['minimum'] as int; // 쓸 수 있는 최저 빌드 번호
    if (latest < 1 || minimum < 1) {
      return UpdateInfoParseResult.failure(
        UpdateInfoError.notPositive,
        'latest $latest, minimum $minimum',
      );
    }
    if (minimum > latest) {
      return UpdateInfoParseResult.failure(
        UpdateInfoError.minimumAboveLatest,
        'latest $latest, minimum $minimum',
      );
    }

    final rawUrl = decoded['apkUrl'] as String; // APK 주소 문자열
    final apkUrl = Uri.tryParse(rawUrl); // 읽은 주소, 못 읽으면 null
    if (apkUrl == null || apkUrl.scheme != 'https' || apkUrl.host.isEmpty) {
      return UpdateInfoParseResult.failure(UpdateInfoError.notHttps, rawUrl);
    }

    final sha256 = decoded['sha256'] as String; // APK 지문
    if (!_sha256Pattern.hasMatch(sha256)) {
      return UpdateInfoParseResult.failure(UpdateInfoError.badSha256, sha256);
    }

    return UpdateInfoParseResult.success(
      UpdateInfo(
        latest: latest,
        latestName: decoded['latestName'] as String,
        minimum: minimum,
        apkUrl: apkUrl,
        sha256: sha256,
        notes: (decoded['notes'] as String).trim(),
      ),
    );
  }
}
