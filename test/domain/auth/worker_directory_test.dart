import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/auth/worker_directory.dart';

/// 작성: 2026-10-18 09:09:47 · nada
/// 함수: _json
/// 목적: `tool/import_workers.py` 가 만드는 형태의 명단 JSON 을 만든다.
/// 인자: workers — 명단 항목 목록
/// 반환: 명단 JSON 문자열
String _json(List<Map<String, Object?>> workers) =>
    jsonEncode({'source': 'test.xlsx', 'workers': workers});

/// 작성: 2026-10-18 09:09:47 · nada
/// 함수: main
/// 목적: 명단을 읽고, 사번 대소문자를 가리지 않고 찾으며, 비밀번호 = 사번
///       규칙으로 로그인을 판정하는지 시험한다. 깨진 명단은 건너뛰지 않고
///       실패로 올리는지도 본다.
void main() {
  final directory = WorkerDirectory.parse(
    _json([
      {'id': 'T00001', 'name': '홍길동', 'company': '(주)시험승강기', 'team': '설치1팀'},
      {'id': 200001, 'name': '김철수', 'company': null, 'team': ' '},
    ]),
  ); // 시험용 명단

  test('명단을 읽고 빈 업체 · 팀은 null 로 둔다', () {
    expect(directory.length, 2);
    final hong = directory.find('T00001')!; // 업체 · 팀이 있는 작업자
    expect(hong.name, '홍길동');
    expect(hong.company, '(주)시험승강기');
    expect(hong.team, '설치1팀');
    final kim = directory.find('200001')!; // 숫자 사번 · 업체 없는 작업자
    expect(kim.employeeId, '200001');
    expect(kim.company, isNull);
    expect(kim.team, isNull);
  });

  test('사번은 앞뒤 공백 · 대소문자를 가리지 않고 찾는다', () {
    expect(directory.find(' t00001 ')?.name, '홍길동');
    expect(directory.find('T99999'), isNull);
  });

  test('한글 자판 · 전각 · 가운데 공백 · 폭 없는 문자는 같은 사번으로 맞춘다', () {
    expect(WorkerDirectory.normalizeId('ㅅ00001'), 'T00001');
    expect(WorkerDirectory.normalizeId('ㅆ00001'), 'T00001');
    expect(WorkerDirectory.normalizeId('Ｔ００００１'), 'T00001');
    expect(WorkerDirectory.normalizeId('T 000　01'), 'T00001');
    expect(WorkerDirectory.normalizeId('​T00001 \n'), 'T00001');
    expect(WorkerDirectory.normalizeId('２０００01'), '200001');
    expect(directory.authenticate('ㅅ00001', 'ㅅ00001').worker?.name, '홍길동');
  });

  test('공백 · 폭 없는 문자만 있는 칸은 빈 칸으로 본다', () {
    expect(
      directory.authenticate(' ​ ', 'T00001').failure,
      LoginFailure.idMissing,
    );
    expect(
      directory.authenticate('T00001', '　').failure,
      LoginFailure.passwordMissing,
    );
  });

  test('비밀번호가 사번과 같으면 로그인을 받아 준다', () {
    final result = directory.authenticate('t00001', 'T00001 '); // 판정 결과
    expect(result.failure, isNull);
    expect(result.worker?.name, '홍길동');
  });

  test('실패 사유를 종류별로 가른다', () {
    expect(directory.authenticate(' ', 'x').failure, LoginFailure.idMissing);
    expect(
      directory.authenticate('T00001', ' ').failure,
      LoginFailure.passwordMissing,
    );
    expect(
      directory.authenticate('T99999', 'T99999').failure,
      LoginFailure.unknownId,
    );
    expect(
      directory.authenticate('T00001', '200001').failure,
      LoginFailure.wrongPassword,
    );
  });

  test('사번이 겹치거나 성명이 빈 명단은 실패로 올린다', () {
    expect(
      () => WorkerDirectory.parse(
        _json([
          {'id': 'T00001', 'name': '홍길동'},
          {'id': 't00001', 'name': '김철수'},
        ]),
      ),
      throwsFormatException,
    );
    expect(
      () => WorkerDirectory.parse(
        _json([
          {'id': 'T00001', 'name': ' '},
        ]),
      ),
      throwsFormatException,
    );
    expect(() => WorkerDirectory.parse('[]'), throwsFormatException);
  });
}
