import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_layout.dart';
import '../../core/widgets/app_snack_bar.dart';

/// 작성: 2026-08-19 10:57:06 · 박건준
/// 수정: 2026-10-04 16:44:32 · nada
/// 클래스: SettingsScreen
/// 목적: 설정 화면. 결과 수신 이메일 목록 관리(추가 · 삭제)와 앱 버전
///       확인을 한 화면에서 처리한다. 어르신도 쓰기 편하도록 버튼 높이를 64dp 이상으로
///       두고, 오류는 테두리 색 · 아이콘 · 문구 3중으로 겹쳐 보여준다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// 작성: 2026-08-19 10:57:06 · 박건준
/// 수정: 2026-10-04 16:44:32 · nada
/// 클래스: _SettingsScreenState
/// 목적: 설정 화면의 상태를 관리한다. 수신 이메일 목록을 불러오고, 바꿀
///       때마다 통째로 저장한다.
class _SettingsScreenState extends State<SettingsScreen> {
  /// `TextEditingController`(입력창에 지금 적힌 글자를 코드에서 읽고
  /// 쓸 수 있게 연결해 주는 객체). 이메일 입력창에 연결해 두면,
  /// 사용자가 입력한 값을 `_emailCtl.text`로 읽거나 저장된 값을
  /// `_emailCtl.text = ...`로 채워 넣을 수 있다. 화면이 사라질 때
  /// dispose에서 반드시 해제해야 한다 — 안 하면 메모리에 계속 남는다
  late final TextEditingController _emailCtl;

  /// 이메일 형식 검사에 쓰는 정규식. "@"와 "."이 하나씩 있고 공백이
  /// 없는 문자열만 통과시킨다
  final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// 이메일 입력창 아래에 보여줄 오류 문구. 오류가 없으면 null
  String? _error;

  /// 등록된 수신 이메일 목록. `_loadEmails()` 가 채우고 `_add()` ·
  /// `_remove()` 가 고친다. 등록 차례대로다
  List<String> _emails = <String>[];

  /// 화면에 보여줄 앱 버전 문구. `_loadVersion()`이 채운다. 읽기 전이면
  /// null
  String? _version;

  /// 작성: 2026-08-19 10:57:06 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: initState
  /// 목적: 이 화면이 나타날 때 한 번, 입력 컨트롤러를 만들고 저장된
  ///       이메일 목록과 앱 버전을 불러와 화면에 채운다.
  @override
  void initState() {
    super.initState();
    _emailCtl = TextEditingController();
    _loadEmails(); // → 로직 이동: _loadEmails()
    _loadVersion(); // → 로직 이동: _loadVersion()
  }

  /// 작성: 2026-10-04 13:28:35 · nada
  /// 함수: _loadVersion
  /// 목적: 설치된 앱의 버전을 읽어 화면에 채운다. 버전은 `pubspec.yaml`
  ///       의 `version:` 한 곳에서만 정하고, 빌드할 때 앱에 새겨진 값을
  ///       그대로 읽는다. 읽지 못하면 "확인 불가"를 보여준다.
  /// 근거: 표준 — `version: 1.0.0+1` 의 `+` 앞이 `PackageInfo.version`,
  ///       뒤가 `PackageInfo.buildNumber` 다 (Flutter 빌드 규칙)
  Future<void> _loadVersion() async {
    String version; // 화면에 보여줄 버전 문구
    try {
      final info = await PackageInfo.fromPlatform(); // 설치된 앱 정보
      version = '${info.version} (${info.buildNumber})';
    } catch (_) {
      version = '확인 불가';
    }
    if (!mounted) return;
    setState(() => _version = version);
  }

  /// 작성: 2026-08-19 10:57:06 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: _loadEmails
  /// 목적: 저장된 수신 이메일 목록을 불러와 화면에 채운다.
  Future<void> _loadEmails() async {
    // → 로직 이동: PrefsStore.loadEmails()
    final saved = await PrefsStore.instance.loadEmails(); // 저장된 목록
    if (!mounted) return;
    setState(() => _emails = saved);
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 함수: dispose
  /// 목적: 화면이 사라질 때 입력 컨트롤러를 해제해 메모리 누수를 막는다.
  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  /// 작성: 2026-08-19 10:57:06 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: _add
  /// 목적: "추가" 버튼을 눌렀을 때 실행된다. 입력한 이메일이
  ///       `name@example.com`처럼 "@" 앞뒤에 글자가 있고 "@" 뒤에
  ///       마침표가 하나 더 있는 형식인지, 이미 목록에 있지 않은지(대소문자
  ///       무시) 검사한다. 걸리면 입력창 아래에 오류 문구를 띄우고 멈춘다.
  ///       통과하면 목록 끝에 붙여 저장하고 입력창을 비운다.
  Future<void> _add() async {
    FocusScope.of(context).unfocus(); // 키보드를 내린다
    final email = _emailCtl.text.trim(); // 입력창에 적힌 이메일(양끝 공백 제거)

    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = '올바른 이메일 형식을 입력하세요.');
      return;
    }
    final lower = email.toLowerCase(); // 중복 비교용 소문자 주소
    if (_emails.any((e) => e.toLowerCase() == lower)) {
      setState(() => _error = '이미 등록된 이메일입니다.');
      return;
    }

    final next = <String>[..._emails, email]; // 새로 저장할 목록
    // → 로직 이동: PrefsStore.saveEmails()
    await PrefsStore.instance.saveEmails(next);
    if (!mounted) return;
    setState(() {
      _emails = next;
      _error = null;
      _emailCtl.clear();
    });
    showSuccessSnackBar(context, '추가되었습니다');
  }

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 함수: _remove
  /// 목적: 이메일 하나를 목록에서 지운다. 되돌릴 수 없어 먼저 확인을
  ///       받는다.
  /// 인자: email — 지울 주소
  Future<void> _remove(String email) async {
    // → 로직 이동: showAppConfirmDialog()
    final confirmed = await showAppConfirmDialog(
      context,
      title: '이메일 삭제',
      message: '$email\n이 주소를 목록에서 지울까요?',
      confirmLabel: '삭제',
      cancelLabel: '취소',
      isDestructive: true,
      barrierDismissible: true,
    ); // 삭제를 골랐는지
    if (!confirmed) return;

    final next = _emails.where((e) => e != email).toList(); // 지운 뒤 목록
    // → 로직 이동: PrefsStore.saveEmails()
    await PrefsStore.instance.saveEmails(next);
    if (!mounted) return;
    setState(() => _emails = next);
  }

  /// 작성: 2026-10-04 16:44:32 · nada
  /// 함수: _buildEmailRow
  /// 목적: 등록된 이메일 한 줄을 주소 + 삭제 버튼으로 만든다.
  /// 인자: email — 보여줄 주소
  /// 반환: 이메일 한 줄 위젯
  Widget _buildEmailRow(String email) {
    return AppCard(
      minHeight: AppDims.rowMinH,
      padding: const EdgeInsets.only(left: AppDims.gap2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              email,
              style: AppText.body,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppDialogIconButton(
            icon: Icons.delete_outline,
            label: '$email 삭제',
            color: AppColors.red,
            onPressed: () => _remove(email), // → 로직 이동: _remove()
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-10-04 13:26:44 · nada
  /// 함수: _buildListTile
  /// 목적: 제목과 오른쪽 값 한 쌍을 보여주는 정보 행을 만든다.
  /// 인자: title — 왼쪽에 놓을 항목 이름
  ///       trailingText — 오른쪽에 놓을 값
  /// 반환: 정보 행 위젯
  Widget _buildListTile({required String title, required String trailingText}) {
    return AppCard(
      minHeight: AppDims.rowMinH,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDims.gap2,
        vertical: AppDims.gap,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppText.body),
          Text(
            trailingText,
            style: AppText.bodyBold.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-07-03 15:21:58 · 박건준
  /// 수정: 2026-10-04 16:44:32 · nada
  /// 함수: build
  /// 목적: 설정 화면을 그린다. 수신 이메일 목록 → 추가 입력창 → 앱 버전
  ///       순으로 세로로 배치한다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: AppScrollBody(
        children: [
          // 1. 결과 수신 이메일 목록
          Text('결과 수신 이메일', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          if (_emails.isEmpty) Text('등록된 이메일이 없습니다', style: AppText.caption),
          for (final email in _emails) ...[
            _buildEmailRow(email), // → 로직 이동: _buildEmailRow()
            const SizedBox(height: AppDims.gap),
          ],
          const SizedBox(height: AppDims.gap),

          // 2. 새 이메일 추가
          TextField(
            controller: _emailCtl,
            keyboardType: TextInputType.emailAddress,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: '이메일 주소',
              errorText: _error,
              prefixIcon: Icon(
                _error != null ? Icons.error_outline : Icons.email_outlined,
                color: _error != null ? AppColors.red : AppColors.textSub,
              ),
            ),
            onSubmitted: (_) => _add(), // → 로직 이동: _add()
          ),
          const SizedBox(height: AppDims.gap),
          ElevatedButton(
            onPressed: _add, // → 로직 이동: _add()
            child: const Text('추가'),
          ),
          const SizedBox(height: AppDims.gap3),

          // 3. 앱 버전
          _buildListTile(title: '앱 버전', trailingText: _version ?? ''),
        ],
      ),
    );
  }
}
