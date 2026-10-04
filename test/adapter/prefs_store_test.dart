import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';

/// 작성: 2026-10-04 14:30:00 · nada
/// 함수: main
/// 목적: 기기 저장소에 둔 수신 이메일과 마지막 현장 정보가 저장한 그대로
///       돌아오는지, 깨진 값은 빈 값으로 받는지 시험한다.
void main() {
  final store = PrefsStore.instance; // 시험할 저장소

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('수신 이메일을 저장한 그대로 읽는다', () async {
    expect(await store.loadEmail(), isNull);

    await store.saveEmail('name@otis.com');

    expect(await store.loadEmail(), 'name@otis.com');
  });

  test('마지막 현장 정보를 저장한 그대로 읽는다', () async {
    expect(await store.loadLastSite(), isEmpty);

    await store.saveLastSite({
      'jobNo': '2024F 1447R01',
      'siteName': '현장',
      'bottomFloor': '1',
      'topFloor': '8',
      'direction': '하부 → 상부',
      'model': 'Gen2',
    });

    final loaded = await store.loadLastSite(); // 다시 읽은 현장 정보
    expect(loaded['jobNo'], '2024F 1447R01');
    expect(loaded['topFloor'], '8');
    expect(loaded['direction'], '하부 → 상부');
  });

  test('깨진 현장 정보는 저장된 적 없는 것처럼 빈 표로 읽는다', () async {
    SharedPreferences.setMockInitialValues({'lastSite': '{깨진'});

    expect(await store.loadLastSite(), isEmpty);
  });
}
