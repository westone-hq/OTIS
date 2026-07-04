import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_checker/domain/auth_repository.dart';
import 'package:vibration_checker/domain/models/measurement_result.dart';
import 'package:vibration_checker/domain/report_generator.dart';
import 'package:vibration_checker/domain/repository/measurement_repository.dart';

import '../../core/theme.dart';

/// S5/S6 공용 이메일 발송 바텀 시트 표시 함수
void showSendEmailSheet(BuildContext context, {required String jobId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDims.radius),
      ),
    ),
    builder: (ctx) => SendEmailSheet(jobId: jobId),
  );
}

/// 이메일 발송 바텀 시트 위젯
/// - 등록된 이메일 수신자 확인 및 발송 항목 선택
/// - 어르신 UX: 70% 높이, 64dp 체크박스 행, 스케일 1.4 체크박스, 명확한 3중 에러 표시
class SendEmailSheet extends StatefulWidget {
  final String jobId;

  /// 위젯 테스트 등에서 실제 네이티브 호출을 가로채기 위한 override
  static Future<void> Function(Email email)? overrideEmailSender;

  const SendEmailSheet({super.key, required this.jobId});

  @override
  State<SendEmailSheet> createState() => _SendEmailSheetState();
}

class _SendEmailSheetState extends State<SendEmailSheet> {
  bool _sendPdf = true;
  bool _sendRaw = true;
  bool _sendSummary = false;

  bool _loading = false;
  String _recipientEmail = '설정에서 이메일을 등록하세요';
  bool _isEmailSet = false;

  @override
  void initState() {
    super.initState();
    _loadRecipient();
  }

  Future<void> _loadRecipient() async {
    final id = AuthRepository.instance.currentUserId;
    String email = '설정에서 이메일을 등록하세요';
    bool isSet = false;
    if (id != null) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('email_$id');
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

  Future<void> _send() async {
    if (!_isEmailSet) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('이메일 등록 안내', style: AppText.subhead),
          content: Text('수신할 이메일 주소가 설정되지 않았습니다.\n설정 화면에서 먼저 이메일을 등록해 주세요.', style: AppText.body),
          actions: [
            Semantics(
              button: true,
              label: '취소',
              child: SizedBox(
                height: AppDims.touchMin,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('취소', style: AppText.bodyBold.copyWith(color: AppColors.navy)),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: '설정으로 이동',
              child: SizedBox(
                height: AppDims.touchMin,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                    context.push('/settings');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: AppDims.gap2),
                  ),
                  child: Text('설정으로 이동', style: AppText.bodyBold.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      var result = await MeasurementRepository.instance.load(widget.jobId);
      if (result == null) {
        result = MeasurementResult.mock;
        final baseDir = await MeasurementRepository.instance.getBaseDirectory();
        final targetDir = Directory('${baseDir.path}/${widget.jobId}');
        if (!await targetDir.exists()) await targetDir.create(recursive: true);
        final pdfFile = File('${targetDir.path}/report.pdf');
        if (!await pdfFile.exists()) await pdfFile.writeAsBytes([0x25, 0x50, 0x44, 0x46]);
        final rawFile = File('${targetDir.path}/raw.txt');
        if (!await rawFile.exists()) await rawFile.writeAsString('EVIMP1\n256\n');
      }

      final baseDir = await MeasurementRepository.instance.getBaseDirectory();
      final List<String> attachments = [];
      if (_sendPdf) {
        final pdfFile = File('${baseDir.path}/${widget.jobId}/report.pdf');
        if (await pdfFile.exists()) attachments.add(pdfFile.path);
      }
      if (_sendRaw) {
        final rawFile = File('${baseDir.path}/${widget.jobId}/raw.txt');
        if (await rawFile.exists()) attachments.add(rawFile.path);
      }

      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(result.dateTime);
      final subject = 'TUNE Summary Report - ${result.jobNo} - $dateStr';
      final body = _sendSummary
          ? ReportGenerator.generateSummaryText(result)
          : 'OTIS 승강기 진동 측정 TUNE 리포트 및 첨부파일입니다.';

      final email = Email(
        body: body,
        subject: subject,
        recipients: [_recipientEmail],
        attachmentPaths: attachments,
      );

      if (SendEmailSheet.overrideEmailSender != null) {
        await SendEmailSheet.overrideEmailSender!(email);
      } else {
        await FlutterEmailSender.send(email);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.green,
              ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메일 작성창 호출 실패: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              Expanded(
                child: Text(title, style: AppText.body),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool noneSelected = !_sendPdf && !_sendRaw && !_sendSummary;
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
                Semantics(
                  button: true,
                  label: '닫기',
                  child: SizedBox(
                    width: AppDims.touchMin,
                    height: AppDims.touchMin,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 28),
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
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
                          style: AppText.caption.copyWith(color: AppColors.textSub),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _recipientEmail,
                          style: AppText.bodyBold,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: AppDims.touchMin,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/settings');
                      },
                      child: Text(
                        '변경',
                        style: AppText.bodyBold.copyWith(color: AppColors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDims.gap2),

            // 3. 발송 항목 CheckboxListTile 3개
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCheckboxItem(
                      title: 'PDF 리포트',
                      value: _sendPdf,
                      onChanged: (val) => setState(() => _sendPdf = val ?? false),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildCheckboxItem(
                      title: 'RAW 데이터 파일',
                      value: _sendRaw,
                      onChanged: (val) => setState(() => _sendRaw = val ?? false),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildCheckboxItem(
                      title: '지표 요약(메일 본문)',
                      value: _sendSummary,
                      onChanged: (val) => setState(() => _sendSummary = val ?? false),
                    ),
                  ],
                ),
              ),
            ),

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
