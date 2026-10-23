import 'package:flutter/services.dart';
import 'package:vibration_checker/adapter/storage/prefs_store.dart';
import 'package:vibration_checker/domain/auth/login_session.dart';
import 'package:vibration_checker/domain/auth/worker_directory.dart';

/// 작성: 2026-10-18 09:09:47 · 박건준
/// 클래스: LoginStore
/// 목적: 로그인 · 로그아웃 · 앱을 켤 때 로그인 되살리기를 한 곳에 둔다.
///       앱 자산의 작업자 명단(`WorkerDirectory`)을 읽고, 로그인 사번을
///       기기(`PrefsStore`)에 남기며, 지금 작업자를 `LoginSession` 에
///       싣는다. 세 곳을 함께 고쳐 서로 어긋나지 않게 한다.
class LoginStore {
  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 변수: instance
  /// 목적: 앱 전역에서 공유하는 단일 로그인 저장소. 앱 자산을 읽는 기본
  ///       통로(`rootBundle`)를 쓴다.
  static final LoginStore instance = LoginStore();

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 변수: directoryAsset
  /// 목적: 작업자 명단 자산 경로. `tool/import_workers.py` 가 OTIS 명단
  ///       엑셀에서 만든다.
  static const String directoryAsset = 'assets/workers/workers.json';

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: LoginStore
  /// 목적: 로그인 저장소를 만든다.
  /// 인자: bundle — 명단 자산을 읽을 통로. 안 주면 앱에 묶인 자산
  ///       (`rootBundle`)을 읽는다. 시험은 가짜 명단을 넣은 통로를 준다
  LoginStore({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// 명단 자산을 읽는 통로
  final AssetBundle _bundle;

  /// 읽어 둔 작업자 명단. `directory()` 가 처음 부를 때 채운다. 읽기 전이면
  /// null
  WorkerDirectory? _directory;

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: directory
  /// 목적: 작업자 명단을 읽는다. 앱이 켜져 있는 동안 명단은 바뀌지 않으므로
  ///       처음 한 번만 읽어 둔다.
  /// 반환: 작업자 명단. 자산이 없거나 형식이 틀리면 예외를 그대로 올린다
  ///       — 명단 없이는 아무도 로그인하지 못하므로 숨기지 않는다
  Future<WorkerDirectory> directory() async {
    final cached = _directory; // 읽어 둔 명단, 없으면 null
    if (cached != null) return cached;
    // → 로직 이동: WorkerDirectory.parse()
    final parsed = WorkerDirectory.parse(
      await _bundle.loadString(directoryAsset),
    ); // 읽어 낸 명단
    _directory = parsed;
    return parsed;
  }

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: restore
  /// 목적: 앱을 켤 때 기기에 남은 로그인 사번을 명단에서 찾아 로그인 상태를
  ///       되살린다. 새 명단에서 빠진 사번이면 로그아웃으로 돌린다 — 명단에
  ///       없는 사람 이름이 리포트에 계속 찍히지 않게 한다.
  /// 반환: 되살렸는지. 남은 사번이 없거나 명단에 없으면 false
  Future<bool> restore() async {
    // → 로직 이동: PrefsStore.loadLoginEmployeeId()
    final savedId = await PrefsStore.instance
        .loadLoginEmployeeId(); // 남은 로그인 사번, 없으면 null
    if (savedId == null) return false;
    final dir = await directory(); // → 로직 이동: directory()
    final worker = dir.find(savedId); // → 로직 이동: WorkerDirectory.find()
    if (worker == null) {
      await logout(); // → 로직 이동: logout()
      return false;
    }
    LoginSession.instance.current = worker;
    return true;
  }

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: login
  /// 목적: 사번 · 비밀번호로 로그인한다. 받아 주면 사번을 기기에 남기고
  ///       지금 작업자로 싣는다.
  /// 인자: employeeId — 입력한 사번
  ///       password — 입력한 비밀번호
  /// 반환: 판정 결과. 실패면 기기 저장 값과 지금 작업자를 건드리지 않는다
  Future<LoginResult> login(String employeeId, String password) async {
    final dir = await directory(); // → 로직 이동: directory()
    // → 로직 이동: WorkerDirectory.authenticate()
    final result = dir.authenticate(employeeId, password); // 판정 결과
    final worker = result.worker; // 로그인한 작업자, 실패면 null
    if (worker == null) return result;
    // → 로직 이동: PrefsStore.saveLoginEmployeeId()
    await PrefsStore.instance.saveLoginEmployeeId(worker.employeeId);
    LoginSession.instance.current = worker;
    return result;
  }

  /// 작성: 2026-10-18 09:09:47 · 박건준
  /// 함수: logout
  /// 목적: 로그아웃한다. 기기의 로그인 사번을 지우고 지금 작업자를 비운다.
  ///       이미 저장한 측정 결과의 작업자 정보는 그대로 둔다.
  Future<void> logout() async {
    // → 로직 이동: PrefsStore.saveLoginEmployeeId()
    await PrefsStore.instance.saveLoginEmployeeId(null);
    LoginSession.instance.current = null;
  }
}
