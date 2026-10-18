import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/login_store.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import 'package:vibration_checker/domain/auth/worker_directory.dart';
import 'package:vibration_checker/domain/session/login_session.dart';

import '../support/fake_worker_bundle.dart';

/// 작성: 2026-10-18 09:09:47 · nada
/// 함수: main
/// 목적: 로그인이 기기 저장 값과 지금 작업자를 함께 채우고, 앱을 다시 켜면
///       되살아나며, 로그아웃 · 명단에서 빠진 사번은 둘 다 비우는지 시험한다.
///       앱에 묶인 실제 명단 자산이 읽히는지도 본다(내용은 보지 않는다).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoginStore store; // 시험할 저장소, 시험마다 새로 만든다

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LoginSession.instance.current = null;
    store = LoginStore(bundle: FakeWorkerBundle());
  });

  test('로그인하면 사번을 기기에 남기고 지금 작업자로 싣는다', () async {
    final result = await store.login('t00001', 't00001'); // 판정 결과

    expect(result.worker?.name, '홍길동');
    expect(LoginSession.instance.current?.employeeId, 'T00001');
    expect(await PrefsStore.instance.loadLoginEmployeeId(), 'T00001');
  });

  test('로그인에 실패하면 아무것도 바꾸지 않는다', () async {
    final result = await store.login('T00001', 'T00002'); // 판정 결과

    expect(result.failure, LoginFailure.wrongPassword);
    expect(LoginSession.instance.current, isNull);
    expect(await PrefsStore.instance.loadLoginEmployeeId(), isNull);
  });

  test('앱을 다시 켜면 남은 사번으로 로그인을 되살린다', () async {
    SharedPreferences.setMockInitialValues({'loginEmployeeId': 'T00001'});

    expect(await store.restore(), isTrue);
    expect(LoginSession.instance.current?.name, '홍길동');
  });

  test('명단에서 빠진 사번은 되살리지 않고 지운다', () async {
    SharedPreferences.setMockInitialValues({'loginEmployeeId': 'T09999'});

    expect(await store.restore(), isFalse);
    expect(LoginSession.instance.current, isNull);
    expect(await PrefsStore.instance.loadLoginEmployeeId(), isNull);
  });

  test('로그아웃하면 기기 저장 값과 지금 작업자를 비운다', () async {
    await store.login('T00001', 'T00001');

    await store.logout();

    expect(LoginSession.instance.current, isNull);
    expect(await PrefsStore.instance.loadLoginEmployeeId(), isNull);
  });

  test('앱에 묶인 작업자 명단 자산을 읽을 수 있다', () async {
    // → 로직 이동: LoginStore.directory()
    final directory = await LoginStore().directory(); // 실제 명단
    expect(directory.length, greaterThan(0));
  });
}
