import 'dart:convert';

import 'package:vibration_checker/model/worker.dart';

/// 작성: 2026-10-18 09:09:47 · nada
/// 클래스: LoginFailure
/// 목적: 로그인을 받아 주지 않은 사유의 종류. 로그인 화면이 종류마다 안내
///       문구와 옮겨 갈 입력칸을 고른다.
///       - `idMissing` — 사번이 비었다
///       - `passwordMissing` — 비밀번호가 비었다
///       - `unknownId` — 명단에 없는 사번이다
///       - `wrongPassword` — 비밀번호가 맞지 않는다
enum LoginFailure { idMissing, passwordMissing, unknownId, wrongPassword }

/// 작성: 2026-10-18 09:09:47 · nada
/// 클래스: LoginResult
/// 목적: `WorkerDirectory.authenticate()` 의 결과. 성공이면 작업자를,
///       실패면 사유를 담는다. 화면이 예외를 잡지 않고 갈래만 나누게 한다.
class LoginResult {
  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: LoginResult.success
  /// 목적: 로그인을 받아 준 결과를 만든다.
  /// 인자: worker — 로그인한 작업자
  const LoginResult.success(Worker this.worker) : failure = null;

  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: LoginResult.failure
  /// 목적: 로그인을 받아 주지 않은 결과를 만든다.
  /// 인자: failure — 사유 종류
  const LoginResult.failure(LoginFailure this.failure) : worker = null;

  /// 로그인한 작업자. 실패면 null
  final Worker? worker;

  /// 실패 사유. 성공이면 null
  final LoginFailure? failure;
}

/// 작성: 2026-10-18 09:09:47 · nada
/// 클래스: WorkerDirectory
/// 목적: 앱에 들어 있는 작업자 명단. 사번으로 작업자를 찾고 로그인을
///       판정한다. 서버가 없어 명단은 앱 자산(`assets/workers/workers.json`)
///       하나이고, 명단이 바뀌면 앱을 새로 빌드해 배포한다.
class WorkerDirectory {
  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: WorkerDirectory
  /// 목적: 사번을 열쇠로 하는 표로 명단을 만든다.
  /// 인자: workers — 명단. 사번이 겹치지 않아야 한다(`parse()` 가 검사한다)
  WorkerDirectory(Iterable<Worker> workers)
    : _byId = {for (final w in workers) w.employeeId: w};

  /// 사번(대문자) → 작업자
  final Map<String, Worker> _byId;

  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: length
  /// 목적: 명단에 든 작업자 수.
  int get length => _byId.length;

  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: WorkerDirectory.parse
  /// 목적: 명단 JSON(`tool/import_workers.py` 가 만든 형태)을 읽는다. 사번 ·
  ///       성명이 비었거나 사번이 겹치면 그 줄을 건너뛰지 않고 실패로
  ///       올린다 — 건너뛰면 그 작업자가 왜 로그인하지 못하는지 현장에서
  ///       알 수 없다.
  /// 인자: source — 명단 JSON 문자열.
  ///       `{"source": 엑셀 이름, "workers": [{"id", "name", "company", "team"}]}`
  /// 반환: 명단. 형식이 틀리면 `FormatException` 을 던진다
  factory WorkerDirectory.parse(String source) {
    final Object? decoded = jsonDecode(source); // JSON 을 풀어 낸 값
    if (decoded is! Map<String, Object?> || decoded['workers'] is! List) {
      throw const FormatException('작업자 명단에 workers 목록이 없다');
    }
    final workers = <Worker>[]; // 읽어 낸 작업자
    final seen = <String>{}; // 이미 나온 사번
    for (final Object? entry in decoded['workers'] as List) {
      if (entry is! Map<String, Object?>) {
        throw FormatException('작업자 명단 항목이 표가 아니다: $entry');
      }
      final id = normalizeId('${entry['id'] ?? ''}'); // 대문자로 맞춘 사번
      final name = (entry['name'] as String?)?.trim() ?? ''; // 성명
      if (id.isEmpty || name.isEmpty) {
        throw FormatException('작업자 명단에 사번 · 성명이 빈 항목이 있다: $entry');
      }
      if (!seen.add(id)) {
        throw FormatException('작업자 명단에 사번 $id 가 겹친다');
      }
      workers.add(
        Worker(
          employeeId: id,
          name: name,
          // → 로직 이동: _optional()
          company: _optional(entry['company']),
          team: _optional(entry['team']), // → 로직 이동: _optional()
        ),
      );
    }
    return WorkerDirectory(workers);
  }

  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: _optional
  /// 목적: 비워 둘 수 있는 칸을 읽는다. 빈 문자열은 null 로 읽는다 — 빈
  ///       문자열을 업체명 · 관리팀 값으로 남기지 않는다.
  /// 인자: value — 명단 항목의 칸 값
  /// 반환: 앞뒤 공백을 지운 문자열. 없거나 비었으면 null
  static String? _optional(Object? value) {
    final text = (value as String?)?.trim(); // 앞뒤 공백을 지운 값
    return text == null || text.isEmpty ? null : text;
  }

  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: normalizeId
  /// 목적: 사번을 대조할 형태로 맞춘다. 앞뒤 공백을 지우고 대문자로 바꾼다
  ///       — 현장에서 "t00001" 처럼 소문자로 적어도 같은 사람으로 본다.
  ///       명단을 읽을 때와 로그인 입력을 받을 때 둘 다 이 함수를 쓴다.
  /// 인자: id — 사번 문자열
  /// 반환: 맞춘 사번
  static String normalizeId(String id) => id.trim().toUpperCase();

  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: find
  /// 목적: 사번으로 작업자를 찾는다. 앱을 다시 켤 때 기기에 남은 로그인
  ///       사번을 되살리는 데 쓴다(`LoginStore.restore()`).
  /// 인자: employeeId — 사번. 대소문자 · 앞뒤 공백은 가리지 않는다
  /// 반환: 작업자. 명단에 없으면 null
  Worker? find(String employeeId) => _byId[normalizeId(employeeId)];

  /// 작성: 2026-10-18 09:09:47 · nada
  /// 함수: authenticate
  /// 목적: 사번 · 비밀번호로 로그인을 판정한다. 비밀번호는 사번과 같다 —
  ///       사번과 같은 규칙(`normalizeId()`)으로 맞춰 비교한다.
  /// 인자: employeeId — 입력한 사번
  ///       password — 입력한 비밀번호
  /// 반환: 성공이면 작업자, 실패면 사유
  /// 근거: 인용 — 2026-10-18 사용자 결정 "사번과 비밀번호는 동일하게. 보안은
  ///       일단 신경쓰지 말고". 서버가 없어 비밀번호를 바꿀 곳이 없다
  LoginResult authenticate(String employeeId, String password) {
    final id = normalizeId(employeeId); // 맞춘 사번
    if (id.isEmpty) return const LoginResult.failure(LoginFailure.idMissing);
    if (password.trim().isEmpty) {
      return const LoginResult.failure(LoginFailure.passwordMissing);
    }
    final worker = _byId[id]; // 명단의 작업자, 없으면 null
    if (worker == null) {
      return const LoginResult.failure(LoginFailure.unknownId);
    }
    if (normalizeId(password) != id) {
      return const LoginResult.failure(LoginFailure.wrongPassword);
    }
    return LoginResult.success(worker);
  }
}
