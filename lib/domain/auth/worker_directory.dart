import 'dart:convert';

import 'package:vibration_checker/domain/auth/worker.dart';

/// 작성: 2026-10-18 09:09:47 · 박건준
/// 클래스: LoginFailure
/// 목적: 로그인을 받아 주지 않은 사유의 종류. 로그인 화면이 종류마다 안내
///       문구와 옮겨 갈 입력칸을 고른다.
///       - `idMissing` — 사번이 비었다
///       - `passwordMissing` — 비밀번호가 비었다
///       - `unknownId` — 명단에 없는 사번이다
///       - `wrongPassword` — 비밀번호가 맞지 않는다
enum LoginFailure { idMissing, passwordMissing, unknownId, wrongPassword }

/// 작성: 2026-10-18 09:09:47 · 박건준
/// 클래스: LoginResult
/// 목적: `WorkerDirectory.authenticate()` 의 결과. 성공이면 작업자를,
///       실패면 사유를 담는다. 화면이 예외를 잡지 않고 갈래만 나누게 한다.
class LoginResult {
  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: LoginResult.success
  /// 목적: 로그인을 받아 준 결과를 만든다.
  /// 인자: worker — 로그인한 작업자
  const LoginResult.success(Worker this.worker) : failure = null;

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: LoginResult.failure
  /// 목적: 로그인을 받아 주지 않은 결과를 만든다.
  /// 인자: failure — 사유 종류
  const LoginResult.failure(LoginFailure this.failure) : worker = null;

  /// 로그인한 작업자. 실패면 null
  final Worker? worker;

  /// 실패 사유. 성공이면 null
  final LoginFailure? failure;
}

/// 작성: 2026-10-18 09:09:47 · 박건준
/// 클래스: WorkerDirectory
/// 목적: 앱에 들어 있는 작업자 명단. 사번으로 작업자를 찾고 로그인을
///       판정한다. 서버가 없어 명단은 앱 자산(`assets/workers/workers.json`)
///       하나이고, 명단이 바뀌면 앱을 새로 빌드해 배포한다.
class WorkerDirectory {
  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: WorkerDirectory
  /// 목적: 사번을 열쇠로 하는 표로 명단을 만든다.
  /// 인자: workers — 명단. 사번이 겹치지 않아야 한다(`parse()` 가 검사한다)
  WorkerDirectory(Iterable<Worker> workers)
    : _byId = {for (final w in workers) w.employeeId: w};

  /// 사번(대문자) → 작업자
  final Map<String, Worker> _byId;

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: length
  /// 목적: 명단에 든 작업자 수.
  int get length => _byId.length;

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 수정: 2026-10-23 13:30:00 · 박건준
  /// 함수: WorkerDirectory.parse
  /// 목적: 명단 JSON(`tool/import_workers.py` 가 만든 형태)을 읽는다. 사번 ·
  ///       성명이 비었거나 사번이 겹치거나 칸의 형식이 틀리면 그 줄을
  ///       건너뛰지 않고 실패로 올린다 — 건너뛰면 그 작업자가 왜 로그인하지
  ///       못하는지 현장에서 알 수 없다. 실패 문구에는 몇 번째 항목(1 부터)의
  ///       어느 칸인지 적는다. 로그인 화면이 그 문구를 오류 알림으로 보인다
  ///       (`LoginScreen._submit()`).
  ///       - `id` · `name` — 문자열이어야 한다
  ///       - `company` · `team` — 문자열이거나 null(OTIS 직원은 업체 · 팀이
  ///         없다)이어야 한다
  /// 인자: source — 명단 JSON 문자열.
  ///       `{"source": 엑셀 이름, "workers": [{"id", "name", "company", "team"}]}`
  /// 반환: 명단. 형식이 틀리면 `FormatException` 을 던진다
  factory WorkerDirectory.parse(String source) {
    final Object? decoded = jsonDecode(source); // JSON 을 풀어 낸 값
    if (decoded is! Map<String, Object?> || decoded['workers'] is! List) {
      throw const FormatException('작업자 명단에 workers 목록이 없다');
    }
    final entries = decoded['workers'] as List; // 명단 항목
    final workers = <Worker>[]; // 읽어 낸 작업자
    final seen = <String>{}; // 이미 나온 사번
    for (var index = 0; index < entries.length; index++) {
      final row = index + 1; // 몇 번째 항목인지 (1 부터)
      final Object? entry = entries[index]; // 이 항목
      if (entry is! Map<String, Object?>) {
        throw FormatException('작업자 명단 $row번째 항목이 표가 아니다: $entry');
      }
      // → 로직 이동: _requiredText()
      final id = normalizeId(_requiredText(entry, 'id', row)); // 맞춘 사번
      final name = _requiredText(entry, 'name', row).trim(); // 성명
      if (id.isEmpty || name.isEmpty) {
        throw FormatException('작업자 명단 $row번째 항목에 사번 · 성명이 비었다: $entry');
      }
      if (!seen.add(id)) {
        throw FormatException('작업자 명단 $row번째 항목의 사번 $id 가 앞 항목과 겹친다');
      }
      workers.add(
        Worker(
          employeeId: id,
          name: name,
          // → 로직 이동: _optionalText()
          company: _optionalText(entry, 'company', row),
          // → 로직 이동: _optionalText()
          team: _optionalText(entry, 'team', row),
        ),
      );
    }
    return WorkerDirectory(workers);
  }

  /// 작성: 2026-10-23 13:30:00 · 박건준
  /// 함수: _requiredText
  /// 목적: 반드시 문자열이어야 하는 칸을 읽는다.
  /// 인자: entry — 명단 항목
  ///       key — 칸 이름 (`id` · `name`)
  ///       row — 몇 번째 항목인지 (1 부터). 실패 문구에 쓴다
  /// 반환: 칸 값. 문자열이 아니면(숫자 · null · 목록 등) `FormatException`
  static String _requiredText(Map<String, Object?> entry, String key, int row) {
    final value = entry[key]; // 칸 값
    if (value is! String) {
      throw FormatException('작업자 명단 $row번째 항목의 $key 가 문자열이 아니다: $value');
    }
    return value;
  }

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 수정: 2026-10-23 13:30:00 · 박건준
  /// 함수: _optionalText
  /// 목적: 비워 둘 수 있는 칸을 읽는다. 빈 문자열은 null 로 읽는다 — 빈
  ///       문자열을 업체명 · 관리팀 값으로 남기지 않는다.
  /// 인자: entry — 명단 항목
  ///       key — 칸 이름 (`company` · `team`)
  ///       row — 몇 번째 항목인지 (1 부터). 실패 문구에 쓴다
  /// 반환: 앞뒤 공백을 지운 문자열. 없거나 비었으면 null. 문자열도 null 도
  ///       아니면(숫자 · 목록 등) `FormatException`
  static String? _optionalText(
    Map<String, Object?> entry,
    String key,
    int row,
  ) {
    final value = entry[key]; // 칸 값
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('작업자 명단 $row번째 항목의 $key 가 문자열이 아니다: $value');
    }
    final text = value.trim(); // 앞뒤 공백을 지운 값
    return text.isEmpty ? null : text;
  }

  /// 작성: 2026-10-20 09:12:40 · 박건준
  /// 변수: _dubeolsikKeys
  /// 목적: 한글 자판 상태에서 영문 자리를 눌렀을 때 들어오는 낱자 → 그
  ///       자리의 영문. 사번 머리 "T" 를 한글 상태로 누르면 "ㅅ" 이 들어와
  ///       명단에서 못 찾는 일을 막는다.
  /// 근거: 표준 — KS X 5002 두벌식 자판 배열(쌍자음 · ㅒ · ㅖ 는 Shift 자리)
  static const Map<String, String> _dubeolsikKeys = <String, String>{
    'ㄱ': 'r',
    'ㄲ': 'R',
    'ㄴ': 's',
    'ㄷ': 'e',
    'ㄸ': 'E',
    'ㄹ': 'f',
    'ㅁ': 'a',
    'ㅂ': 'q',
    'ㅃ': 'Q',
    'ㅅ': 't',
    'ㅆ': 'T',
    'ㅇ': 'd',
    'ㅈ': 'w',
    'ㅉ': 'W',
    'ㅊ': 'c',
    'ㅋ': 'z',
    'ㅌ': 'x',
    'ㅍ': 'v',
    'ㅎ': 'g',
    'ㅏ': 'k',
    'ㅐ': 'o',
    'ㅑ': 'i',
    'ㅒ': 'O',
    'ㅓ': 'j',
    'ㅔ': 'p',
    'ㅕ': 'u',
    'ㅖ': 'P',
    'ㅗ': 'h',
    'ㅛ': 'y',
    'ㅜ': 'n',
    'ㅠ': 'b',
    'ㅡ': 'm',
    'ㅣ': 'l',
  };

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 수정: 2026-10-20 09:12:40 · 박건준
  /// 함수: normalizeId
  /// 목적: 사번을 대조할 형태로 맞춘다. 명단을 읽을 때와 로그인 입력을 받을
  ///       때 둘 다 이 함수를 쓴다. 현장 휴대폰 키보드에서 생기는 입력
  ///       차이를 같은 사번으로 본다.
  ///       - 대문자로 바꾼다 — "t00001" 도 같은 사람이다
  ///       - 공백(앞뒤 · 가운데, 전각 공백 포함)과 폭 없는 문자를 지운다
  ///       - 전각 영숫자("Ｔ００００１")를 반각으로 바꾼다
  ///       - 한글 자판 상태로 누른 낱자를 그 자리 영문으로 바꾼다
  ///         (`_dubeolsikKeys`, "ㅅ00001" → "T00001")
  ///       명단 사번은 모두 영문 · 숫자라(`tool/import_workers.py` 가 만든
  ///       명단 977명 확인, 2026-10-20) 이 변환으로 두 사람이 같은 사번이
  ///       되는 일은 없다.
  /// 인자: id — 사번 문자열
  /// 반환: 맞춘 사번
  /// 식:   전각 문자 코드 − 0xFEE0 = 반각 문자 코드 (U+FF01 ~ U+FF5E)
  static String normalizeId(String id) {
    final out = StringBuffer(); // 맞춘 글자를 모으는 곳
    for (final rune in id.runes) {
      final half = rune >= 0xFF01 && rune <= 0xFF5E
          ? rune - 0xFEE0
          : rune; // 전각이면 반각으로 바꾼 글자 코드
      final char = String.fromCharCode(half); // 글자 하나
      // 폭 없는 공백 · 이음 문자는 `trim()` 이 공백으로 보지 않아 따로 뺀다
      if (char.trim().isEmpty || (half >= 0x200B && half <= 0x200D)) continue;
      out.write(_dubeolsikKeys[char] ?? char);
    }
    return out.toString().toUpperCase();
  }

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: find
  /// 목적: 사번으로 작업자를 찾는다. 앱을 다시 켤 때 기기에 남은 로그인
  ///       사번을 되살리는 데 쓴다(`LoginStore.restore()`).
  /// 인자: employeeId — 사번. `normalizeId()` 가 맞추는 차이는 가리지 않는다
  /// 반환: 작업자. 명단에 없으면 null
  Worker? find(String employeeId) => _byId[normalizeId(employeeId)];

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 수정: 2026-10-20 09:12:40 · 박건준
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
    final typed = normalizeId(password); // 사번과 같은 규칙으로 맞춘 비밀번호
    if (typed.isEmpty) {
      return const LoginResult.failure(LoginFailure.passwordMissing);
    }
    final worker = _byId[id]; // 명단의 작업자, 없으면 null
    if (worker == null) {
      return const LoginResult.failure(LoginFailure.unknownId);
    }
    if (typed != id) {
      return const LoginResult.failure(LoginFailure.wrongPassword);
    }
    return LoginResult.success(worker);
  }
}
