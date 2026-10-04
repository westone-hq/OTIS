import 'package:flutter/material.dart';
import 'package:vibration_checker/adapter/prefs_store.dart';

import '../../core/theme.dart';

/// 작성: 2026-08-19 10:57:06 · 박건준
/// 수정: 2026-10-04 13:26:44 · nada
/// 클래스: SettingsScreen
/// 목적: 설정 화면. 결과 수신 이메일 등록과 앱 버전 확인을 한 화면에서
///       처리한다. 어르신도 쓰기 편하도록 버튼 높이를 64dp 이상으로
///       두고, 오류는 테두리 색 · 아이콘 · 문구 3중으로 겹쳐 보여준다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// 작성: 2026-08-19 10:57:06 · 박건준
/// 수정: 2026-10-04 13:26:44 · nada
/// 클래스: _SettingsScreenState
/// 목적: 설정 화면의 상태를 관리한다. 이메일 등록값을 불러오고 저장한다.
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

  /// 작성: 2026-08-19 10:57:06 · 박건준
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

  /// 작성: 2026-08-19 10:57:06 · 박건준
  /// 수정: 2026-10-04 13:26:44 · nada
  /// 함수: _loadEmail
  /// 목적: 저장된 이메일이 있으면 불러와 입력창에 채운다. 저장된 적이
  ///       없으면 입력창을 빈 채로 둔다.
  Future<void> _loadEmail() async {
    // → 로직 이동: PrefsStore.loadEmail()
    final savedEmail = await PrefsStore.instance.loadEmail(); // 저장된 이메일
    if (savedEmail != null && mounted) {
      _emailCtl.text = savedEmail;
    }
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
  /// 수정: 2026-10-04 13:26:44 · nada
  /// 함수: _save
  /// 목적: "저장" 버튼을 눌렀을 때 실행된다. 입력한 이메일이
  ///       `name@example.com`처럼 "@" 앞뒤에 글자가 있고 "@" 뒤에
  ///       마침표가 하나 더 있는 형식인지 검사하고, 아니면 입력창
  ///       아래에 오류 문구를 띄우고 멈춘다. 형식이 맞으면 저장하고,
  ///       저장 완료를 알리는 안내를 띄운다.
  Future<void> _save() async {
    FocusScope.of(context).unfocus(); // 키보드를 내린다
    final email = _emailCtl.text.trim(); // 입력창에 적힌 이메일(양끝 공백 제거)

    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = '올바른 이메일 형식을 입력하세요.');
      return;
    }

    // → 로직 이동: PrefsStore.saveEmail()
    await PrefsStore.instance.saveEmail(email);

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

  /// 작성: 2026-10-04 13:26:44 · nada
  /// 함수: _buildListTile
  /// 목적: 제목과 오른쪽 값 한 쌍을 보여주는 정보 행을 만든다.
  /// 인자: title — 왼쪽에 놓을 항목 이름
  ///       trailingText — 오른쪽에 놓을 값
  /// 반환: 정보 행 위젯
  Widget _buildListTile({required String title, required String trailingText}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDims.gap2,
        vertical: AppDims.gap,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDims.radius),
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
  /// 수정: 2026-10-04 13:26:44 · nada
  /// 함수: build
  /// 목적: 설정 화면을 그린다. 이메일 등록과 앱 버전을 세로로 배치한다.
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
              // 1. 결과 수신 이메일 설정 섹션
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

              // 2. 앱 버전
              _buildListTile(title: '앱 버전', trailingText: '1.0.0'),
            ],
          ),
        ),
      ),
    );
  }
}
