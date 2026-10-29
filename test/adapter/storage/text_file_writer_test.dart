import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/storage/storage_file_access.dart';
import 'package:vibration_checker/adapter/storage/text_file_writer.dart';

/// 작성: 2026-10-29 16:06:38 · Codex
/// 클래스: _OpeningFile
/// 목적: 지정한 오류로 파일 열기를 실패시킨 뒤 실제 파일이나 시험 핸들을
///       돌려준다. 기록 내용과 재시도 범위를 함께 검사한다.
class _OpeningFile extends Fake implements File {
  /// 실제 기록 파일
  final File target;

  /// 열 때 순서대로 발생시킬 운영체제 오류 번호
  final List<int> errors;

  /// 실제 파일 대신 반환할 핸들. 쓰기 실패 검사에서만 쓴다
  final RandomAccessFile? handle;

  /// 파일을 열려고 시도한 횟수
  int calls = 0;

  /// 작성: 2026-10-29 16:06:38 · Codex
  /// 함수: _OpeningFile
  /// 목적: 열기 오류와 실제 기록 파일을 받는다.
  /// 인자: target — 실제 파일, errors — 오류 번호 순서, handle — 시험 핸들
  _OpeningFile(this.target, this.errors, {this.handle});

  /// 작성: 2026-10-29 16:06:38 · Codex
  /// 함수: open
  /// 목적: 정해 둔 실패를 먼저 내고 이후 실제 핸들을 반환한다.
  /// 인자: mode — 파일 열기 방식
  /// 반환: 열린 파일 핸들
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    final index = calls++; // 이번 열기 시도 번호
    if (index < errors.length) {
      throw FileSystemException(
        '시험 열기 실패',
        target.path,
        OSError('시험 운영체제 오류', errors[index]),
      );
    }
    return handle ?? await target.open(mode: mode);
  }
}

/// 작성: 2026-10-29 16:06:38 · Codex
/// 클래스: _FailingWriteHandle
/// 목적: 파일을 연 뒤 쓰기에서 오류가 나도 내용을 재시도하지 않고 핸들을
///       닫는지 확인한다.
class _FailingWriteHandle extends Fake implements RandomAccessFile {
  /// 실제 쓰기를 시도한 횟수
  int writes = 0;

  /// 핸들을 닫은 횟수
  int closes = 0;

  /// 작성: 2026-10-29 16:06:38 · Codex
  /// 함수: writeString
  /// 목적: 열기가 아닌 쓰기 오류를 발생시킨다.
  /// 인자: string — 기록할 문자열, encoding — 문자 인코딩
  /// 반환: 실패 Future
  @override
  Future<RandomAccessFile> writeString(
    String string, {
    Encoding encoding = utf8,
  }) async {
    writes++;
    throw const FileSystemException('시험 쓰기 실패', '', OSError('공유 위반', 32));
  }

  /// 작성: 2026-10-29 16:06:38 · Codex
  /// 함수: close
  /// 목적: 오류 때도 핸들을 닫는지 센다.
  /// 반환: 닫은 핸들
  @override
  Future<RandomAccessFile> close() async {
    closes++;
    return this;
  }
}

/// 작성: 2026-10-29 16:06:38 · Codex
/// 수정: 2026-10-29 16:15:04 · Codex
/// 함수: main
/// 목적: 공유 위반만 제한적으로 재시도하고 한글·줄바꿈·덧붙이기를 유지하는지
///       검사한다. 쓰기 중 실패를 재생해 같은 줄을 두 번 쓰지 않는다.
void main() {
  late Directory temporary; // 이번 시험의 임시 폴더
  late File target; // 실제 텍스트 기록 파일

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('otis_text_writer_');
    target = File('${temporary.path}/meta.txt');
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test('한글과 CRLF를 유지하고 덮어쓰기와 덧붙이기를 구분한다', () async {
    await TextFileWriter.write(target, '이전 내용');
    await TextFileWriter.write(target, '집계\r\n');
    await TextFileWriter.write(target, '소음\r\n', mode: FileMode.append);
    expect(await target.readAsString(), '집계\r\n소음\r\n');
  });

  test('권한 오류는 즉시 전달한다', () async {
    final file = _OpeningFile(target, [5]); // 권한 거부
    await expectLater(
      TextFileWriter.write(file, '집계'),
      throwsA(isA<FileSystemException>()),
    );
    expect(file.calls, 1);
  });

  test('쓰기 중 공유 위반은 재시도하지 않고 핸들을 닫는다', () async {
    final handle = _FailingWriteHandle(); // 쓰기 실패 핸들
    final file = _OpeningFile(target, [], handle: handle); // 열기는 성공
    await expectLater(
      TextFileWriter.write(file, '집계', mode: FileMode.append),
      throwsA(isA<FileSystemException>()),
    );
    expect(file.calls, 1);
    expect(handle.writes, 1);
    expect(handle.closes, 1);
  });

  test('Windows 공유 위반 뒤 열기에 성공하면 내용은 한 번만 덧붙인다', () async {
    await TextFileWriter.write(target, '처음\r\n');
    final file = _OpeningFile(target, [32, 32]); // 두 번 실패 뒤 성공
    await TextFileWriter.write(file, '추가\r\n', mode: FileMode.append);
    expect(file.calls, 3);
    expect(await target.readAsString(), '처음\r\n추가\r\n');
  }, skip: !Platform.isWindows);

  test('Windows 공유 위반이 계속되면 횟수를 제한하고 실패를 전달한다', () async {
    final file = _OpeningFile(target, List.filled(20, 32)); // 계속 잠긴 파일
    await expectLater(
      TextFileWriter.write(file, '집계'),
      throwsA(isA<FileSystemException>()),
    );
    expect(file.calls, 6);
    expect(await target.exists(), isFalse);
  }, skip: !Platform.isWindows);

  test('Windows 공유 위반으로 막힌 폴더 삭제도 같은 경로로 다시 시도한다', () async {
    final directory = Directory('${temporary.path}/capture'); // 지울 폴더
    await directory.create();
    await TextFileWriter.write(File('${directory.path}/meta.txt'), '집계');
    var attempts = 0; // 삭제 시도 횟수
    await StorageFileAccess.retry(() async {
      attempts++;
      if (attempts < 3) {
        throw FileSystemException(
          '시험 공유 위반',
          directory.path,
          const OSError('공유 위반', 32),
        );
      }
      return directory.delete(recursive: true);
    });
    expect(attempts, 3);
    expect(await directory.exists(), isFalse);
  }, skip: !Platform.isWindows);

  test('Windows가 아니면 같은 번호의 오류도 재시도하지 않는다', () async {
    final file = _OpeningFile(target, [32]); // 다른 운영체제의 오류
    await expectLater(
      TextFileWriter.write(file, '집계'),
      throwsA(isA<FileSystemException>()),
    );
    expect(file.calls, 1);
  }, skip: Platform.isWindows);
}
