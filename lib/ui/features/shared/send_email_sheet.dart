import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_layout.dart';
import '../../core/widgets/app_snack_bar.dart';

/// 작성: 2026-08-19 10:33:43 · 박건준
/// 수정: 2026-10-04 13:37:23 · nada
/// 함수: showSendEmailSheet
/// 목적: 이메일 발송 화면을 앱 공통 모양의 바텀 시트(화면 아래에서 위로
///       올라오는 패널)로 띄운다. 저장된 측정 결과를 보낼 때와, 측정을
///       막 마친 파일을 그대로 보낼 때 둘 다 이 함수 하나로 연다.
/// 인자: context — 시트를 띄울 화면의 위치 정보
///       jobId — 첨부할 측정 결과의 식별자. 저장소에서 그 결과를 찾아
///       첨부한다. attachmentPaths 대신 쓴다
///       attachmentPaths — 이미 가진 파일을 저장소 조회 없이 그대로
///       첨부하는 경로 목록. jobId 대신 쓴다
///       subject — 메일 제목. attachmentPaths 경로에서만 쓰인다
///       body — 메일 본문. attachmentPaths 경로에서만 쓰인다
/// 반환: 시트가 닫힐 때 완료되는 비동기 작업. jobId 와 attachmentPaths 를
///       둘 다 주거나 둘 다 빼면 `ArgumentError` 를 던진다
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
  return showAppSheet(
    context,
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

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 함수: SendEmailSheet
  /// 목적: 시트가 보낼 자료를 받는다. `jobId` 와 `attachmentPaths` 중 하나만
  ///       준다 — 둘 다 주거나 빼는 경우는 `showSendEmailSheet()` 가 막는다.
  /// 인자: jobId, attachmentPaths, subject, body — 위 필드 설명을 따른다
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
/// 수정: 2026-10-04 16:44:32 · nada
/// 클래스: _SendEmailSheetState
/// 목적: 이메일 발송 바텀 시트의 상태를 관리한다. 등록된 수신 이메일
///       가운데 받을 주소를 여러 개 고르게 하고, 보낼 항목을 선택받아
///       발송을 실행한다. 보낸 주소는 기억해 다음에 미리 골라 둔다.
class _SendEmailSheetState extends State<SendEmailSheet> {
  /// PDF 리포트를 보낼 항목에 포함할지 여부. 첨부 경로를 직접 전달받는
  /// 경로(attachmentPaths)에서는 쓰이지 않는다
  bool _sendPdf = true;

  /// 측정값 원본(`raw.txt`)을 보낼 항목에 포함할지 여부. 첨부 경로를
  /// 직접 전달받는 경로에서는 쓰이지 않는다
  bool _sendRaw = true;

  /// "보내기"를 눌러 메일을 조립·발송하는 중인지 여부. true인 동안
  /// 버튼을 비활성화해 중복 실행을 막는다
  bool _loading = false;

  /// 설정에 등록된 수신 이메일 전부. `_loadRecipients()` 가 채운다.
  /// 비어 있으면 아직 등록하지 않은 것이다
  List<String> _emails = <String>[];

  /// 받을 주소로 고른 이메일. `_loadRecipients()` 가 지난번 보낸 주소로
  /// 미리 채우고, 체크를 바꿀 때마다 고친다
  final Set<String> _selected = <String>{};

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: initState
  /// 목적: 이 시트가 화면에 나타날 때 한 번, 저장된 수신 이메일과 지난번
  ///       보낸 주소를 불러와 화면에 표시한다.
  @override
  void initState() {
    super.initState();
    _loadRecipients(); // → 로직 이동: _loadRecipients()
  }

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: _loadRecipients
  /// 목적: 등록된 수신 이메일 목록을 불러오고, 지난번 메일을 보낸 주소
  ///       가운데 아직 목록에 남아 있는 것을 미리 고른다. 보낸 적이 없고
  ///       등록된 주소가 하나뿐이면 그 하나를 고른다.
  Future<void> _loadRecipients() async {
    final store = PrefsStore.instance; // 기기 저장소
    // → 로직 이동: PrefsStore.loadEmails()
    final emails = await store.loadEmails(); // 등록된 수신 이메일
    // → 로직 이동: PrefsStore.loadLastRecipients()
    final last = await store.loadLastRecipients(); // 지난번 보낸 주소
    if (!mounted) return;
    setState(() {
      _emails = emails;
      _selected
        ..clear()
        ..addAll(last.where(emails.contains));
      if (_selected.isEmpty && emails.length == 1) _selected.add(emails.first);
    });
  }

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 함수: _recipients
  /// 목적: 고른 주소를 설정에 등록된 차례대로 늘어놓는다. 메일 앱에 넘기는
  ///       수신자 목록이다.
  /// 반환: 받을 주소 목록
  List<String> _recipients() =>
      _emails.where(_selected.contains).toList(growable: false);

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: _send
  /// 목적: "보내기" 버튼을 눌렀을 때 실행된다. 수신 이메일이 하나도
  ///       등록되지 않았으면 등록 안내 대화상자를 띄우고 멈춘다. 등록되어
  ///       있으면 보낼 메일의 제목·본문·수신자·첨부파일을 정하고
  ///       (첨부 경로를 그대로 전달받은 경우 `_buildAttachmentEmail()`,
  ///       측정 결과 ID로 조회하는 경우 `_buildJobEmail()`), 기기에
  ///       이미 설치된 메일 앱(Gmail 등)의 작성 화면을 그 내용으로
  ///       미리 채워서 띄운다. 실제 발송 버튼은 사용자가 그 메일
  ///       앱에서 직접 눌러야 한다 — 이 함수가 메일을 대신 보내주는
  ///       것은 아니다. 메일 앱 작성창을 띄웠으면 고른 주소를 기억한다.
  Future<void> _send() async {
    if (_emails.isEmpty) {
      // → 로직 이동: showAppConfirmDialog()
      final goToSettings = await showAppConfirmDialog(
        context,
        title: '이메일 등록 안내',
        message:
            '수신할 이메일 주소가 설정되지 않았습니다.\n'
            '설정 화면에서 먼저 이메일을 등록해 주세요.',
        confirmLabel: '설정으로 이동',
        cancelLabel: '취소',
        barrierDismissible: true,
      ); // 설정으로 가기를 골랐는지
      if (goToSettings && mounted) {
        Navigator.of(context).pop();
        context.push('/settings'); // → 로직 이동: SettingsScreen.build()
      }
      return;
    }

    setState(() => _loading = true);

    try {
      final email = widget.attachmentPaths != null
          // → 로직 이동: _buildAttachmentEmail()
          ? await _buildAttachmentEmail(widget.attachmentPaths!)
          // → 로직 이동: _buildJobEmail()
          : await _buildJobEmail(widget.jobId!);

      // → 로직 이동: FlutterEmailSender.send()
      await FlutterEmailSender.send(email);
      // → 로직 이동: PrefsStore.saveLastRecipients()
      await PrefsStore.instance.saveLastRecipients(email.recipients);

      if (!mounted) return;
      Navigator.of(context).pop();
      showSuccessSnackBar(context, '메일 작성창이 호출되었습니다 (첨부 구성 완료)');
    } catch (e) {
      if (!mounted) return;
      final message = widget.jobId != null
          ? '메일에 넣을 자료를 준비하지 못했습니다.\n$e'
          : '메일 작성창 호출 실패: $e'; // 화면에 보여줄 실패 안내 문구
      showErrorSnackBar(context, message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: _buildJobEmail
  /// 목적: jobId 로 저장소를 조회해 리포트 메일을 조립한다. 보내기로 한
  ///       자료 중 실제로 없는 것이 있으면 본문 끝에 "누락:" 줄로 밝힌다 —
  ///       빠진 채로 조용히 나가면 받는 쪽이 한참 뒤에야 안다. 메일 앱
  ///       작성창에 본문이 그대로 뜨므로 보내는 사람도 누르기 전에 본다.
  ///       파일이 어디에 어떤 이름으로 있는지는 저장소에 묻는다. 화면이
  ///       경로를 짜 맞추면 저장 배치가 바뀔 때 여기가 조용히 어긋난다.
  /// 인자: jobId — 첨부할 측정 결과의 식별자
  /// 반환: 수신자·제목·본문·첨부까지 채운 메일 객체
  Future<Email> _buildJobEmail(String jobId) async {
    // → 로직 이동: MeasurementRepository.load()
    final result = await MeasurementRepository.instance.load(
      jobId,
    ); // 조회된 측정 결과, 없으면 null
    if (result == null) {
      throw StateError('측정 결과를 찾을 수 없다: $jobId');
    }

    final repo = MeasurementRepository.instance; // 저장소 인스턴스
    // → 로직 이동: MeasurementRepository.jobDirectory()
    final jobDir = await repo.jobDirectory(jobId); // 이 측정의 폴더
    final List<String> attachments = []; // 실제로 첨부할 파일 경로
    final List<String> attachmentDescriptions = []; // 본문에 나열할 첨부 설명 줄
    final List<String> missing = []; // 보내기로 했는데 없는 자료

    if (_sendPdf) {
      // → 로직 이동: MeasurementRepository.ensureReportPdf()
      final pdfFile = await repo.ensureReportPdf(
        jobId,
      ); // 만들어졌거나 이미 있던 PDF. 저장된 측정이 없으면 null
      if (pdfFile != null && await pdfFile.exists()) {
        attachments.add(pdfFile.path);
        attachmentDescriptions.add(
          '- ${MeasurementRepository.reportFileName}: 앱 측정 결과(가공값)',
        );
      } else {
        missing.add(
          '누락: ${MeasurementRepository.reportFileName} — 리포트를 만들지 '
          '못했습니다',
        );
      }
    }
    if (_sendRaw) {
      final rawFile = File(
        '${jobDir.path}/${MeasurementRepository.rawFileName}',
      ); // 격자에 맞춘 측정값 파일
      if (await rawFile.exists()) {
        attachments.add(rawFile.path);
        attachmentDescriptions.add(
          '- ${MeasurementRepository.rawFileName}: 측정값 원본(256Hz)',
        );
      } else {
        missing.add(
          '누락: ${MeasurementRepository.rawFileName} — 측정값 원본 파일이 '
          '없습니다',
        );
      }
    }

    final dateStr = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(result.dateTime); // 메일 제목에 쓸 날짜 문구
    final subject = 'TUNE Summary Report - ${result.jobNo} - $dateStr'; // 메일 제목
    final bodyLines = <String>[
      'OTIS 승강기 진동 측정 리포트입니다.',
      ...attachmentDescriptions,
      '',
      '※ 첨부 ${attachments.length}개',
      if (missing.isNotEmpty) ...['', ...missing],
    ]; // 메일 본문 줄 목록
    final body = bodyLines.join('\n'); // 메일 본문

    return Email(
      body: body,
      subject: subject,
      recipients: _recipients(), // → 로직 이동: _recipients()
      attachmentPaths: attachments,
    );
  }

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
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
      recipients: _recipients(), // → 로직 이동: _recipients()
      attachmentPaths: attachments,
    );
  }

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: _buildCheckboxItem
  /// 목적: 보낼 항목 하나를 체크박스 + 이름 한 줄로 만든다. 줄 어디를
  ///       눌러도 체크가 바뀌고, 체크박스는 어르신이 누르기 쉽게 키운다.
  /// 인자: title — 항목 이름
  ///       value — 지금 체크됐는지
  ///       onChanged — 체크를 바꿀 때 부를 함수. 바뀐 값을 받는다
  /// 반환: 체크 항목 한 줄 위젯
  Widget _buildCheckboxItem({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppDims.rowMinH),
      alignment: Alignment.center,
      child: InkWell(
        // 줄 전체를 누를 자리로 만든다
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDims.gap),
          child: Row(
            children: [
              Transform.scale(
                // 체크박스만 키운다
                scale: AppDims.checkboxScale,
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

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: build
  /// 목적: 이메일 발송 시트를 그린다. 위에서부터 순서대로 놓는다.
  ///       1. 제목과 닫기 버튼
  ///       2. 받는 사람 — 등록된 이메일마다 체크 한 줄. 여러 개 고를 수
  ///          있다. "관리"를 누르면 설정 화면으로 간다
  ///       3. 보낼 항목 체크 목록. 파일을 그대로 넘겨받은 경우에는 넘겨받은
  ///          파일을 전부 보내므로 목록을 보여주지 않는다
  ///       4. 고를 것이 빠졌을 때의 안내와 "보내기" 버튼
  ///       2 · 3 은 함께 스크롤되고 4 는 아래에 고정한다. 시트 아래쪽
  ///       시스템 영역은 `showAppSheet()` 가 비켜 준다.
  /// 인자: context — 이 시트가 화면 어디에 놓이는지 알려주는 값
  /// 반환: 화면 높이의 일정 비율을 차지하는 시트 내용
  @override
  Widget build(BuildContext context) {
    final isAttachmentMode = widget.attachmentPaths != null; // 파일을 그대로 넘겨받았는지
    final noItem =
        !isAttachmentMode && !_sendPdf && !_sendRaw; // 보낼 항목을 고르지 않았는지
    final noRecipient = _selected.isEmpty; // 받을 주소를 고르지 않았는지
    final warning = _emails.isEmpty
        ? null
        : noRecipient
        ? '받을 이메일을 선택하세요'
        : noItem
        ? '보낼 항목을 선택하세요'
        : null; // 보내기 버튼 위 안내 문구, 없으면 null
    final sheetHeight =
        MediaQuery.of(context).size.height * AppDims.sheetHeightFactor; // 시트 높이

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

            Expanded(
              // 받는 사람 · 보낼 항목을 함께 스크롤
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2. 받는 사람
                    Row(
                      children: [
                        Expanded(child: Text('받는 사람', style: AppText.bodyBold)),
                        // 수신 이메일을 등록 · 삭제하러 설정 화면으로 이동
                        AppDialogButton(
                          label: '관리',
                          onPressed: () {
                            Navigator.of(context).pop();
                            // → 로직 이동: SettingsScreen.build()
                            context.push('/settings');
                          },
                          primary: false,
                          textColor: AppColors.blue,
                        ),
                      ],
                    ),
                    if (_emails.isEmpty)
                      Text(
                        '등록된 이메일이 없습니다. 설정에서 먼저 등록해 주세요.',
                        style: AppText.caption,
                      ),
                    for (final email in _emails) ...[
                      _buildCheckboxItem(
                        title: email,
                        value: _selected.contains(email),
                        onChanged: (val) => setState(() {
                          if (val ?? false) {
                            _selected.add(email);
                          } else {
                            _selected.remove(email);
                          }
                        }),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                    ],

                    // 3. 보낼 항목 — 파일을 그대로 넘겨받았으면 전부 보낸다
                    if (!isAttachmentMode) ...[
                      const SizedBox(height: AppDims.gap3),
                      Text('보낼 항목', style: AppText.bodyBold),
                      _buildCheckboxItem(
                        title: 'PDF 리포트',
                        value: _sendPdf,
                        onChanged: (val) =>
                            setState(() => _sendPdf = val ?? false),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _buildCheckboxItem(
                        title: '측정값 원본 (raw.txt)',
                        value: _sendRaw,
                        onChanged: (val) =>
                            setState(() => _sendRaw = val ?? false),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDims.gap),

            // 4. 하단 안내 및 보내기 버튼
            if (warning != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: AppDims.iconXs,
                    color: AppColors.red,
                  ),
                  const SizedBox(width: AppDims.gapHalf),
                  Text(
                    warning,
                    style: AppText.caption.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDims.gap),
            ],
            ElevatedButton(
              // 등록된 주소가 없으면 눌렀을 때 등록 안내를 띄운다
              onPressed:
                  (_emails.isNotEmpty && (noRecipient || noItem)) || _loading
                  ? null
                  : _send, // → 로직 이동: _send()
              child: _loading
                  ? const SizedBox(
                      width: AppDims.iconS,
                      height: AppDims.iconS,
                      child: CircularProgressIndicator(
                        color: AppColors.onDark,
                        strokeWidth: AppDims.spinnerStroke,
                      ),
                    )
                  : const Text('보내기'),
            ),
          ],
        ),
      ),
    );
  }
}
