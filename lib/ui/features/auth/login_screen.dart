import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration_checker/adapter/auth_repository.dart';

import '../../core/theme.dart';

/// S1 로그인
/// - ID: Otis 사번(6자리 숫자) 또는 협력업체 T사번(T+5자리 숫자)
/// - PW: ID와 동일 (FR-2)
/// - 어르신 UX: 필드/버튼 64dp, 본문 18+, 오류는 색+아이콘+텍스트
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// 로그인 화면의 상태 및 사용자 인증 입력/제출 로직을 관리합니다.
class _LoginScreenState extends State<LoginScreen> {
  final _idCtl = TextEditingController();
  final _pwCtl = TextEditingController();
  final _pwFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idCtl.dispose();
    _pwCtl.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final id = _idCtl.text;
    final pw = _pwCtl.text;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await AuthRepository.instance.login(id, pw);
      if (!mounted) return;
      setState(() => _loading = false);
      context.go('/home');
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '로그인 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppDims.screenPad),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDims.gap3),
                  const Text(
                    'OTIS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppDims.gap),
                  Text(
                    '진동 측정',
                    textAlign: TextAlign.center,
                    style: AppText.subhead.copyWith(color: AppColors.textSub),
                  ),
                  const SizedBox(height: 48),

                  // 아이디
                  Text('아이디', style: AppText.bodyBold),
                  const SizedBox(height: AppDims.gap),
                  SizedBox(
                    height: AppDims.fieldH,
                    child: TextField(
                      controller: _idCtl,
                      style: AppText.body,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9Tt]'),
                        ),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        hintText: '사번 또는 T번호 (예: 123456 / T12345)',
                      ),
                      onSubmitted: (_) => _pwFocus.requestFocus(),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),
                  const SizedBox(height: AppDims.gap3),

                  // 비밀번호
                  Text('비밀번호', style: AppText.bodyBold),
                  const SizedBox(height: AppDims.gap),
                  SizedBox(
                    height: AppDims.fieldH,
                    child: TextField(
                      controller: _pwCtl,
                      focusNode: _pwFocus,
                      style: AppText.body,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: '비밀번호 입력',
                        suffixIcon: Semantics(
                          button: true,
                          label: _obscure ? '비밀번호 표시' : '비밀번호 숨김',
                          child: SizedBox(
                            width: 88,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 24,
                                color: AppColors.textSub,
                              ),
                              label: Text(
                                _obscure ? '표시' : '숨김',
                                style: AppText.caption,
                              ),
                            ),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),

                  // 오류: 색 + 아이콘 + 텍스트 3중 표시
                  if (_error != null) ...[
                    const SizedBox(height: AppDims.gap2),
                    Container(
                      padding: const EdgeInsets.all(AppDims.gap2),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppDims.radius),
                        border: Border.all(color: AppColors.red),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.red, size: 28),
                          const SizedBox(width: AppDims.gap2),
                          Expanded(
                            child: Text(
                              _error!,
                              style:
                                  AppText.body.copyWith(color: AppColors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 로그인 버튼 (64dp, full width)
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Text('로그인'),
                  ),

                  const SizedBox(height: AppDims.gap3),
                  Text(
                    '비밀번호는 아이디와 동일합니다',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                  const SizedBox(height: AppDims.gap3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
