import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration_checker/adapter/update/update_checker.dart';
import 'package:vibration_checker/adapter/update/update_installer.dart';
import 'package:vibration_checker/domain/update/update_decision.dart';
import 'package:vibration_checker/domain/update/update_info.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/core/widgets/app_dialog.dart';
import 'package:vibration_checker/ui/core/widgets/app_snack_bar.dart';

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: UpdatePrompt
/// 목적: 앱 안 업데이트 안내의 화면 흐름. 확인(`UpdateChecker`)과 설치
///       (`UpdateInstaller`) 결과를 받아 창과 문구만 고른다.
///       - 앱 시작 때 한 번: 홈 화면이 `checkAtLaunch()` 를 부른다
///       - 수동 확인: 설정 화면 "업데이트 확인" 이 `checkManually()` 를
///         부른다
///       측정 · 결과 화면에서는 부르지 않는다. 확인이 끝났을 때 홈 화면이
///       맨 위가 아니면(측정을 시작했으면) 창을 띄우지 않는다.
class UpdatePrompt {
  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: UpdatePrompt
  /// 목적: 흐름 객체를 만든다. 시험이 바꿔 끼울 확인기 · 설치기만 받는다.
  /// 인자: checker — 업데이트 확인기. 안 주면 새로 만든다
  ///       installer — 내려받기 · 설치 통로. 안 주면 안드로이드 통로
  UpdatePrompt({UpdateChecker? checker, UpdateInstaller? installer})
    : _checker = checker ?? UpdateChecker(),
      _installer = installer ?? const UpdateInstaller();

  /// 업데이트 확인기
  final UpdateChecker _checker;

  /// 내려받기 · 설치 통로
  final UpdateInstaller _installer;

  /// 이번 앱 실행에서 시작 확인을 이미 했는지. 홈 화면이 다시 만들어져도
  /// 한 번만 확인하려고 실행 전체에 하나만 둔다. 앱을 다시 켜면 false
  static bool _launchChecked = false;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: checkAtLaunch
  /// 목적: 앱 시작 때 한 번 업데이트를 확인하고, 있으면 안내한다. 확인하지
  ///       못하면(인터넷 없음 등) 아무것도 띄우지 않는다. 확인하는 동안
  ///       사용자가 측정으로 넘어갔으면 창을 띄우지 않는다.
  /// 인자: context — 홈 화면의 위치 정보
  Future<void> checkAtLaunch(BuildContext context) async {
    if (_launchChecked) return;
    _launchChecked = true;
    final check = await _checker.check(); // → 로직 이동: UpdateChecker.check()
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    await offer(context, check); // → 로직 이동: offer()
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: checkManually
  /// 목적: 설정 화면에서 누른 확인. "나중에" 기록을 보지 않고 확인해,
  ///       새 버전이 있으면 안내하고 없으면 "최신 버전입니다", 확인하지
  ///       못했으면 그 갈래(인터넷 · 서버 · 형식)에 맞춰 알린다.
  /// 인자: context — 설정 화면의 위치 정보
  Future<void> checkManually(BuildContext context) async {
    // → 로직 이동: UpdateChecker.check()
    final check = await _checker.check(manual: true);
    if (!context.mounted) return;
    final failure = check.failure; // 확인하지 못한 갈래, 확인했으면 null
    if (failure != null) {
      final message = switch (failure) {
        UpdateCheckFailure.network => '업데이트를 확인하지 못했습니다. 인터넷 연결을 확인하세요.',
        UpdateCheckFailure.server => '업데이트 서버에서 버전 정보를 찾지 못했습니다.',
        UpdateCheckFailure.invalid => '업데이트 정보를 읽지 못했습니다.',
      }; // 갈래마다 다른 안내
      showErrorSnackBar(context, message);
      return;
    }
    if (check.decision == UpdateDecision.none) {
      showSuccessSnackBar(context, '최신 버전입니다');
      return;
    }
    await offer(context, check); // → 로직 이동: offer()
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: offer
  /// 목적: 확인 결과에 맞는 창을 띄우고 업데이트를 진행한다.
  ///       - `none` 이면 아무것도 하지 않는다
  ///       - `optional` 은 "업데이트" / "나중에". "나중에" 는 기록해 같은
  ///         번호를 하루 동안 다시 묻지 않는다. 중간에 실패 · 취소하면
  ///         그대로 앱을 쓴다
  ///       - `required` 는 뒤로가기 · 바깥 누르기로 닫히지 않고 버튼은
  ///         "업데이트" 하나다. 설치가 끝나지 않으면(실패 · 취소) 창을 다시
  ///         띄운다 — 이 빌드는 쓸 수 없기 때문이다
  /// 인자: context — 창을 띄울 화면의 위치 정보
  ///       check — 확인 결과
  Future<void> offer(BuildContext context, UpdateCheck check) async {
    final info = check.info; // 서버의 버전 정보
    if (check.decision == UpdateDecision.none || info == null) return;
    final required = check.decision == UpdateDecision.required; // 필수인지

    while (true) {
      if (!context.mounted) return;
      // → 로직 이동: showAppConfirmDialog()
      final accepted = await showAppConfirmDialog(
        context,
        title: '새 버전이 있습니다',
        message: _offerMessage(info, required), // → 로직 이동: _offerMessage()
        confirmLabel: '업데이트',
        cancelLabel: required ? null : '나중에',
        blockBack: required,
      ); // "업데이트" 를 눌렀는지
      if (!accepted) {
        await _checker.snooze(info); // → 로직 이동: UpdateChecker.snooze()
        return;
      }
      if (!context.mounted) return;
      // → 로직 이동: _runUpdate()
      final done = await _runUpdate(context, info, required);
      if (done || !required) return;
    }
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: _offerMessage
  /// 목적: 업데이트 창 본문을 만든다. 필수면 첫 줄에 이 버전을 더 쓸 수
  ///       없다고 밝힌다. 바뀐 점(notes)이 비어 있으면 그 줄을 뺀다.
  /// 인자: info — 서버의 버전 정보
  ///       required — 필수 업데이트인지
  /// 반환: 본문 문구
  String _offerMessage(UpdateInfo info, bool required) {
    return [
      if (required) '이 버전은 더 이상 사용할 수 없습니다.',
      '새 버전 ${info.latestName}',
      if (info.notes.isNotEmpty) info.notes,
    ].join('\n');
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: _runUpdate
  /// 목적: 설치 허용 확인 → 내려받기 → 설치를 차례로 진행한다. 단계마다
  ///       실패하면 사유를 알리고 멈춘다.
  /// 인자: context — 창을 띄울 화면의 위치 정보
  ///       info — 받을 버전 정보
  ///       required — 필수 업데이트인지. 내려받기 취소 버튼을 두지 않는다
  /// 반환: 설치 화면까지 넘겨 설치됐으면 true
  Future<bool> _runUpdate(
    BuildContext context,
    UpdateInfo info,
    bool required,
  ) async {
    // → 로직 이동: _ensureInstallAllowed()
    if (!await _ensureInstallAllowed(context, required)) return false;
    if (!context.mounted) return false;

    // → 로직 이동: _DownloadDialog
    final download = await showDialog<_DownloadOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadDialog(
        installer: _installer,
        info: info,
        cancellable: !required,
      ),
    ); // 내려받기 결과
    if (!context.mounted || download == null) return false;
    final path = download.path; // 받은 파일 경로, 실패면 null
    if (path == null) {
      final message = switch (download.errorCode) {
        'cancelled' => null,
        'sha256Mismatch' => '받은 파일이 손상되어 설치하지 않았습니다. 다시 시도하세요.',
        _ => '새 버전을 받지 못했습니다. 인터넷 연결을 확인하세요.',
      }; // 알릴 문구, 사용자가 취소했으면 null
      if (message != null) showErrorSnackBar(context, message);
      return false;
    }

    // → 로직 이동: UpdateInstaller.install()
    final (outcome, reason) = await _installer.install(path);
    if (!context.mounted) return outcome == InstallOutcome.success;
    switch (outcome) {
      case InstallOutcome.success:
        return true;
      case InstallOutcome.aborted:
        return false;
      case InstallOutcome.conflict:
        // → 로직 이동: showAppConfirmDialog()
        await showAppConfirmDialog(
          context,
          title: '새로 설치가 필요합니다',
          message:
              '기존 앱을 지우고 새로 설치해야 합니다. 설치된 앱과 서명이 달라 '
              '덮어쓸 수 없습니다. 앱을 지우면 기기에 저장된 측정 결과도 '
              '지워지므로 먼저 옮겨 두세요.',
          confirmLabel: '확인',
        );
        return false;
      case InstallOutcome.failed:
        debugPrint('UpdatePrompt: 설치 실패 — $reason');
        showErrorSnackBar(context, '설치하지 못했습니다. 다시 시도하세요.');
        return false;
    }
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: _ensureInstallAllowed
  /// 목적: 이 앱의 APK 설치가 허용됐는지 보고, 꺼져 있으면 안내한 뒤
  ///       설정 화면으로 보낸다. 돌아오면 다시 확인한다.
  /// 인자: context — 창을 띄울 화면의 위치 정보
  ///       required — 필수 업데이트인지. 안내 창에 "취소" 를 두지 않는다
  /// 반환: 허용됐으면 true
  Future<bool> _ensureInstallAllowed(
    BuildContext context,
    bool required,
  ) async {
    // → 로직 이동: UpdateInstaller.canInstall()
    if (await _installer.canInstall()) return true;
    if (!context.mounted) return false;
    // → 로직 이동: showAppConfirmDialog()
    final go = await showAppConfirmDialog(
      context,
      title: '설치 허용이 필요합니다',
      message: "설정에서 'V-Check 의 앱 설치 허용'을 켠 뒤 돌아오세요.",
      confirmLabel: '설정 열기',
      cancelLabel: required ? null : '취소',
      blockBack: required,
    ); // "설정 열기" 를 눌렀는지
    if (!go) return false;
    // → 로직 이동: UpdateInstaller.openInstallSettings()
    final allowed = await _installer.openInstallSettings();
    if (!allowed && context.mounted) {
      showErrorSnackBar(context, '설치 허용이 꺼져 있어 업데이트하지 않았습니다.');
    }
    return allowed;
  }
}

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: _DownloadOutcome
/// 목적: 내려받기 창이 돌려주는 결과. 성공이면 `path`, 실패면
///       `errorCode`(`UpdateDownloadException.code`) 하나만 채운다.
class _DownloadOutcome {
  /// 받은 파일 경로. 실패면 null
  final String? path;

  /// 실패 사유 코드. 성공이면 null
  final String? errorCode;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: _DownloadOutcome
  /// 목적: 결과를 담는다.
  /// 인자: path, errorCode — 위 필드
  const _DownloadOutcome({this.path, this.errorCode});
}

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: _DownloadDialog
/// 목적: APK 를 받는 동안 진행 막대(퍼센트)를 보여 주는 창. 선택
///       업데이트일 때만 "취소" 를 둔다. 뒤로가기 · 바깥 누르기로는 닫히지
///       않는다 — 받는 중에 창만 닫히면 받기가 끝난 뒤 설치가 엉뚱한 때
///       뜬다.
class _DownloadDialog extends StatefulWidget {
  /// 내려받기 통로
  final UpdateInstaller installer;

  /// 받을 버전 정보
  final UpdateInfo info;

  /// "취소" 버튼을 둘지
  final bool cancellable;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: _DownloadDialog
  /// 목적: 창에 필요한 값을 받는다.
  /// 인자: installer, info, cancellable — 위 필드
  const _DownloadDialog({
    required this.installer,
    required this.info,
    required this.cancellable,
  });

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

/// 작성: 2026-10-13 14:18:51 · 박건준
/// 클래스: _DownloadDialogState
/// 목적: 창이 뜨면 내려받기를 시작하고, 진행률을 받아 막대를 갱신하다가
///       끝나면 결과를 들고 창을 닫는다.
class _DownloadDialogState extends State<_DownloadDialog> {
  /// 진행률 구독. `initState()` 가 만들고 `dispose()` 가 끊는다
  StreamSubscription<DownloadProgress>? _progressSub;

  /// 받은 비율(0~1). 아직 모르거나 서버가 크기를 주지 않으면 null
  double? _fraction;

  /// "취소" 를 눌렀는지. 두 번 누르지 않게 버튼을 끈다
  bool _cancelling = false;

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: initState
  /// 목적: 진행률을 듣기 시작하고 내려받기를 시작한다.
  @override
  void initState() {
    super.initState();
    // → 로직 이동: UpdateInstaller.progress()
    _progressSub = widget.installer.progress().listen((p) {
      if (mounted) setState(() => _fraction = p.fraction);
    });
    _download(); // → 로직 이동: _download()
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: _download
  /// 목적: 내려받기를 기다려 결과를 들고 창을 닫는다.
  Future<void> _download() async {
    _DownloadOutcome outcome; // 창이 돌려줄 결과
    try {
      // → 로직 이동: UpdateInstaller.download()
      final path = await widget.installer.download(widget.info);
      outcome = _DownloadOutcome(path: path);
    } on UpdateDownloadException catch (e) {
      debugPrint('UpdatePrompt: 내려받기 실패 — $e');
      outcome = _DownloadOutcome(errorCode: e.code);
    }
    if (mounted) Navigator.of(context).pop(outcome);
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: dispose
  /// 목적: 진행률 구독을 끊는다.
  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  /// 작성: 2026-10-13 14:18:51 · 박건준
  /// 함수: build
  /// 목적: 제목 · 진행 막대 · 퍼센트 · (선택이면) 취소 버튼을 그린다.
  @override
  Widget build(BuildContext context) {
    final fraction = _fraction; // 받은 비율, 모르면 null
    return PopScope(
      // 받는 중에는 뒤로가기로 닫지 않는다
      canPop: false,
      child: AlertDialog(
        title: Text('새 버전을 받는 중', style: AppText.subhead),
        content: Column(
          // 진행 막대와 퍼센트
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: fraction,
              minHeight: AppDims.gap,
              color: AppColors.blue,
              backgroundColor: AppColors.surface,
            ),
            const SizedBox(height: AppDims.gap2),
            Text(
              fraction == null ? '받는 중…' : '${(fraction * 100).floor()}%',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          if (widget.cancellable)
            AppDialogButton(
              label: '취소',
              primary: false,
              onPressed: _cancelling
                  ? null
                  : () {
                      setState(() => _cancelling = true);
                      // → 로직 이동: UpdateInstaller.cancelDownload()
                      widget.installer.cancelDownload();
                    },
            ),
        ],
      ),
    );
  }
}
