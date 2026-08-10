import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';
import 'package:vibration_checker/adapter/auth_repository.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';

/// S6 설정 화면
/// - 사용자 프로필 정보 및 결과 수신 이메일 설정, 앱 정보 조회 및 로그아웃
/// - 어르신 UX: 64dp 주 행동 버튼, 3중 상태 오류 표시, 최소 56dp+ 터치 영역
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// 설정 화면의 상태, 사용자 사번 기반 이메일 설정 영구 저장 및 로그아웃 로직을 관리합니다.
class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _emailCtl;
  final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtl = TextEditingController();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final id = AuthRepository.instance.currentUserId;
    if (id == null) return;
    final savedEmail = await PrefsStore.instance.loadEmail(id);
    if (savedEmail != null && mounted) {
      _emailCtl.text = savedEmail;
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtl.text.trim();

    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = '올바른 이메일 형식을 입력하세요.');
      return;
    }

    final id = AuthRepository.instance.currentUserId;
    if (id != null) {
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
              child: Text(
                '저장되었습니다',
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
      appBar: AppBar(
        title: const Text('설정'),
      ),
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
              SizedBox(
                height: AppDims.buttonH,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('저장'),
                ),
              ),
              const SizedBox(height: AppDims.gap3),

              // 3. 앱 버전 및 문의하기
              _buildListTile(
                title: '앱 버전',
                trailingText: '1.0.0',
              ),
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
