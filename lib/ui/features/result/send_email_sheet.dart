import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration_checker/adapter/storage/prefs_store.dart';
import 'package:vibration_checker/domain/mail/mail_composer.dart';
import 'package:vibration_checker/service/mail_service.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/core/widgets/app_dialog.dart';
import 'package:vibration_checker/ui/core/widgets/app_layout.dart';
import 'package:vibration_checker/ui/core/widgets/app_snack_bar.dart';

/// 작성: 2026-08-19 10:33:43 · 박건준
/// 수정: 2026-10-04 18:15:24 · 박건준
/// 함수: showSendEmailSheet
/// 목적: 저장된 측정 결과 하나를 보낼 이메일 발송 화면을 앱 공통 모양의
///       바텀 시트(화면 아래에서 위로 올라오는 패널)로 띄운다. 결과 화면과
///       저장 결과 목록이 함께 쓴다.
/// 인자: context — 시트를 띄울 화면의 위치 정보
///       jobId — 첨부할 측정 결과의 식별자. 저장소에서 그 결과를 찾아
///       첨부한다
/// 반환: 시트가 닫힐 때 완료되는 비동기 작업
Future<void> showSendEmailSheet(BuildContext context, {required String jobId}) {
  return showAppSheet(
    context,
    // → 로직 이동: SendEmailSheet.initState()
    builder: (ctx) => SendEmailSheet(jobId: jobId),
  );
}

/// 작성: 2026-08-19 10:33:43 · 박건준
/// 수정: 2026-10-04 18:15:24 · 박건준
/// 클래스: SendEmailSheet
/// 목적: 이메일 발송 바텀 시트 위젯. 등록된 수신자를 보여주고, 보낼
///       항목을 선택받아 기기의 메일 앱을 띄운다. 어르신도 쓰기
///       편하도록 체크박스 한 행 64dp, 체크박스 확대(1.4배)를 적용했다.
class SendEmailSheet extends StatefulWidget {
  /// 첨부할 측정 결과의 식별자
  final String jobId;

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-04 18:15:24 · 박건준
  /// 함수: SendEmailSheet
  /// 목적: 시트가 보낼 측정 결과를 받는다.
  /// 인자: jobId — 첨부할 측정 결과의 식별자
  const SendEmailSheet({super.key, required this.jobId});

  @override
  State<SendEmailSheet> createState() => _SendEmailSheetState();
}

/// 작성: 2026-08-19 10:33:43 · 박건준
/// 수정: 2026-10-22 09:30:00 · 박건준
/// 클래스: _SendEmailSheetState
/// 목적: 이메일 발송 바텀 시트의 상태를 관리한다. 등록된 수신 이메일
///       가운데 받을 주소를 여러 개 고르게 하고, 보낼 항목을 선택받아
///       발송을 실행한다. 보낸 주소는 기억해 다음에 미리 골라 둔다.
///       보낼 수 있는 항목은 PDF 리포트, 로우 데이터(`raw.txt`, 256Hz
///       격자에 맞춘 필터 · 기준선 보정 전 값에서 축별 평균만 뺀 값),
///       현장 소음 녹음
///       (`noise.m4a`, 2026-10-18 사용자 결정) 셋이다. 안드로이드 센서
///       원본 이벤트 기록(`native_raw.txt`)은 기기 측정 폴더에만 남기고
///       보내지 않는다 (2026-10-08 결정. 2026-10-07 에는 두 원본 파일을
///       모두 보내지 않기로 했었다). 소음 진단 산출물(데시벨 CSV ·
///       마이크 원본 PCM)은 기능을 뺐다 — 예전 빌드가 기기에 남긴 진단
///       폴더가 있어도 찾지 않는다(2026-10-15 결정).
class _SendEmailSheetState extends State<SendEmailSheet> {
  /// PDF 리포트를 보낼 항목에 포함할지 여부
  bool _sendPdf = true;

  /// 로우 데이터(`raw.txt`)를 보낼 항목에 포함할지 여부
  bool _sendRaw = true;

  /// 현장 소음 녹음(`noise.m4a`)을 보낼 항목에 포함할지 여부
  bool _sendNoise = true;

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
  /// 수정: 2026-10-04 16:44:32 · 박건준
  /// 함수: initState
  /// 목적: 이 시트가 화면에 나타날 때 한 번, 저장된 수신 이메일과 지난번
  ///       보낸 주소를 불러와 화면에 표시한다.
  @override
  void initState() {
    super.initState();
    _loadRecipients(); // → 로직 이동: _loadRecipients()
  }

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-04 16:44:32 · 박건준
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

  /// 작성: 2026-10-04 16:44:32 · 박건준
  /// 함수: _recipients
  /// 목적: 고른 주소를 설정에 등록된 차례대로 늘어놓는다. 메일 앱에 넘기는
  ///       수신자 목록이다.
  /// 반환: 받을 주소 목록
  List<String> _recipients() =>
      _emails.where(_selected.contains).toList(growable: false);

  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-23 00:20:00 · 박건준
  /// 함수: _send
  /// 목적: "보내기" 버튼을 눌렀을 때 실행된다. 수신 이메일이 하나도
  ///       등록되지 않았으면 등록 안내 대화상자를 띄우고 멈춘다. 등록되어
  ///       있으면 보낼 메일의 제목·본문·수신자·첨부파일을 정하고
  ///       (`MailService.buildJobEmail()`), 기기에
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
      // → 로직 이동: MailService.buildJobEmail()
      final email = await MailService.buildJobEmail(
        jobId: widget.jobId,
        items: <MailItem>{
          if (_sendPdf) MailItem.report,
          if (_sendRaw) MailItem.raw,
          if (_sendNoise) MailItem.noise,
        },
        recipients: _recipients(), // → 로직 이동: _recipients()
      ); // 조립한 메일

      await MailService.send(email); // → 로직 이동: MailService.send()

      if (!mounted) return;
      Navigator.of(context).pop();
      // 메일 앱 선택 창을 취소해도 안드로이드가 알려 주지 않아 여기로 온다.
      // "작성창이 열렸다" 고 단정하지 않고 실제로 한 일만 적는다(2026-10-22)
      showSuccessSnackBar(context, '첨부를 준비해 메일 앱 선택 창을 열었습니다');
    } catch (e) {
      if (!mounted) return;
      final message = // 화면에 보여줄 실패 안내 문구
          '메일에 넣을 자료를 준비하지 못했습니다.\n$e';
      showErrorSnackBar(context, message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 작성: 2026-10-04 13:37:23 · 박건준
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

  /// 작성: 2026-10-04 13:37:23 · 박건준
  /// 수정: 2026-10-18 10:12:30 · 박건준
  /// 함수: build
  /// 목적: 이메일 발송 시트를 그린다. 위에서부터 순서대로 놓는다.
  ///       1. 제목과 닫기 버튼
  ///       2. 받는 사람 — 등록된 이메일마다 체크 한 줄. 여러 개 고를 수
  ///          있다. "관리"를 누르면 설정 화면으로 간다
  ///       3. 보낼 항목 체크 목록 (PDF 리포트, 로우 데이터, 현장 소음).
  ///          셋 다 처음에 체크돼 있다. 안드로이드
  ///          원본(2026-10-08 결정)과 소음 진단 산출물(2026-10-15 결정)은
  ///          보낼 항목이 아니라 목록에 없다
  ///       4. 고를 것이 빠졌을 때의 안내와 "보내기" 버튼
  ///       2 · 3 은 함께 스크롤되고 4 는 아래에 고정한다. 시트 아래쪽
  ///       시스템 영역은 `showAppSheet()` 가 비켜 준다.
  /// 인자: context — 이 시트가 화면 어디에 놓이는지 알려주는 값
  /// 반환: 화면 높이의 일정 비율을 차지하는 시트 내용
  @override
  Widget build(BuildContext context) {
    final noItem = // 보낼 항목을 하나도 안 골랐는지
        !_sendPdf && !_sendRaw && !_sendNoise;
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

                    // 3. 보낼 항목
                    const SizedBox(height: AppDims.gap3),
                    Text('보낼 항목', style: AppText.bodyBold),
                    _buildCheckboxItem(
                      title: 'PDF 리포트',
                      value: _sendPdf,
                      onChanged: (val) =>
                          setState(() => _sendPdf = val ?? false),
                    ),
                    _buildCheckboxItem(
                      title: '로우 데이터 (raw.txt)',
                      value: _sendRaw,
                      onChanged: (val) =>
                          setState(() => _sendRaw = val ?? false),
                    ),
                    _buildCheckboxItem(
                      title: '현장 소음 (m4a)',
                      value: _sendNoise,
                      onChanged: (val) =>
                          setState(() => _sendNoise = val ?? false),
                    ),
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
