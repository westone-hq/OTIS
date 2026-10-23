import 'package:flutter/services.dart';
import 'package:vibration_checker/domain/update/update_info.dart';

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: InstallOutcome
/// 목적: 설치 화면에 넘긴 결과.
///       - `success` — 설치됐다. 자기 자신을 바꾸는 설치라 이 값이 닿기 전에
///         앱이 끝날 수 있다
///       - `aborted` — 사용자가 설치 확인 화면에서 취소했다
///       - `conflict` — 기존 앱과 충돌한다(서명 키가 다른 APK 등). 기존
///         앱을 지우고 새로 설치해야 한다
///       - `failed` — 그 밖의 실패
enum InstallOutcome { success, aborted, conflict, failed }

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: DownloadProgress
/// 목적: APK 내려받기 진행률 한 건.
class DownloadProgress {
  /// 받은 바이트
  final int received;

  /// 전체 바이트. 서버가 알려 주지 않으면 -1
  final int total;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: DownloadProgress
  /// 목적: 진행률을 담는다.
  /// 인자: received, total — 위 필드
  const DownloadProgress(this.received, this.total);

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: fraction
  /// 목적: 받은 비율(0~1). 전체를 모르면 null — 화면은 비율 없는 진행
  ///       막대를 그린다.
  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: UpdateDownloadException
/// 목적: APK 내려받기 실패. `code` 로 사유를 가른다 — "cancelled"(사용자
///       취소) · "sha256Mismatch"(받은 파일 지문이 다름) · "network"(받기
///       실패) · "measuring" · "busy" · "badArgs".
class UpdateDownloadException implements Exception {
  /// 실패 사유 코드 (`UpdateInstaller.kt` 의 `download` 응답)
  final String code;

  /// 덧붙인 설명. 없으면 null
  final String? message;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: UpdateDownloadException
  /// 목적: 실패 사유를 담는다.
  /// 인자: code, message — 위 필드
  const UpdateDownloadException(this.code, [this.message]);

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: toString
  /// 목적: 기록에 남길 한 줄.
  @override
  String toString() => 'UpdateDownloadException($code: $message)';
}

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: UpdateInstaller
/// 목적: 안드로이드 쪽 업데이트 담당(`UpdateInstaller.kt`)과 통하는 통로.
///       설치 허용 확인 · 설정 화면 열기, APK 내려받기(진행률 · 취소),
///       설치를 요청한다. 화면(update_prompt.dart)이 이 순서로 부른다.
class UpdateInstaller {
  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: UpdateInstaller
  /// 목적: 통로 객체를 만든다. 채널은 앱 전체에 하나라 상태가 없다.
  const UpdateInstaller();

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 변수: _methodChannel
  /// 목적: 요청 하나 · 응답 하나 통로. 이름이 `UpdateInstaller.kt` 의
  ///       `METHOD_CHANNEL` 과 반드시 같아야 한다.
  static const MethodChannel _methodChannel = MethodChannel(
    'com.otis.vibration_checker/update_method',
  );

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 변수: _progressChannel
  /// 목적: 진행률 통로. 이름이 `UpdateInstaller.kt` 의 `PROGRESS_CHANNEL`
  ///       과 반드시 같아야 한다.
  static const EventChannel _progressChannel = EventChannel(
    'com.otis.vibration_checker/update_progress',
  );

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: canInstall
  /// 목적: 이 앱에 APK 설치가 허용됐는지 묻는다.
  /// 반환: 허용됐으면 true
  Future<bool> canInstall() async =>
      // → 로직 이동: UpdateInstaller.canInstall
      await _methodChannel.invokeMethod<bool>('canInstall') ?? false;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: openInstallSettings
  /// 목적: 이 앱의 "설치 허용" 설정 화면을 열고, 사용자가 돌아오면 다시
  ///       확인한 결과를 받는다.
  /// 반환: 돌아온 뒤 허용됐으면 true
  Future<bool> openInstallSettings() async =>
      // → 로직 이동: UpdateInstaller.openInstallSettings
      await _methodChannel.invokeMethod<bool>('openInstallSettings') ?? false;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: progress
  /// 목적: 내려받기 진행률을 흘려 받는다. 받는 동안만 값이 온다.
  /// 반환: 진행률 흐름
  Stream<DownloadProgress> progress() =>
      // → 로직 이동: UpdateInstaller.onListen()
      _progressChannel.receiveBroadcastStream().map((event) {
        final map = event as Map<Object?, Object?>; // 진행률 한 건
        return DownloadProgress(map['received'] as int, map['total'] as int);
      });

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: download
  /// 목적: 버전 정보의 APK 를 내려받고 SHA-256 을 맞춰 본다.
  /// 인자: info — 받을 버전 정보
  /// 반환: 받은 파일 경로
  ///       실패면 `UpdateDownloadException` 을 던진다
  Future<String> download(UpdateInfo info) async {
    try {
      // → 로직 이동: UpdateInstaller.download
      final path = await _methodChannel.invokeMethod<String>('download', {
        'url': info.apkUrl.toString(),
        'sha256': info.sha256,
      }); // 받은 파일 경로
      if (path == null) {
        throw const UpdateDownloadException('network', '경로 없음');
      }
      return path;
    } on PlatformException catch (e) {
      throw UpdateDownloadException(e.code, e.message);
    }
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: cancelDownload
  /// 목적: 받는 중인 내려받기를 멈춘다. `download()` 는 "cancelled" 로
  ///       끝난다.
  Future<void> cancelDownload() =>
      // → 로직 이동: UpdateInstaller.cancelDownload
      _methodChannel.invokeMethod<void>('cancelDownload');

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: install
  /// 목적: 받은 APK 를 안드로이드 설치 화면으로 넘기고 결과를 받는다.
  /// 인자: path — `download()` 가 돌려준 경로
  /// 반환: (결과, 실패 사유). 사유는 `failed` 일 때만 있다
  Future<(InstallOutcome, String?)> install(String path) async {
    final String raw; // 안드로이드 쪽 결과 문자열
    try {
      // → 로직 이동: UpdateInstaller.install
      raw =
          await _methodChannel.invokeMethod<String>('install', {
            'path': path,
          }) ??
          'failed:응답 없음';
    } on PlatformException catch (e) {
      return (InstallOutcome.failed, '${e.code}: ${e.message}');
    }
    return switch (raw) {
      'success' => (InstallOutcome.success, null),
      'aborted' => (InstallOutcome.aborted, null),
      'conflict' => (InstallOutcome.conflict, null),
      _ => (InstallOutcome.failed, raw.replaceFirst('failed:', '')),
    };
  }
}
