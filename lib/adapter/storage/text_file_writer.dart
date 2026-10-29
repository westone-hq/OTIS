import 'dart:io';

import 'package:vibration_checker/adapter/storage/storage_file_access.dart';

/// 작성: 2026-10-29 16:06:38 · Codex
/// 수정: 2026-10-29 16:15:04 · Codex
/// 클래스: TextFileWriter
/// 목적: 텍스트 파일을 열어 한 번 기록하고 닫는다. Windows에서 다른
///       프로세스가 잠깐 파일을 잡은 경우에는 열기만 다시 시도한다.
///       쓰기를 시작한 뒤의 실패는 재시도하지 않아 덧붙인 줄이 겹치지 않는다.
class TextFileWriter {
  /// 작성: 2026-10-29 16:06:38 · Codex
  /// 함수: TextFileWriter._
  /// 목적: 상태 없는 파일 기록 함수만 제공한다.
  TextFileWriter._();

  /// 작성: 2026-10-29 16:06:38 · Codex
  /// 수정: 2026-10-29 16:15:04 · Codex
  /// 함수: write
  /// 목적: 파일을 열어 UTF-8 문자열을 기록하고 성공·실패 모두 핸들을 닫는다.
  ///       Android 등에서는 기존처럼 열기를 한 번만 시도한다.
  /// 인자: file — 기록할 파일
  ///       text — 기록할 내용. 줄바꿈은 호출자가 정한 대로 유지한다
  ///       mode — 덮어쓰기 또는 덧붙이기
  /// 반환: 기록한 파일. 잠금이 계속되거나 다른 오류면 예외를 그대로 올린다
  static Future<File> write(
    File file,
    String text, {
    FileMode mode = FileMode.write,
  }) async {
    // → 로직 이동: StorageFileAccess.retry()
    final handle = await StorageFileAccess.retry(
      () => file.open(mode: mode),
    ); // 열기에 성공한 핸들
    try {
      await handle.writeString(text);
    } finally {
      await handle.close();
    }
    return file;
  }
}
