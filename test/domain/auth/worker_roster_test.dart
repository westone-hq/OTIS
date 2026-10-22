import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/storage/login_store.dart';
import 'package:vibration_checker/domain/auth/worker_directory.dart';

/// 작성: 2026-10-20 09:12:40 · nada
/// 함수: main
/// 목적: 앱에 묶인 실제 작업자 명단 전원이 로그인되는지 시험한다. 이름 ·
///       사번을 시험 코드에 적지 않고, 실행할 때 자산을 읽어 한 명씩 돈다.
///       - 사번 형식(T + 숫자 5자리, 숫자 6자리)과 겹침 없음
///       - 사번 = 비밀번호로 전원 로그인되고 그 사람이 돌아온다
///       - 소문자 · 공백 · 한글 자판(T → ㅅ) · 전각으로 적어도 로그인된다
///       - 다른 사람 사번을 비밀번호로 넣으면 거절한다
///       - 사번을 한 글자만 바꾸면 명단에 없거나 다른 사람이다(서로
///         헷갈릴 만큼 닮은 사번이 같은 사람으로 묶이지 않는다)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkerDirectory directory; // 앱이 읽는 명단
  late List<Map<String, Object?>> rows; // 자산 JSON 의 줄 그대로

  setUpAll(() async {
    final source = await rootBundle.loadString(LoginStore.directoryAsset);
    rows = ((jsonDecode(source) as Map<String, Object?>)['workers'] as List)
        .cast<Map<String, Object?>>();
    directory = await LoginStore().directory(); // → 로직 이동: directory()
  });

  test('사번 형식이 맞고 겹치지 않으며 명단 줄 수와 같다', () {
    final pattern = RegExp(r'^(T\d{5}|\d{6})$'); // 명단 사번 형식
    final ids = rows.map((r) => r['id'] as String).toList(); // 사번 목록
    expect(ids, everyElement(matches(pattern)));
    expect(ids.toSet().length, ids.length);
    expect(directory.length, rows.length);
    for (final id in ids) {
      expect(WorkerDirectory.normalizeId(id), id, reason: '맞춘 뒤에도 같아야 한다');
    }
  });

  test('전원이 사번 = 비밀번호로 로그인되고 명단의 그 사람이 돌아온다', () {
    for (final row in rows) {
      final id = row['id'] as String; // 사번
      final result = directory.authenticate(id, id); // 판정
      expect(result.failure, isNull, reason: id);
      expect(result.worker?.employeeId, id);
      expect(result.worker?.name, row['name']);
      expect(result.worker?.company, row['company']);
      expect(result.worker?.team, row['team']);
    }
  });

  test('전원이 소문자 · 공백 · 한글 자판 · 전각 입력으로도 로그인된다', () {
    for (final row in rows) {
      final id = row['id'] as String; // 사번
      final fullWidth = String.fromCharCodes(
        id.runes.map((c) => c + 0xFEE0),
      ); // 전각으로 적은 사번
      final typedVariants = <String>[
        ' ${id.toLowerCase()} ',
        '${id.substring(0, 3)} ${id.substring(3)}',
        fullWidth,
        if (id.startsWith('T')) 'ㅅ${id.substring(1)}',
      ]; // 현장에서 들어올 수 있는 모양
      for (final typed in typedVariants) {
        final result = directory.authenticate(typed, typed); // 판정
        expect(result.worker?.employeeId, id, reason: '"$typed"');
      }
    }
  });

  test('다른 사람의 사번을 비밀번호로 넣으면 전원 거절한다', () {
    for (var i = 0; i < rows.length; i++) {
      final id = rows[i]['id'] as String; // 사번
      final other = rows[(i + 1) % rows.length]['id'] as String; // 남의 사번
      expect(
        directory.authenticate(id, other).failure,
        LoginFailure.wrongPassword,
        reason: id,
      );
    }
  });

  test('사번 끝자리를 바꾸면 명단에 없거나 다른 사람이다', () {
    for (final row in rows) {
      final id = row['id'] as String; // 사번
      final last = int.parse(id[id.length - 1]); // 끝자리 숫자
      final changed =
          '${id.substring(0, id.length - 1)}${(last + 1) % 10}'; // 한 자리 바꾼 사번
      final result = directory.authenticate(changed, changed); // 판정
      if (result.worker != null) {
        expect(result.worker!.employeeId, isNot(id));
      } else {
        expect(result.failure, LoginFailure.unknownId);
      }
    }
  });
}
