// 작성: 2026-08-19 10:57:06
// 작성자: 박건준

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import 'package:vibration_checker/adapter/auth_repository.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';

/// 클래스: SettingsScreen
/// 목적: 설정 화면. 사용자 프로필 정보, 결과 수신 이메일 등록, 앱
///       버전 확인, 로그아웃을 한 화면에서 처리한다. 어르신도 쓰기
///       편하도록 버튼 높이를 64dp 이상으로 두고, 오류는 테두리 색
///       · 아이콘 · 문구 3중으로 겹쳐 보여준다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// 클래스: _SettingsScreenState
/// 목적: 설정 화면의 상태를 관리한다. 로그인된 사용자 아이디를 기준으로
///       이메일 등록값을 불러오고 저장하며, 로그아웃 처리를 한다.
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

  /// 함수: initState
  /// 목적: 이 화면이 나타날 때 한 번, 입력 컨트롤러를 만들고 저장된
  ///       이메일을 불러와 입력창에 채운다.
  @override
  void initState() {
    super.initState();
    _emailCtl = TextEditingController();
    // → 로직 이동: _loadEmail()
    _loadEmail();
  }

  /// 함수: _loadEmail
  /// 목적: 지금 로그인된 사용자 앞으로 저장된 이메일이 있으면 불러와
  ///       입력창에 채운다. 로그인 정보가 없거나 저장된 적이 없으면
  ///       입력창을 빈 채로 둔다.
  Future<void> _loadEmail() async {
    // → 로직 이동: AuthRepository.currentUserId
    final id = AuthRepository.instance.currentUserId; // 로그인 사용자 식별자
    if (id == null) return;
    // → 로직 이동: PrefsStore.loadEmail()
    final savedEmail = await PrefsStore.instance.loadEmail(id); // 저장된 이메일
    if (savedEmail != null && mounted) {
      _emailCtl.text = savedEmail;
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  /// 함수: _save
  /// 목적: "저장" 버튼을 눌렀을 때 실행된다. 입력한 이메일이
  ///       `name@example.com`처럼 "@" 앞뒤에 글자가 있고 "@" 뒤에
  ///       마침표가 하나 더 있는 형식인지 검사하고, 아니면 입력창
  ///       아래에 오류 문구를 띄우고 멈춘다. 형식이 맞으면 로그인된
  ///       사용자 아이디에 연결해 저장하고, 저장 완료를 알리는
  ///       안내를 띄운다.
  Future<void> _save() async {
    FocusScope.of(context).unfocus(); // 키보드를 내린다
    final email = _emailCtl.text.trim(); // 입력창에 적힌 이메일(양끝 공백 제거)

    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = '올바른 이메일 형식을 입력하세요.');
      return;
    }

    // → 로직 이동: AuthRepository.currentUserId
    final id = AuthRepository.instance.currentUserId; // 로그인 사용자 식별자
    if (id != null) {
      // → 로직 이동: PrefsStore.saveEmail()
      await PrefsStore.instance.saveEmail(id, email);
    }

    setState(() => _error = null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.green),
            SizedBox(width: AppDims.gap),
            Expanded(
              child: Text('저장되었습니다', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
      ),
    );
  }

  void _showReadyNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('준비 중'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('로그아웃', style: AppText.subhead),
        content: Text('정말 로그아웃 하시겠습니까?', style: AppText.body),
        actions: [
          AppDialogButton(
            label: '취소',
            onPressed: () => Navigator.of(ctx).pop(false),
            primary: false,
          ),
          AppDialogButton(
            label: '로그아웃',
            onPressed: () => Navigator.of(ctx).pop(true),
            isDestructive: true,
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthRepository.instance.logout();
      if (!mounted) return;
      context.go('/login');
    }
  }

  Widget _buildProfileCard() {
    final userId = AuthRepository.instance.currentUserId ?? '미로그인';
    return Container(
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 40,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(width: AppDims.gap2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userId, style: AppText.bodyBold),
                const SizedBox(height: 4),
                Text(
                  'Otis 직원',
                  style: AppText.caption.copyWith(color: AppColors.textSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    String? trailingText,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      alignment: Alignment.center,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDims.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDims.gap2,
              vertical: AppDims.gap,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDims.radius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppText.body),
                if (trailingText != null)
                  Text(
                    trailingText,
                    style: AppText.bodyBold.copyWith(color: AppColors.textSub),
                  ),
                if (trailingIcon != null)
                  Icon(trailingIcon, color: AppColors.textSub),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 프로필 카드
              _buildProfileCard(),
              const SizedBox(height: AppDims.gap3),

              // 2. 결과 수신 이메일 설정 섹션
              Text('결과 수신 이메일', style: AppText.bodyBold),
              const SizedBox(height: AppDims.gap),
              TextField(
                controller: _emailCtl,
                keyboardType: TextInputType.emailAddress,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: '예: name@otis.com',
                  errorText: _error,
                  prefixIcon: Icon(
                    _error != null ? Icons.error_outline : Icons.email_outlined,
                    color: _error != null ? AppColors.red : AppColors.textSub,
                  ),
                ),
              ),
              const SizedBox(height: AppDims.gap),
              // 입력한 이메일을 형식 검사 후 저장
              SizedBox(
                height: AppDims.buttonH,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('저장'),
                ),
              ),
              const SizedBox(height: AppDims.gap3),

              // 3. 앱 버전 및 문의하기
              _buildListTile(title: '앱 버전', trailingText: '1.0.0'),
              const SizedBox(height: AppDims.gap),
              _buildListTile(
                title: '문의하기',
                trailingIcon: Icons.chevron_right,
                onTap: _showReadyNotice,
              ),
              const SizedBox(height: 48),

              // 4. 맨 아래 로그아웃 버튼
              SizedBox(
                height: AppDims.buttonH,
                child: OutlinedButton(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDims.radius),
                    ),
                  ),
                  child: Text(
                    '로그아웃',
                    style: AppText.bodyBold.copyWith(color: AppColors.red),
                  ),
                ),
              ),
              const SizedBox(height: AppDims.gap2),
            ],
          ),
        ),
      ),
    );
  }
}
