import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vibration_checker/adapter/storage/login_store.dart';

/// 작성: 2026-10-18 09:41:12 · nada
/// 변수: testWorkersJson
/// 목적: 시험용 작업자 명단. 실제 명단(실명)을 시험에 쓰지 않으려고 둔다.
///       업체 · 팀이 있는 사람과, OTIS 직원처럼 둘 다 빈 사람을 하나씩 둔다.
final String testWorkersJson = jsonEncode({
  'source': 'test.xlsx',
  'workers': [
    {'id': 'T00001', 'name': '홍길동', 'company': '(주)시험승강기', 'team': '설치1팀'},
    {'id': '200001', 'name': '김철수', 'company': null, 'team': null},
  ],
});

/// 작성: 2026-10-18 09:41:12 · nada
/// 클래스: FakeWorkerBundle
/// 목적: 명단 자산 자리에 시험용 명단을 돌려주는 자산 통로.
///       `LoginStore(bundle: FakeWorkerBundle())` 로 끼운다.
class FakeWorkerBundle extends CachingAssetBundle {
  /// 작성: 2026-10-18 09:41:12 · nada
  /// 함수: FakeWorkerBundle
  /// 목적: 돌려줄 명단 JSON 을 받는다.
  /// 인자: json — 명단 JSON 문자열. 안 주면 `testWorkersJson`
  FakeWorkerBundle([String? json]) : json = json ?? testWorkersJson;

  /// 명단 자산 자리에 돌려줄 JSON 문자열
  final String json;

  /// 작성: 2026-10-18 09:41:12 · nada
  /// 함수: load
  /// 목적: 명단 자산을 요청하면 시험용 JSON 을, 그 밖에는 실패를 돌려준다.
  /// 인자: key — 자산 경로
  /// 반환: 자산 바이트
  @override
  Future<ByteData> load(String key) async {
    if (key != LoginStore.directoryAsset) throw StateError('없는 자산: $key');
    return ByteData.sublistView(utf8.encode(json));
  }
}
