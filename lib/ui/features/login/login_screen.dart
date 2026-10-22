import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration_checker/adapter/storage/login_store.dart';
import 'package:vibration_checker/domain/auth/worker_directory.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/core/widgets/app_layout.dart';
import 'package:vibration_checker/ui/core/widgets/app_snack_bar.dart';

/// 작성: 2026-10-18 09:41:12 · nada
/// 클래스: LoginScreen
/// 목적: 로그인 화면. 사번 · 비밀번호를 받아 `LoginStore.login()` 에 넘기고,
///       받아 주면 홈으로 간다. 로그인 전에는 라우터(router.dart)가 모든
///       화면을 이 화면으로 돌린다. 판정은 `WorkerDirectory` 가 하고 이
///       화면은 사유에 맞는 문구와 옮겨 갈 입력칸만 고른다.
class LoginScreen extends StatefulWidget {
  /// 작성: 2026-10-18 09:41:12 · nada
  /// 함수: LoginScreen
  /// 목적: 로그인 화면을 만든다.
  /// 인자: store — 로그인을 맡길 저장소. 안 주면 `LoginStore.instance`.
  ///       시험은 가짜 명단을 읽는 저장소를 준다
  const LoginScreen({super.key, this.store});

  /// 로그인을 맡길 저장소. null 이면 `LoginStore.instance`
  final LoginStore? store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// 작성: 2026-10-18 09:41:12 · nada
/// 클래스: _LoginScreenState
/// 목적: 로그인 화면의 입력 · 오류 문구 · 진행 중 상태를 관리한다.
class _LoginScreenState extends State<LoginScreen> {
  /// 사번 입력창 컨트롤러(입력창 글자를 코드에서 읽고 쓰는 객체)
  final _idCtl = TextEditingController();

  /// 비밀번호 입력창 컨트롤러
  final _passwordCtl = TextEditingController();

  /// 오류가 나면 커서를 옮겨 줄 비밀번호 입력창의 초점 담당 객체
  final _passwordFocus = FocusNode();

  /// 사번 입력창 아래 오류 문구. 오류가 없으면 null
  String? _idError;

  /// 비밀번호 입력창 아래 오류 문구. 오류가 없으면 null
  String? _passwordError;

  /// 로그인 판정을 기다리는 중인지. 그동안 버튼을 꺼 두 번 누르지 않게 한다
  bool _busy = false;

  /// 작성: 2026-10-18 09:41:12 · nada
  /// 함수: dispose
  /// 목적: 화면이 사라질 때 입력 컨트롤러 · 초점 객체를 해제한다.
  @override
  void dispose() {
    _idCtl.dispose();
    _passwordCtl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// 작성: 2026-10-18 09:41:12 · nada
  /// 함수: _submit
  /// 목적: "로그인" 을 눌렀을 때 판정을 맡기고 결과에 따라 화면을 고른다.
  ///       - 받아 주면 홈으로 간다
  ///       - 사번 쪽 사유(비었음 · 명단에 없음)면 사번 칸에, 비밀번호 쪽
  ///         사유면 비밀번호 칸에 문구를 띄운다
  ///       - 명단을 읽지 못하면(자산 없음 · 형식 오류) 오류 알림을 띄운다
  ///         — 앱을 다시 설치해야 하는 문제라 입력칸 문구로 보이지 않는다
  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus(); // 키보드를 내린다
    setState(() {
      _busy = true;
      _idError = null;
      _passwordError = null;
    });
    final store = widget.store ?? LoginStore.instance; // 로그인을 맡길 저장소
    final LoginResult result; // 판정 결과
    try {
      // → 로직 이동: LoginStore.login()
      result = await store.login(_idCtl.text, _passwordCtl.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, '작업자 명단을 읽지 못했습니다.\n$e');
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result.failure) {
      case null:
        context.go('/home'); // → 로직 이동: HomeScreen.build()
      case LoginFailure.idMissing:
        setState(() => _idError = '사번을 입력하세요.');
      case LoginFailure.unknownId:
        setState(() => _idError = '등록되지 않은 사번입니다.');
      case LoginFailure.passwordMissing:
        setState(() => _passwordError = '비밀번호를 입력하세요.');
        _passwordFocus.requestFocus();
      case LoginFailure.wrongPassword:
        setState(() => _passwordError = '비밀번호가 맞지 않습니다.');
        _passwordCtl.clear();
        _passwordFocus.requestFocus();
    }
  }

  /// 작성: 2026-10-18 09:41:12 · nada
  /// 수정: 2026-10-22 12:50:00 · nada
  /// 함수: build
  /// 목적: 사번 → 비밀번호 입력칸을 세로로 두고 아래에 "로그인" 버튼을
  ///       고정한다. 버튼은 키보드가 열리면 그 위로 올라온다. 뒤로 갈 화면이
  ///       없어 앱바에 뒤로 버튼을 두지 않는다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 화면 전체 틀
      appBar: AppBar(
        title: const Text('로그인'),
        automaticallyImplyLeading: false,
      ),
      body: AppScrollBody(
        children: [
          Text('OTIS V-Check', style: AppText.title),
          const SizedBox(height: AppDims.gap),
          Text('작업자 사번으로 로그인하세요', style: AppText.caption),
          const SizedBox(height: AppDims.gap3),
          Text('사번', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          TextField(
            controller: _idCtl,
            style: AppText.body,
            // 영문 · 숫자 키보드를 띄운다. 한글 상태로 누른 낱자는
            // `WorkerDirectory.normalizeId()` 가 다시 영문으로 바꾼다
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: '예: T00000',
              errorText: _idError,
              prefixIcon: Icon(
                _idError != null ? Icons.error_outline : Icons.badge_outlined,
                color: _idError != null ? AppColors.red : AppColors.textSub,
              ),
            ),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: AppDims.gap2),
          Text('비밀번호', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          TextField(
            controller: _passwordCtl,
            focusNode: _passwordFocus,
            style: AppText.body,
            keyboardType: TextInputType.visiblePassword,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '비밀번호',
              errorText: _passwordError,
              prefixIcon: Icon(
                _passwordError != null
                    ? Icons.error_outline
                    : Icons.lock_outline,
                color: _passwordError != null
                    ? AppColors.red
                    : AppColors.textSub,
              ),
            ),
            onSubmitted: (_) => _submit(), // → 로직 이동: _submit()
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        // 화면 아래 고정 "로그인" 버튼. 사번 · 비밀번호를 넣는 동안 키보드에
        // 가려지지 않게 키보드 위로 올린다(2026-10-22 에뮬레이터 확인)
        liftAboveKeyboard: true,
        child: ElevatedButton(
          onPressed: _busy ? null : _submit, // → 로직 이동: _submit()
          child: Text(_busy ? '확인 중…' : '로그인'),
        ),
      ),
    );
  }
}
