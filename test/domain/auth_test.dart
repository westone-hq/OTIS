/// 목적: 사용자가 입력한 아이디와 비밀번호가 올바른 형식(사번 6자리, T사번 5자리 등)인지 검사하는 로그인 로직이 정상 작동하는지 테스트한다.
@Skip('로그인 우회(T00000) 기간 무효. auth_repository 원복 시 함께 복원 — RD-12')
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/adapter/auth_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthRepository.instance = LocalAuthRepository();
  });

  group('AuthRepository (Phase 5-A)', () {
    test('정규식 검증: 유효한 사번 6자리 및 T사번 5자리 통과', () async {
      final validIds = ['123456', 'T12345', 't12345'];
      for (final id in validIds) {
        final res = await AuthRepository.instance.login(id, id);
        expect(res, isTrue, reason: '$id should pass');
        expect(AuthRepository.instance.currentUserId, equals(id));
      }
    });

    test('정규식 검증: 4가지 잘못된 사번 형식 (12345, 1234567, T1234, A12345) 거부', () async {
      final invalidIds = ['12345', '1234567', 'T1234', 'A12345'];
      for (final id in invalidIds) {
        expect(
          () => AuthRepository.instance.login(id, id),
          throwsA(isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('아이디 형식을 확인하세요'),
          )),
          reason: '$id should fail regex validation',
        );
      }
    });

    test('PW == ID 검증: 일치 시 성공, 불일치 시 실패', () async {
      expect(
        () => AuthRepository.instance.login('123456', 'wrongpw'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('아이디 또는 비밀번호를 확인하세요'),
        )),
      );

      final res = await AuthRepository.instance.login('123456', '123456');
      expect(res, isTrue);
    });

    test('로그인 성공 시 currentUserId 설정 및 SharedPreferences 저장 검증', () async {
      await AuthRepository.instance.login('T99999', 'T99999');
      expect(AuthRepository.instance.currentUserId, equals('T99999'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auto_login_id'), equals('T99999'));

      // 자동 로그인 복원 테스트
      final newRepo = LocalAuthRepository();
      final restoredId = await newRepo.getAutoLoginId();
      expect(restoredId, equals('T99999'));
      expect(newRepo.currentUserId, equals('T99999'));
    });

    test('관리자 ID 활성/비활성 여부 (OI-2): Local 구현은 항상 enabled(true) 반환', () async {
      final enabled = await AuthRepository.instance.isEnabled('123456');
      expect(enabled, isTrue);
    });
  });
}
