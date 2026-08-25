import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import 'package:vibration_checker/adapter/auth_repository.dart';
import 'package:vibration_checker/adapter/report_generator.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';

/// 작성: 2026-08-19 10:33:43 · 박건준
/// 함수: showSendEmailSheet
/// 목적: 이메일 발송 화면을 `showModalBottomSheet`(화면 아래에서 위로
///       올라오는 바텀 시트를 띄우는 Flutter 함수)로 띄운다. 측정
///       결과 화면과 첨부파일 전달 화면 둘 다 이 함수 하나로 발송
///       시트를 연다. 각 인자의 역할은 다음과 같다.
///       - `context` — 어느 화면 위에 띄울지 알려주는 위치 정보
///       - `isScrollControlled` — true로 주면 시트가 내용 길이에 맞춰
///         화면 위쪽 끝까지 늘어날 수 있다
///       - `backgroundColor` — 시트 바탕색
///       - `shape` — 시트의 위쪽 두 모서리만 둥글게 깎는 테두리 모양
///       - `builder` — 시트 안에 실제로 그릴 위젯을 돌려주는 함수.
///         여기서는 `SendEmailSheet`를 그대로 띄운다
/// 인자: context — 시트를 띄울 화면의 BuildContext
///       jobId — 첨부할 측정 결과의 식별자. 저장소에서 그 결과를 찾아
///       첨부한다. attachmentPaths 대신 쓴다
///       attachmentPaths — 이미 가진 파일을 저장소 조회 없이 그대로
///       첨부하는 경로 목록. jobId 대신 쓴다
///       subject — 메일 제목. attachmentPaths 경로에서만 쓰인다
///       body — 메일 본문. attachmentPaths 경로에서만 쓰인다
/// 반환: 시트가 닫힐 때 완료되는 Future
Future<void> showSendEmailSheet(
  BuildContext context, {
  String? jobId,
  List<String>? attachmentPaths,
  String? subject,
  String? body,
}) {
  if ((jobId != null) == (attachmentPaths != null)) {
    throw ArgumentError('jobId 와 attachmentPaths 중 정확히 하나만 지정해야 한다');
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDims.radius)),
    ),
    // → 로직 이동: SendEmailSheet.initState()
    builder: (ctx) => SendEmailSheet(
      jobId: jobId,
      attachmentPaths: attachmentPaths,
      subject: subject,
      body: body,
    ),
  );
}

/// 작성: 2026-08-19 10:33:43 · 박건준
/// 클래스: SendEmailSheet
/// 목적: 이메일 발송 바텀 시트 위젯. 등록된 수신자를 보여주고, 보낼
///       항목을 선택받아 기기의 메일 앱을 띄운다. 어르신도 쓰기
///       편하도록 시트 높이 70%, 체크박스 한 행 64dp, 체크박스
///       확대(1.4배)를 적용했다.
class SendEmailSheet extends StatefulWidget {
  /// 첨부할 측정 결과의 식별자. attachmentPaths 대신 쓴다
  final String? jobId;

  /// 그대로 첨부할 파일 경로 목록. jobId 대신 쓴다
  final List<String>? attachmentPaths;

  /// 메일 제목. attachmentPaths 경로에서만 쓰인다
  final String? subject;

  /// 메일 본문. attachmentPaths 경로에서만 쓰인다
  final String? body;

  const SendEmailSheet({
    super.key,
    this.jobId,
    this.attachmentPaths,
    this.subject,
    this.body,
  });

  @override
  State<SendEmailSheet> createState() => _SendEmailSheetState();
}

/// 작성: 2026-08-19 10:33:43 · 박건준
/// 클래스: _SendEmailSheetState
/// 목적: 이메일 발송 바텀 시트의 상태를 관리한다. 등록된 수신자를
///       확인하고, 보낼 항목을 선택받아 발송을 실행한다.
class _SendEmailSheetState extends State<SendEmailSheet> {
  /// PDF 리포트를 보낼 항목에 포함할지 여부. 첨부 경로를 직접 전달받는
  /// 경로(attachmentPaths)에서는 쓰이지 않는다
  bool _sendPdf = true;

  /// RAW 원본(raw.txt + 엑셀)을 보낼 항목에 포함할지 여부. 첨부 경로를
  /// 직접 전달받는 경로에서는 쓰이지 않는다
  bool _sendRaw = true;

  /// 지표 요약을 메일 본문에 넣을지 여부. 첨부 경로를 직접 전달받는
  /// 경로에서는 쓰이지 않는다
  bool _sendSummary = false;

  /// "보내기"를 눌러 메일을 조립·발송하는 중인지 여부. true인 동안
  /// 버튼을 비활성화해 중복 실행을 막는다
  bool _loading = false;

  /// 화면에 보여줄 수신 이메일 주소. `_loadRecipient()`가 채운다.
  /// 등록된 적이 없으면 안내 문구가 그대로 남는다
  String _recipientEmail = '설정에서 이메일을 등록하세요';

  /// 수신 이메일이 실제로 등록되어 있는지 여부. `_loadRecipient()`가
  /// 채우고, `_send()`가 이 값을 보고 등록 안내를 띄울지 정한다
  bool _isEmailSet = false;

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 함수: initState
  /// 목적: 이 시트가 화면에 나타날 때 한 번, 저장된 수신자 이메일을
  ///       불러와 화면에 표시한다.
  @override
  void initState() {
    super.initState();
    // → 로직 이동: _loadRecipient()
    _loadRecipient();
  }

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 함수: _loadRecipient
  /// 목적: 지금 로그인된 사용자 앞으로 저장된 수신 이메일을 불러와
  ///       화면에 표시할 상태를 채운다. 로그인 정보가 없거나, 이메일을
  ///       등록한 적이 없거나, 등록값이 빈 문자열이면 안내 문구를
  ///       그대로 두고 `_isEmailSet`을 false로 남긴다 — `_send()`가
  ///       이 값을 보고 발송 전 등록 안내를 띄운다.
  Future<void> _loadRecipient() async {
    // → 로직 이동: AuthRepository.currentUserId
    final id = AuthRepository.instance.currentUserId; // 로그인 사용자 식별자
    String email = '설정에서 이메일을 등록하세요'; // 화면에 채울 수신 이메일
    bool isSet = false; // 실제로 등록된 이메일을 찾았는지 여부
    if (id != null) {
      // → 로직 이동: PrefsStore.loadEmail()
      final saved = await PrefsStore.instance.loadEmail(id); // 저장된 수신 주소
      if (saved != null && saved.trim().isNotEmpty) {
        email = saved;
        isSet = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _recipientEmail = email;
      _isEmailSet = isSet;
    });
  }

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 함수: _send
  /// 목적: "보내기" 버튼을 눌렀을 때 실행된다. 수신 이메일이 등록되지
  ///       않았으면 등록 안내 대화상자를 띄우고 멈춘다. 등록되어
  ///       있으면 보낼 메일의 제목·본문·수신자·첨부파일을 정하고
  ///       (첨부 경로를 그대로 전달받은 경우 `_buildAttachmentEmail()`,
  ///       측정 결과 ID로 조회하는 경우 `_buildJobEmail()`), 기기에
  ///       이미 설치된 메일 앱(Gmail 등)의 작성 화면을 그 내용으로
  ///       미리 채워서 띄운다. 실제 발송 버튼은 사용자가 그 메일
  ///       앱에서 직접 눌러야 한다 — 이 함수가 메일을 대신 보내주는
  ///       것은 아니다.
  Future<void> _send() async {
    if (!_isEmailSet) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('이메일 등록 안내', style: AppText.subhead),
          content: Text(
            '수신할 이메일 주소가 설정되지 않았습니다.\n설정 화면에서 먼저 이메일을 등록해 주세요.',
            style: AppText.body,
          ),
          actions: [
            AppDialogButton(
              label: '취소',
              onPressed: () => Navigator.of(ctx).pop(),
              primary: false,
            ),
            AppDialogButton(
              label: '설정으로 이동',
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                // → 로직 이동: SettingsScreen
                context.push('/settings');
              },
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final email = widget.attachmentPaths != null
          // → 로직 이동: _buildAttachmentEmail()
          ? await _buildAttachmentEmail(widget.attachmentPaths!)
          // → 로직 이동: _buildJobEmail()
          : await _buildJobEmail(widget.jobId!);

      // → 로직 이동: 기기 메일 앱(외부)
      await FlutterEmailSender.send(email);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.green),
              const SizedBox(width: AppDims.gap),
              const Expanded(
                child: Text(
                  '메일 작성창이 호출되었습니다 (첨부 구성 완료)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = widget.jobId != null
          ? '저장·출력 기능은 아직 구현되지 않았습니다.\n(요청: 메일 첨부 자료 조회)'
          : '메일 작성창 호출 실패: $e'; // 화면에 보여줄 실패 안내 문구
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 함수: _buildJobEmail
  /// 목적: jobId 로 저장소를 조회해 리포트 메일을 조립한다 (기존 경로, 동작 변경 없음).
  Future<Email> _buildJobEmail(String jobId) async {
    final result = await MeasurementRepository.instance.load(jobId);
    if (result == null) {
      throw StateError('측정 결과를 찾을 수 없다: $jobId');
    }

    final baseDir = await MeasurementRepository.instance.getBaseDirectory();
    final repo = MeasurementRepository.instance;
    final List<String> attachments = [];
    final List<String> attachmentDescriptions = [];

    if (_sendPdf) {
      final pdfFile = await repo.ensureReportPdf(jobId);
      if (pdfFile != null && await pdfFile.exists()) {
        attachments.add(pdfFile.path);
        attachmentDescriptions.add('- report.pdf: 앱 측정 결과(가공값)');
      }
    }
    if (_sendRaw) {
      // 1) 센서 원본 raw.txt
      final rawFile = File('${baseDir.path}/$jobId/raw.txt');
      if (await rawFile.exists()) {
        attachments.add(rawFile.path);
        attachmentDescriptions.add('- raw.txt: 센서 원본 샘플(256Hz)');
      }
      // 2) 초별 분리 엑셀 (256 / 128 / 64Hz)
      final excelFiles = await repo.ensureRawExcelFiles(jobId);
      for (final excel in excelFiles) {
        if (await excel.exists()) {
          attachments.add(excel.path);
          final name = excel.path.replaceAll('\\', '/').split('/').last;
          attachmentDescriptions.add('- $name');
        }
      }
    }

    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(result.dateTime);
    final subject = 'TUNE Summary Report - ${result.jobNo} - $dateStr';
    final body = _sendSummary
        ? ReportGenerator.generateSummaryText(result)
        : 'OTIS 승강기 진동 측정 리포트입니다.\n'
              '${attachmentDescriptions.join('\n')}\n'
              '\n'
              '※ 첨부 ${attachments.length}개';

    return Email(
      body: body,
      subject: subject,
      recipients: [_recipientEmail],
      attachmentPaths: attachments,
    );
  }

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 함수: _buildAttachmentEmail
  /// 목적: 전달받은 첨부 경로로 메일의 제목·본문·수신자·첨부파일
  ///       목록을 정한다. 저장소 조회나 측정 결과 객체 생성 과정을
  ///       거치지 않는다 — 이미 첨부할 파일 경로를 갖고 있는
  ///       상태이기 때문이다. 경로마다 파일이 실제로 있는지 확인해,
  ///       있는 파일만 첨부 목록에 넣는다. 없는 파일은 첨부하지 않는
  ///       대신, 메일 본문 맨 아래에 "누락: 파일명" 줄을 하나씩
  ///       덧붙인다 — 받는 사람이 메일을 열었을 때 몇 개가 왜 안
  ///       왔는지 바로 알 수 있게 하기 위해서다.
  /// 인자: paths — 첨부할 파일의 절대 경로 목록
  /// 반환: 수신자·제목·본문·첨부까지 채운 메일 객체
  Future<Email> _buildAttachmentEmail(List<String> paths) async {
    final List<String> attachments = []; // 실제로 존재해 첨부할 경로
    final List<String> missingNames = []; // 존재하지 않아 누락 처리할 파일명

    for (final path in paths) {
      if (await File(path).exists()) {
        attachments.add(path);
      } else {
        missingNames.add(path.replaceAll('\\', '/').split('/').last);
      }
    }

    final subject = widget.subject ?? 'OTIS 진동측정 파일 전송'; // 메일 제목
    final bodyLines = <String>[
      widget.body ?? 'OTIS 진동측정 계측 파일을 첨부합니다.',
    ]; // 메일 본문 줄 목록
    for (final name in missingNames) {
      bodyLines.add('누락: $name');
    }

    return Email(
      body: bodyLines.join('\n'),
      subject: subject,
      recipients: [_recipientEmail],
      attachmentPaths: attachments,
    );
  }

  Widget _buildCheckboxItem({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      alignment: Alignment.center,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Transform.scale(
                scale: 1.4,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.blue,
                ),
              ),
              const SizedBox(width: AppDims.gap),
              Expanded(child: Text(title, style: AppText.body)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAttachmentMode = widget.attachmentPaths != null;
    final bool noneSelected =
        !isAttachmentMode && !_sendPdf && !_sendRaw && !_sendSummary;
    final double sheetHeight = MediaQuery.of(context).size.height * 0.7;

    return SizedBox(
      height: sheetHeight,
      child: Padding(
        padding: const EdgeInsets.all(AppDims.screenPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 상단 타이틀 및 닫기 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('이메일 발송', style: AppText.subhead),
                AppDialogIconButton(
                  icon: Icons.close,
                  label: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppDims.gap),

            // 2. 수신자 카드
            Container(
              padding: const EdgeInsets.all(AppDims.gap2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDims.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '받는 사람',
                          style: AppText.caption.copyWith(
                            color: AppColors.textSub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_recipientEmail, style: AppText.bodyBold),
                      ],
                    ),
                  ),
                  // 수신 이메일을 등록·변경하러 설정 화면으로 이동
                  AppDialogButton(
                    label: '변경',
                    onPressed: () {
                      Navigator.of(context).pop();
                      // → 로직 이동: SettingsScreen
                      context.push('/settings');
                    },
                    primary: false,
                    textColor: AppColors.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDims.gap2),

            // 3. 발송 항목 CheckboxListTile 3개 — attachmentPaths 경로에서는
            //    전달받은 파일을 전부 보내므로 선택 UI를 표시하지 않는다.
            if (!isAttachmentMode)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCheckboxItem(
                        title: 'PDF 리포트',
                        value: _sendPdf,
                        onChanged: (val) =>
                            setState(() => _sendPdf = val ?? false),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _buildCheckboxItem(
                        title: 'RAW 원본 (raw.txt + 엑셀 256/128/64)',
                        value: _sendRaw,
                        onChanged: (val) =>
                            setState(() => _sendRaw = val ?? false),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _buildCheckboxItem(
                        title: '지표 요약(메일 본문)',
                        value: _sendSummary,
                        onChanged: (val) =>
                            setState(() => _sendSummary = val ?? false),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Expanded(child: SizedBox.shrink()),

            // 4. 하단 안내 및 보내기 버튼
            if (noneSelected) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: AppColors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '보낼 항목을 선택하세요',
                    style: AppText.caption.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDims.gap),
            ],
            SizedBox(
              height: AppDims.buttonH,
              child: ElevatedButton(
                onPressed: (noneSelected || _loading) ? null : _send,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('보내기'),
              ),
            ),
            const SizedBox(height: AppDims.gap),
          ],
        ),
      ),
    );
  }
}
