import 'package:flutter/material.dart';
import '../theme.dart';

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 클래스: AppDialogButton
/// 목적: 어르신 UX(최소 터치 타깃 56dp)를 준수하는 공용 다이얼로그/액션
///       버튼이다. Semantics(button: true, label)와
///       SizedBox(height: AppDims.touchMin)를 자동으로 감싼다.
class AppDialogButton extends StatelessWidget {
  /// 버튼 라벨 문자열 (Semantics 및 텍스트 표시에 사용)
  final String label;

  /// 클릭 시 동작 콜백
  final VoidCallback? onPressed;

  /// 주 행동(ElevatedButton) 여부. false이면 보조 행동(TextButton)으로 렌더링.
  final bool primary;

  /// 위험/삭제/중단 등 경고성 행동 여부. true일 경우 빨간 배경 또는 글자색 적용.
  final bool isDestructive;

  /// 커스텀 텍스트 색상 (지정하지 않을 시 primary/isDestructive에 맞게 기본값 적용)
  final Color? textColor;

  /// 좌측 아이콘 (지정 시 icon 버튼 형태로 렌더링)
  final IconData? icon;

  /// 좌측 아이콘 색상
  final Color? iconColor;

  /// 아이콘 크기
  final double? iconSize;

  /// 커스텀 텍스트 스타일 (지정하지 않을 시 AppText.bodyBold 기준)
  final TextStyle? textStyle;

  /// 내부 패딩 커스텀 (지정하지 않을 시 기본 좌우 gap2)
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
  /// 함수: build
  /// 목적: primary·isDestructive·icon 여부에 따라 ElevatedButton 또는
  ///       TextButton으로 렌더링한다.
  @override
  Widget build(BuildContext context) {
    final Color defaultColor = isDestructive
        ? (primary ? Colors.white : AppColors.red)
        : (primary ? Colors.white : AppColors.navy);
    final Color effectiveColor = textColor ?? defaultColor;

    final TextStyle effectiveStyle = (textStyle ?? AppText.bodyBold).copyWith(
      color: effectiveColor,
    );

    final Widget textWidget = Text(
      label,
      style: !primary || isDestructive || textColor != null || textStyle != null
          ? effectiveStyle
          : null,
    );

    Widget buttonWidget;
    if (primary) {
      final style = ElevatedButton.styleFrom(
        backgroundColor: isDestructive ? AppColors.red : AppColors.blue,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: AppDims.gap2),
      );
      if (icon != null) {
        buttonWidget = ElevatedButton.icon(
          onPressed: onPressed,
          style: style,
          icon: Icon(
            icon,
            size: iconSize ?? 22,
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
            size: iconSize ?? 24,
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
      child: SizedBox(
        height: AppDims.touchMin,
        child: buttonWidget,
      ),
    );
  }
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 클래스: AppDialogIconButton
/// 목적: 어르신 UX(최소 터치 타깃 56dp x 56dp)를 준수하는 아이콘 전용
///       버튼이다.
class AppDialogIconButton extends StatelessWidget {
  /// 아이콘 종류
  final IconData icon;

  /// Semantics 라벨 및 툴팁 문자열
  final String label;

  /// 클릭 시 동작 콜백
  final VoidCallback? onPressed;

  /// 아이콘 색상
  final Color? color;

  /// 아이콘 크기 (기본값 28)
  final double size;

  /// 커스텀 툴팁 (지정하지 않을 시 label 사용)
  final String? tooltip;

  /// 작성: 2026-08-06 15:59:06 · 박건준
  /// 함수: AppDialogIconButton
  /// 목적: 아이콘 버튼에 필요한 값을 받아 위젯을 만든다. 각 인자의
  ///       의미는 위 필드 설명을 따른다.
  /// 인자: icon, label, onPressed, color, size, tooltip
  const AppDialogIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.size = 28,
    this.tooltip,
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
          tooltip: tooltip ?? label,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// 작성: 2026-08-06 15:59:06 · 박건준
/// 함수: showAppConfirmDialog
/// 목적: 반복되는 barrierDismissible: false + AlertDialog 골격을 간편하게
///       띄우는 확인 다이얼로그 헬퍼이다.
/// 인자: context — 다이얼로그를 띄울 화면의 BuildContext
///       title — 다이얼로그 제목 위젯
///       content — 다이얼로그 본문 위젯
///       confirmLabel — 확인 버튼 라벨
///       cancelLabel — 취소 버튼 라벨. null이면 취소 버튼을 만들지 않는다
///       onConfirm — 확인을 눌렀을 때 추가로 실행할 동작
///       onCancel — 취소를 눌렀을 때 추가로 실행할 동작
///       isDestructive — 확인 버튼을 위험 행동 색으로 표시할지 여부
///       barrierDismissible — 바깥을 눌러 닫을 수 있는지 여부, 기본 false
/// 반환: 사용자가 확인을 누르면 true, 취소나 바깥을 눌러 닫으면 false/null
Future<T?> showAppConfirmDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  required String confirmLabel,
  String? cancelLabel,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool isDestructive = false,
  bool barrierDismissible = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      title: title,
      content: content,
      actions: [
        if (cancelLabel != null)
          AppDialogButton(
            label: cancelLabel,
            onPressed: () {
              Navigator.of(ctx).pop(false as T?);
              onCancel?.call();
            },
            primary: false,
          ),
        AppDialogButton(
          label: confirmLabel,
          onPressed: () {
            Navigator.of(ctx).pop(true as T?);
            onConfirm?.call();
          },
          primary: true,
          isDestructive: isDestructive,
        ),
      ],
    ),
  );
}
