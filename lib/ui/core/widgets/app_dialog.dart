import 'package:flutter/material.dart';
import '../theme.dart';

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 클래스: AppDialogButton
/// 목적: 어르신 UX(최소 터치 타깃 56dp)를 준수하는 공용 다이얼로그/액션
///       버튼이다. Semantics(화면 낭독기 등 보조기술에 역할·상태를
///       알려주는 Flutter 위젯)(button: true, label)와
///       SizedBox(height: AppDims.touchMin)를 자동으로 감싼다.
class AppDialogButton extends StatelessWidget {
  /// 버튼 라벨 문자열 (Semantics 및 텍스트 표시에 사용)
  final String label;

  /// 눌렀을 때 실행할 동작
  final VoidCallback? onPressed;

  /// 주 행동(ElevatedButton) 여부. false이면 보조 행동(TextButton)으로 그려진다.
  final bool primary;

  /// 위험/삭제/중단 등 경고성 행동 여부. true일 경우 빨간 배경 또는 글자색 적용.
  final bool isDestructive;

  /// 따로 지정하는 텍스트 색상 (지정하지 않으면 primary/isDestructive에 맞게 기본값 적용)
  final Color? textColor;

  /// 좌측 아이콘 (지정 시 icon 버튼 형태로 그려진다)
  final IconData? icon;

  /// 좌측 아이콘 색상
  final Color? iconColor;

  /// 아이콘 크기
  final double? iconSize;

  /// 따로 지정하는 텍스트 스타일 (지정하지 않으면 AppText.bodyBold 기준)
  final TextStyle? textStyle;

  /// 따로 지정하는 내부 패딩 (지정하지 않으면 기본 좌우 gap2)
  final EdgeInsetsGeometry? padding;

  /// 작성: 2026-08-06 15:59:06 · 박건준
  /// 함수: AppDialogButton
  /// 목적: 버튼에 필요한 값을 받아 위젯을 만든다. 각 인자의 의미는 위
  ///       필드 설명을 따른다.
  /// 인자: label, onPressed, primary, isDestructive, textColor, icon,
  ///       iconColor, iconSize, textStyle, padding
  const AppDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.isDestructive = false,
    this.textColor,
    this.icon,
    this.iconColor,
    this.iconSize,
    this.textStyle,
    this.padding,
  });

  /// 작성: 2026-08-06 15:59:06 · 박건준
  /// 수정: 2026-10-04 13:37:23 · nada
  /// 함수: build
  /// 목적: primary·isDestructive·icon 여부에 따라 ElevatedButton 또는
  ///       TextButton으로 그린다.
  @override
  Widget build(BuildContext context) {
    final Color defaultColor =
        isDestructive // isDestructive·primary 조합별 기본 글자색
        ? (primary ? AppColors.onDark : AppColors.red)
        : (primary ? AppColors.onDark : AppColors.navy);
    final Color effectiveColor = textColor ?? defaultColor; // 실제로 쓸 글자색

    final TextStyle effectiveStyle = (textStyle ?? AppText.bodyBold).copyWith(
      color: effectiveColor,
    ); // 실제로 쓸 텍스트 스타일

    final Widget textWidget = Text(
      // 라벨 텍스트 위젯
      label,
      style: !primary || isDestructive || textColor != null || textStyle != null
          ? effectiveStyle
          : null,
    );

    Widget buttonWidget; // 최종적으로 반환할 버튼 위젯
    if (primary) {
      final style = ElevatedButton.styleFrom(
        // primary 버튼 스타일
        backgroundColor: isDestructive ? AppColors.red : AppColors.blue,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: AppDims.gap2),
      );
      if (icon != null) {
        buttonWidget = ElevatedButton.icon(
          onPressed: onPressed,
          style: style,
          icon: Icon(
            icon,
            size: iconSize ?? AppDims.iconS,
            color: iconColor ?? effectiveColor,
          ),
          label: textWidget,
        );
      } else {
        buttonWidget = ElevatedButton(
          onPressed: onPressed,
          style: isDestructive || padding != null ? style : null,
          child: textWidget,
        );
      }
    } else {
      final style = padding != null
          ? TextButton.styleFrom(
              padding: padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDims.radius),
              ),
            )
          : null;
      if (icon != null) {
        buttonWidget = TextButton.icon(
          onPressed: onPressed,
          style: style,
          icon: Icon(
            icon,
            size: iconSize ?? AppDims.iconS,
            color: iconColor ?? effectiveColor,
          ),
          label: textWidget,
        );
      } else {
        buttonWidget = TextButton(
          onPressed: onPressed,
          style: style,
          child: textWidget,
        );
      }
    }

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(height: AppDims.touchMin, child: buttonWidget),
    );
  }
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 수정: 2026-10-04 13:37:23 · nada
/// 클래스: AppDialogIconButton
/// 목적: 어르신 UX(최소 터치 타깃 56dp x 56dp)를 준수하는 아이콘 전용
///       버튼이다.
class AppDialogIconButton extends StatelessWidget {
  /// 아이콘 종류
  final IconData icon;

  /// 화면 낭독기에 읽어 줄 이름이자, 길게 누르면 뜨는 설명 문구
  final String label;

  /// 눌렀을 때 실행할 동작
  final VoidCallback? onPressed;

  /// 아이콘 색상
  final Color? color;

  /// 아이콘 크기 (기본값 `AppDims.iconM`)
  final double size;

  /// 작성: 2026-08-06 15:59:06 · 박건준
  /// 수정: 2026-10-04 13:37:23 · nada
  /// 함수: AppDialogIconButton
  /// 목적: 아이콘 버튼에 필요한 값을 받아 위젯을 만든다. 각 인자의
  ///       의미는 위 필드 설명을 따른다.
  /// 인자: icon, label, onPressed, color, size
  const AppDialogIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.size = AppDims.iconM,
  });

  /// 작성: 2026-08-06 15:59:06 · 박건준
  /// 함수: build
  /// 목적: 최소 터치 영역을 보장하는 SizedBox로 IconButton을 감싼다.
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: AppDims.touchMin,
        height: AppDims.touchMin,
        child: IconButton(
          icon: Icon(icon, size: size, color: color),
          tooltip: label,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 수정: 2026-10-04 13:37:23 · nada
/// 함수: showAppConfirmDialog
/// 목적: 제목 · 문구 · 버튼 한두 개로 된 대화상자를 띄우고 사용자의
///       선택을 돌려준다. 측정 중단 확인, 측정 실패 · 중단 안내, 이메일
///       등록 안내가 같은 모양을 쓴다. 버튼을 누른 뒤 할 일(화면 이동
///       등)은 돌려받은 값을 보고 부르는 쪽이 한다.
/// 인자: context — 대화상자를 띄울 화면의 위치 정보
///       title — 제목
///       message — 본문 문구. 줄바꿈 문자로 여러 줄을 쓸 수 있다
///       confirmLabel — 확인 버튼 라벨
///       cancelLabel — 취소 버튼 라벨. null 이면 확인 버튼 하나만 둔다
///       isDestructive — 확인 버튼을 위험 행동 색(빨강)으로 칠할지
///       barrierDismissible — 바깥을 눌러 닫을 수 있는지. 기본 false
/// 반환: 확인을 누르면 true. 취소를 누르거나 바깥을 눌러 닫으면 false
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  bool barrierDismissible = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppText.subhead),
      content: Text(message, style: AppText.body),
      actions: [
        if (cancelLabel != null)
          AppDialogButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
            primary: false,
          ),
        AppDialogButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(ctx).pop(true),
          isDestructive: isDestructive,
        ),
      ],
    ),
  ); // 누른 버튼. 바깥을 눌러 닫았으면 null
  return confirmed ?? false;
}
