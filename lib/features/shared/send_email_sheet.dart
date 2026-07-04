import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
/// - 등록된 이메일 수신자 확인 및 4가지 발송 항목 선택
/// - 어르신 UX: 70% 높이, 64dp 체크박스 행, 스케일 1.4 체크박스, 명확한 3중 에러 표시
class SendEmailSheet extends StatefulWidget {
  final String jobId;

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

  @override
  void initState() {
    super.initState();
    _loadRecipient();
  }

  Future<void> _loadRecipient() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recipientEmail = prefs.getString('pref_recipient_email') ?? '설정에서 이메일을 등록하세요';
    });
  }

  Future<void> _send() async {
    setState(() => _loading = true);

    // TODO: 실제 발송 API 연결
    await Future<void>.delayed(const Duration(milliseconds: 800));

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
                '이메일이 발송되었습니다',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
      ),
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

            // 3. 발송 항목 CheckboxListTile 4개
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
