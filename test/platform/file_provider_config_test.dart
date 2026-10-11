import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';

/// 작성: 2026-10-11 17:10:57 · nada
/// 변수: _manifestPath
/// 목적: 앱 안드로이드 manifest 경로 (저장소 루트 기준).
const String _manifestPath = 'android/app/src/main/AndroidManifest.xml';

/// 작성: 2026-10-11 17:10:57 · nada
/// 변수: _pathsPath
/// 목적: 플러그인 FileProvider 경로 설정을 덮어쓰는 앱 리소스 경로.
const String _pathsPath = 'android/app/src/main/res/xml/shared_file_paths.xml';

/// 작성: 2026-10-11 17:10:57 · nada
/// 클래스: _TempPathProvider
/// 목적: 앱 임시 폴더 자리를 시험용 임시 폴더로 바꿔 끼운다.
class _TempPathProvider extends PathProviderPlatform {
  /// 임시 폴더 경로
  final String root;

  /// 작성: 2026-10-11 17:10:57 · nada
  /// 함수: _TempPathProvider
  /// 목적: 돌려줄 임시 폴더 경로를 받는다.
  /// 인자: root — 임시 폴더 경로
  _TempPathProvider(this.root);

  /// 작성: 2026-10-11 17:10:57 · nada
  /// 함수: getTemporaryPath
  /// 목적: 앱 임시 폴더 자리에 시험용 임시 폴더를 돌려준다.
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// 작성: 2026-10-11 17:10:57 · nada
/// 함수: _withoutComments
/// 목적: XML 주석을 걷어 낸다. 주석에 적힌 설명 문구가 요소로 잡히지
///       않게 한다.
/// 인자: xml — XML 원문
/// 반환: 주석을 지운 원문
String _withoutComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// 작성: 2026-10-11 17:10:57 · nada
/// 함수: main
/// 목적: 메일 첨부 FileProvider 설정이 2026-10-11 정리한 모양에서 벗어나지
///       않는지 파일 내용으로 확인한다. 누가 앱 manifest 에 같은 authority
///       의 provider 를 다시 넣거나 경로를 넓히면 여기서 잡힌다.
///       - 앱 manifest 에 `.file_provider` authority 의 provider 가 없다.
///         그 authority 는 flutter_email_sender 플러그인이 선언한다
///       - 경로 설정은 `cache-path` `mail/` 하나뿐이다
///       - 그 폴더가 `MeasurementRepository.mailAttachmentCopy()` 가 실제로
///         사본을 만드는 폴더와 같다
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('앱 manifest 에 .file_provider authority 의 provider 가 없다', () {
    final manifest = _withoutComments(File(_manifestPath).readAsStringSync());
    final providers = RegExp(
      r'<provider\b[^>]*>',
      dotAll: true,
    ).allMatches(manifest).map((m) => m.group(0)!); // provider 여는 태그들

    expect(
      providers.where((tag) => tag.contains('.file_provider')),
      isEmpty,
      reason: '플러그인 provider 와 authority 가 겹친다',
    );
  });

  test('경로 설정은 cache-path mail/ 하나뿐이다', () {
    final paths = _withoutComments(File(_pathsPath).readAsStringSync());
    final entries = RegExp(
      r'<([a-z-]+)\s([^>]*?)/>',
    ).allMatches(paths).toList(); // <paths> 안의 경로 항목

    expect(entries, hasLength(1));
    expect(entries.single.group(1), 'cache-path');
    expect(entries.single.group(2), contains('path="mail/"'));
  });

  test('경로 설정의 폴더가 첨부 사본을 만드는 폴더와 같다', () async {
    final temp = await Directory.systemTemp.createTemp('otis_file_provider');
    addTearDown(() => temp.delete(recursive: true));
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
    final source = File('${temp.path}/report.pdf')
      ..writeAsStringSync('%PDF-1.4'); // 측정 폴더 파일 자리

    final copy = await MeasurementRepository.instance.mailAttachmentCopy(
      source,
      'TUNE_J-1_20261011-171057.pdf',
    ); // 메일에 붙일 사본
    final folder = copy.parent.path.substring(temp.path.length + 1); // 임시 폴더 아래

    final declared = RegExp(r'path="([^"]*)/"').firstMatch(
      _withoutComments(File(_pathsPath).readAsStringSync()),
    ); // 경로 설정이 여는 폴더
    expect(folder, declared!.group(1));
  });
}
