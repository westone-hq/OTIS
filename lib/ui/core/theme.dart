import 'package:flutter/material.dart';

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 수정: 2026-10-04 13:37:23 · nada
/// 클래스: AppColors
/// 목적: 디자인 토큰(화면 전체가 같이 쓰는 색 · 치수 · 글자 값) — 앱의
///       모든 색은 여기만 참조한다. 화면 코드에서 `Color(0x...)` 숫자나
///       투명도 숫자를 직접 쓰지 않는다.
abstract final class AppColors {
  /// 기본 브랜드 색 (앱바, 주요 버튼 배경 등)
  static const navy = Color(0xFF1F3864);

  /// 보조 행동 색 (보조 버튼, 강조 텍스트 등)
  static const blue = Color(0xFF2E75B6);

  /// 경고·기준 초과 색
  static const red = Color(0xFFC00000);

  /// 정상·통과 색
  static const green = Color(0xFF2E7D32);

  /// 주의 색 (절제해서 사용)
  static const gold = Color(0xFFBF9000);

  /// 기본 본문 글자색
  static const text = Color(0xFF1A1A1A);

  /// 보조 설명 글자색
  static const textSub = Color(0xFF595959);

  /// 화면 배경색
  static const bg = Color(0xFFFFFFFF);

  /// 카드 등 표면 배경색
  static const surface = Color(0xFFF4F6F8);

  /// 테두리·구분선 색
  static const border = Color(0xFFD9D9D9);

  /// 남색 · 파랑 · 빨강 바탕 위에 놓는 글자 · 아이콘 색
  static const onDark = Color(0xFFFFFFFF);

  /// 남색 바탕 위 보조 글자색. `onDark` 의 70% 불투명도
  static const onDarkSub = Color(0xB3FFFFFF);

  /// 오류 안내 박스 바탕. `red` 의 8% 불투명도
  static const redTint = Color(0x14C00000);

  /// 주의 안내 박스 바탕. `gold` 의 8% 불투명도
  static const goldTint = Color(0x14BF9000);

  /// 그림 속 옅은 윤곽선. `navy` 의 20% 불투명도
  static const navyFaint = Color(0x331F3864);
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 수정: 2026-10-04 13:37:23 · nada
/// 클래스: AppDims
/// 목적: 디자인 토큰 — 앱의 모든 치수는 여기만 참조한다. 화면 코드에서
///       숫자를 직접 쓰지 않는다. 단위는 모두 dp(기기 화면 밀도와 상관없이
///       같은 크기로 보이게 하는 길이 단위)다. 간격은 8dp 단위로 맞춘다.
abstract final class AppDims {
  /// 붙어 있는 두 줄 사이 간격 (4dp)
  static const gapHalf = 4.0;

  /// 기본 간격 (8dp)
  static const gap = 8.0;

  /// 간격 2배 (16dp)
  static const gap2 = 16.0;

  /// 간격 3배 (24dp)
  static const gap3 = 24.0;

  /// 간격 5배 (40dp)
  static const gap5 = 40.0;

  /// 간격 6배 (48dp). 스크롤 본문 끝 여백
  static const gap6 = 48.0;

  /// 화면 좌우 여백
  static const screenPad = 24.0;

  /// 넓은 화면에서 본문이 늘어날 수 있는 최대 폭
  static const contentMaxWidth = 600.0;

  /// 모서리 - 전부 12 고정
  static const radius = 12.0;

  /// 터치 타깃 최소 높이 (dp)
  static const touchMin = 56.0;

  /// 주 버튼 높이 (dp)
  static const buttonH = 64.0;

  /// 폭을 정해 두는 단독 버튼의 폭 (카운트다운 건너뛰기 등)
  static const wideButtonW = 220.0;

  /// 입력 필드 높이
  static const fieldH = 64.0;

  /// 입력 필드 안쪽 위아래 여백
  static const fieldPadV = 20.0;

  /// 정보 행 · 체크 항목 한 줄의 최소 높이
  static const rowMinH = 64.0;

  /// 선택 카드 높이 (대기 시간 선택 등)
  static const choiceCardH = 72.0;

  /// 단계 번호 원의 지름
  static const badgeSize = 40.0;

  /// 기본 테두리 두께 (카드 · 선택지 · 버튼 윤곽)
  static const borderW = 1.5;

  /// 강조 테두리 두께 (입력 포커스 · 오류)
  static const borderWThick = 2.0;

  /// 작은 아이콘 크기 (글자 옆 보조 표시)
  static const iconXs = 18.0;

  /// 기본 아이콘 크기
  static const iconS = 24.0;

  /// 큰 아이콘 크기 (안내 박스 · 선택 카드)
  static const iconM = 28.0;

  /// 그림용 아이콘 크기
  static const iconL = 36.0;

  /// 바텀 시트 높이. 화면 높이에 곱하는 비율
  static const sheetHeightFactor = 0.75;

  /// 체크박스 확대 배율. 기본 크기는 어르신이 누르기 작다
  static const checkboxScale = 1.4;

  /// 진행 표시 원의 선 두께
  static const spinnerStroke = 2.5;
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 수정: 2026-10-04 13:37:23 · nada
/// 클래스: AppText
/// 목적: 디자인 토큰 — 앱의 모든 글자 스타일은 여기만 참조한다. 화면
///       코드에서 글자 크기를 직접 쓰지 않는다. 어르신도 읽기 쉽도록
///       본문은 18sp(글자 크기 단위) 이상, 캡션은 16sp 이상으로 둔다.
abstract final class AppText {
  /// 캡션(부가 설명) 글자 스타일. 16sp
  static const caption = TextStyle(fontSize: 16, color: AppColors.textSub);

  /// 본문 글자 스타일. 18sp
  static const body = TextStyle(fontSize: 18, color: AppColors.text);

  /// 강조 본문 글자 스타일. 18sp, 굵게
  static const bodyBold = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  /// 소제목 글자 스타일. 22sp, 굵게
  static const subhead = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  /// 제목 글자 스타일. 28sp, 굵게, navy 색
  static const title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
  );

  /// 큰 숫자(경과 시간 등) 글자 스타일. 44sp, 굵게
  static const bigNumber = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  /// 카운트다운 숫자 글자 스타일. 120sp, 굵게, 파랑
  static const countdown = TextStyle(
    fontSize: 120,
    fontWeight: FontWeight.w700,
    color: AppColors.blue,
  );

  /// 버튼 글자 스타일. 20sp, 굵게, 흰색
  static const button = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.onDark,
  );
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 수정: 2026-10-04 13:37:23 · nada
/// 함수: buildAppTheme
/// 목적: 앱 전역에서 쓰는 `ThemeData`(버튼 · 입력창 등 기본 위젯이
///       따르는 색 · 모양 설정 묶음)를 만든다. 버튼 · 입력창 · 스낵바 등
///       공용 위젯의 색과 모양을 여기서 한 번에 정한다.
/// 반환: 완성된 `ThemeData`
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
      titleTextStyle: AppText.subhead,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.onDark,
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
        side: const BorderSide(color: AppColors.navy, width: AppDims.borderW),
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
        vertical: AppDims.fieldPadV,
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
        borderSide: const BorderSide(
          color: AppColors.blue,
          width: AppDims.borderWThick,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        borderSide: const BorderSide(
          color: AppColors.red,
          width: AppDims.borderWThick,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
        borderSide: const BorderSide(
          color: AppColors.red,
          width: AppDims.borderWThick,
        ),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navy,
      contentTextStyle: AppText.body.copyWith(color: AppColors.onDark),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDims.radius),
      ),
    ),
  );
}
