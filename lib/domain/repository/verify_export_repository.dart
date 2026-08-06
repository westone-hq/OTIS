import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class VerifyExportResult {
  const VerifyExportResult({required this.directory, required this.files});

  final Directory directory;
  final List<File> files;
}

typedef VerifyBaseDirectoryProvider = Future<Directory> Function();

/// 검증용 네이티브 임시 txt를 앱 Documents/verify 아래로 옮긴다.
class VerifyExportRepository {
  VerifyExportRepository({VerifyBaseDirectoryProvider? baseDirectoryProvider})
    : _baseDirectoryProvider =
          baseDirectoryProvider ?? getApplicationDocumentsDirectory;

  final VerifyBaseDirectoryProvider _baseDirectoryProvider;

  /// 전체 동시 검증: 기존 8개 + 기본 256/128/64Hz 총 11개를 저장한다.
  Future<VerifyExportResult> exportAll(Map<String, String> nativePaths) async {
    return _copyManyAtomically(
      nativePaths: nativePaths,
      outputs: const [
        ('fastestRaw', 'FASTEST_원본.txt'),
        ('fastest256', 'FASTEST_256Hz.txt'),
        ('handlerRaw', 'HandlerThread_원본.txt'),
        ('handler256', 'HandlerThread_256Hz.txt'),
        ('oneMsRaw', '1ms_원본.txt'),
        ('oneMs256', '1ms_256Hz.txt'),
        ('threeMsRaw', '3ms_원본.txt'),
        ('threeMs256', '3ms_256Hz.txt'),
        ('base256', '기본_FASTEST_256Hz.txt'),
        ('base128', '기본_FASTEST_128Hz.txt'),
        ('base64', '기본_FASTEST_64Hz.txt'),
      ],
    );
  }

  /// 페이지 1: FASTEST 원본과 256Hz 결과 두 개를 함께 저장한다.
  Future<VerifyExportResult> exportFastest(
    Map<String, String> nativePaths,
  ) async {
    return _copyManyAtomically(
      nativePaths: nativePaths,
      outputs: const [
        ('fastestRaw', '3~7_원본.txt'),
        ('fastest256', '3~7_256Hz.txt'),
      ],
    );
  }

  /// 페이지 2: 1ms·3ms의 원본/256Hz 결과 네 개를 함께 저장한다.
  Future<VerifyExportResult> exportFixed(
    Map<String, String> nativePaths,
  ) async {
    return _copyManyAtomically(
      nativePaths: nativePaths,
      outputs: const [
        ('oneMsRaw', '1ms_원본.txt'),
        ('oneMs256', '1ms_256Hz.txt'),
        ('threeMsRaw', '3ms_원본.txt'),
        ('threeMs256', '3ms_256Hz.txt'),
      ],
    );
  }

  Future<Directory> _createSessionDirectory() async {
    final documents = await _baseDirectoryProvider();
    final stamp = DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());
    final separator = Platform.pathSeparator;
    final directory = Directory(
      '${documents.path}${separator}verify$separator$stamp',
    );
    await directory.create(recursive: true);
    return directory;
  }

  /// 모든 원본을 .tmp로 복사한 뒤 전부 성공한 경우에만 최종 이름으로 바꾼다.
  Future<VerifyExportResult> _copyManyAtomically({
    required Map<String, String> nativePaths,
    required List<(String, String)> outputs,
  }) async {
    for (final (key, _) in outputs) {
      final source = nativePaths[key];
      if (source == null || source.isEmpty) {
        throw StateError('$key 검증 출력 경로가 없습니다.');
      }
    }

    final directory = await _createSessionDirectory();
    final separator = Platform.pathSeparator;
    final temporaryFiles = <File>[];
    final finalFiles = <File>[];

    try {
      for (final (key, fileName) in outputs) {
        final temporary = File('${directory.path}$separator$fileName.tmp');
        await File(nativePaths[key]!).copy(temporary.path);
        temporaryFiles.add(temporary);
        finalFiles.add(File('${directory.path}$separator$fileName'));
      }

      for (var i = 0; i < temporaryFiles.length; i++) {
        await temporaryFiles[i].rename(finalFiles[i].path);
      }
      return VerifyExportResult(directory: directory, files: finalFiles);
    } catch (_) {
      for (final file in [...temporaryFiles, ...finalFiles]) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }
}
