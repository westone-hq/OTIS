import 'package:flutter/material.dart';

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 클래스: AppColors
/// 목적: 디자인 토큰 - 앱의 모든 색은 여기만 참조한다. 화면 코드에서
///       Color(0x...) 숫자 하드코딩을 금지한다.
abstract final class AppColors {
  static const navy = Color(0xFF1F3864); // primary
  static const blue = Color(0xFF2E75B6); // action
  static const red = Color(0xFFC00000); // alert / 기준 초과
  static const green = Color(0xFF2E7D32); // pass / 정상
  static const gold = Color(0xFFBF9000); // warning (절제 사용)
  static const text = Color(0xFF1A1A1A);
  static const textSub = Color(0xFF595959);
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF4F6F8);
  static const border = Color(0xFFD9D9D9);
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 클래스: AppDims
/// 목적: 디자인 토큰 - 앱의 모든 치수는 여기만 참조한다. 화면 코드에서
///       숫자 하드코딩을 금지한다.
abstract final class AppDims {
  /// 8dp 그리드
  static const gap = 8.0;
  static const gap2 = 16.0;
  static const gap3 = 24.0;

  /// 화면 좌우 여백
  static const screenPad = 24.0;

  /// 모서리 - 전부 12 고정
  static const radius = 12.0;

  /// 터치 타깃 최소 / 주 버튼 높이
  static const touchMin = 56.0;
  static const buttonH = 64.0;

  /// 입력 필드 높이
  static const fieldH = 64.0;
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 클래스: AppText
/// 목적: 디자인 토큰 - 앱의 모든 글자 스타일은 여기만 참조한다. 화면
///       코드에서 스타일 하드코딩을 금지한다.
abstract final class AppText {
  // 어르신 UX: 본문 18 미만 금지, 캡션 최소 16
  static const caption = TextStyle(fontSize: 16, color: AppColors.textSub);
  static const body = TextStyle(fontSize: 18, color: AppColors.text);
  static const bodyBold =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text);
  static const subhead =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text);
  static const title =
      TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy);
  static const bigNumber =
      TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: AppColors.text);
  static const button =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white);
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 함수: buildAppTheme
/// 목적: 앱 전역에서 쓰는 ThemeData를 만든다. 버튼·입력창·스낵바 등
///       공용 위젯의 색과 모양을 여기서 한 번에 정한다.
/// 반환: 완성된 ThemeData
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.blue,
      error: AppColors.red,
      surface: AppColors.bg,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        minimumSize: const Size.fromHeight(AppDims.buttonH),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDims.radius),
        ),
        textStyle: AppText.button,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size.fromHeight(AppDims.buttonH),
        side: const BorderSide(color: AppColors.navy, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDims.radius),
        ),
        textStyle: AppText.button.copyWith(color: AppColors.navy),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDims.gap2,
        vertical: 20,
      ),
      hintStyle: AppText.body.copyWith(color: AppColors.textSub),
      labelStyle: AppText.body.copyWith(color: AppColors.textSub),
      errorStyle: AppText.caption.copyWith(color: AppColors.red),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        borderSide: const BorderSide(color: AppColors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        borderSide: const BorderSide(color: AppColors.red, width: 2),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navy,
      contentTextStyle: AppText.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
      ),
    ),
  );
}
