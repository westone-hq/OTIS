import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/repository/verify_export_repository.dart';

void main() {
  late Directory temporaryDirectory;
  late VerifyExportRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('otis_verify_');
    repository = VerifyExportRepository(
      baseDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('전체 검증은 기존 8개와 기본 다중 주파수 3개를 함께 저장한다', () async {
    final keys = [
      'fastestRaw',
      'fastest256',
      'handlerRaw',
      'handler256',
      'oneMsRaw',
      'oneMs256',
      'threeMsRaw',
      'threeMs256',
      'base256',
      'base128',
      'base64',
    ];
    final sources = <String, String>{};
    for (final key in keys) {
      final source = File('${temporaryDirectory.path}/$key.txt');
      await source.writeAsString(key);
      sources[key] = source.path;
    }

    final result = await repository.exportAll(sources);

    expect(result.files, hasLength(11));
    expect(result.files.map((file) => file.path), [
      endsWith('FASTEST_원본.txt'),
      endsWith('FASTEST_256Hz.txt'),
      endsWith('HandlerThread_원본.txt'),
      endsWith('HandlerThread_256Hz.txt'),
      endsWith('1ms_원본.txt'),
      endsWith('1ms_256Hz.txt'),
      endsWith('3ms_원본.txt'),
      endsWith('3ms_256Hz.txt'),
      endsWith('기본_FASTEST_256Hz.txt'),
      endsWith('기본_FASTEST_128Hz.txt'),
      endsWith('기본_FASTEST_64Hz.txt'),
    ]);
  });

  test('FASTEST 출력은 원본과 256Hz 두 파일로 저장된다', () async {
    final raw = File('${temporaryDirectory.path}/fastest-raw.txt');
    final hz256 = File('${temporaryDirectory.path}/fastest-256.txt');
    await raw.writeAsString('raw');
    await hz256.writeAsString('256');

    final result = await repository.exportFastest({
      'fastestRaw': raw.path,
      'fastest256': hz256.path,
    });

    expect(result.files.map((file) => file.path), [
      endsWith('3~7_원본.txt'),
      endsWith('3~7_256Hz.txt'),
    ]);
  });

  test('fixed 출력은 1ms와 3ms 원본·256Hz 네 파일을 저장한다', () async {
    final sources = <String, String>{};
    for (final key in ['oneMsRaw', 'oneMs256', 'threeMsRaw', 'threeMs256']) {
      final source = File('${temporaryDirectory.path}/$key.txt');
      await source.writeAsString(key);
      sources[key] = source.path;
    }

    final result = await repository.exportFixed(sources);

    expect(result.files.map((file) => file.path), [
      endsWith('1ms_원본.txt'),
      endsWith('1ms_256Hz.txt'),
      endsWith('3ms_원본.txt'),
      endsWith('3ms_256Hz.txt'),
    ]);
    expect(
      result.directory.listSync().whereType<File>().map((file) => file.path),
      isNot(contains(endsWith('.tmp'))),
    );
  });

  test('fixed 출력은 네 경로 중 하나가 없으면 어떤 파일도 만들지 않는다', () async {
    final oneSource = File('${temporaryDirectory.path}/one-native.txt');
    await oneSource.writeAsString('one');

    expect(
      () => repository.exportFixed({'oneMsRaw': oneSource.path}),
      throwsStateError,
    );

    final verifyDirectory = Directory('${temporaryDirectory.path}/verify');
    expect(await verifyDirectory.exists(), isFalse);
  });
}
