import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/update_installer.dart';
import 'package:vibration_checker/domain/update/update_info.dart';

/// 작성: 2026-10-13 16:27:48 · nada
/// 변수: _channel
/// 목적: 가짜 응답을 끼울 통로. 이름이 `update_installer.dart` 의
///       `_methodChannel` 과 같아야 한다.
const MethodChannel _channel = MethodChannel(
  'com.otis.vibration_checker/update_method',
);

/// 작성: 2026-10-13 16:27:48 · nada
/// 변수: _info
/// 목적: 받을 버전 정보.
final UpdateInfo _info = UpdateInfo(
  latest: 2,
  latestName: '0.0.1',
  minimum: 1,
  apkUrl: Uri.parse('https://github.com/o/r/releases/download/v/v.apk'),
  sha256: 'ab' * 32,
  notes: '',
);

/// 작성: 2026-10-13 16:27:48 · nada
/// 함수: _answer
/// 목적: 안드로이드 쪽 대신 요청에 답할 함수를 끼운다.
/// 인자: handler — 요청 하나에 답하는 함수
void _answer(Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

/// 작성: 2026-10-13 16:27:48 · nada
/// 함수: main
/// 목적: Dart 쪽 업데이트 통로가 안드로이드 응답을 제대로 옮기는지 본다.
///       내려받기 인자 · 실패 코드, 설치 결과 문자열 → `InstallOutcome`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  test('download 는 주소 · 지문을 넘기고 받은 경로를 돌려준다', () async {
    MethodCall? asked; // 받은 요청
    _answer((call) async {
      asked = call;
      return '/cache/update/vcheck-update.apk';
    });

    final path = await const UpdateInstaller().download(_info); // 받은 경로

    expect(path, '/cache/update/vcheck-update.apk');
    expect(asked!.method, 'download');
    expect(asked!.arguments, {
      'url': _info.apkUrl.toString(),
      'sha256': _info.sha256,
    });
  });

  test('download 실패는 안드로이드 코드를 담은 예외로 올린다', () async {
    _answer((_) async => throw PlatformException(code: 'sha256Mismatch'));

    expect(
      () => const UpdateInstaller().download(_info),
      throwsA(
        isA<UpdateDownloadException>().having(
          (e) => e.code,
          'code',
          'sha256Mismatch',
        ),
      ),
    );
  });

  test('install 결과 문자열을 InstallOutcome 으로 옮긴다', () async {
    final cases = <String, InstallOutcome>{
      'success': InstallOutcome.success,
      'aborted': InstallOutcome.aborted,
      'conflict': InstallOutcome.conflict,
      'failed:-1 INSTALL_FAILED': InstallOutcome.failed,
    }; // 안드로이드 응답 → 기대 결과
    for (final entry in cases.entries) {
      _answer((_) async => entry.key);
      final (outcome, reason) = await const UpdateInstaller().install('/a');
      expect(outcome, entry.value, reason: entry.key);
      if (entry.value == InstallOutcome.failed) {
        expect(reason, '-1 INSTALL_FAILED');
      }
    }
  });

  test('install 요청이 거절되면(측정 중 등) failed 와 사유', () async {
    _answer((_) async => throw PlatformException(code: 'measuring'));

    final (outcome, reason) = await const UpdateInstaller().install('/a');

    expect(outcome, InstallOutcome.failed);
    expect(reason, startsWith('measuring'));
  });
}
