import 'dart:io';

/// 작성: 2026-10-29 16:15:04 · Codex
/// 클래스: StorageFileAccess
/// 목적: 파일 열기와 폴더 삭제에서 Windows의 일시적인 공유 위반만 제한적으로
///       재시도한다. 이미 시작한 내용 쓰기에는 적용하지 않는다.
class StorageFileAccess {
  /// 작성: 2026-10-29 16:15:04 · Codex
  /// 함수: StorageFileAccess._
  /// 목적: 상태 없는 파일 접근 정책만 제공한다.
  StorageFileAccess._();

  /// 작성: 2026-10-29 16:15:04 · Codex
  /// 변수: _retryDelays
  /// 목적: 공유 위반이 계속되면 최대 310ms 뒤 원래 예외를 전달한다.
  /// 근거: 측정 — 2026-10-29 Windows에서 새 집계 파일 기록 100건 중
  ///       16건에 오류 32가 재현되었고, 폴더 삭제에서도 같은 오류가 발생했다.
  static const _retryDelays = <Duration>[
    Duration(milliseconds: 10),
    Duration(milliseconds: 20),
    Duration(milliseconds: 40),
    Duration(milliseconds: 80),
    Duration(milliseconds: 160),
  ];

  /// 작성: 2026-10-29 16:15:04 · Codex
  /// 함수: retry
  /// 목적: Windows 공유 위반(32)으로 실패한 접근만 다시 시도한다. 다른 오류는
  ///       즉시 전달한다. 내용 덧붙이기처럼 반복하면 중복되는 작업은 받지 않는다.
  /// 인자: operation — 파일 열기 또는 같은 폴더 삭제처럼 반복 가능한 접근
  /// 반환: 성공한 접근의 결과. 끝내 실패하면 마지막 예외를 그대로 올린다
  static Future<T> retry<T>(Future<T> Function() operation) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await operation();
      } on FileSystemException catch (error) {
        if (!Platform.isWindows ||
            error.osError?.errorCode != 32 ||
            attempt >= _retryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(_retryDelays[attempt]);
      }
    }
  }
}
