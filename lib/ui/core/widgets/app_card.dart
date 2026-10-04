import 'package:flutter/material.dart';

import '../theme.dart';

/// 작성: 2026-10-04 13:37:23 · nada
/// 클래스: AppCard
/// 목적: 회색 표면 바탕에 테두리를 두른 카드. 시작 화면 거치 안내,
///       설정 화면 정보 행, 메일 시트 받는 사람처럼 내용을 한 덩이로
///       묶어 보여줄 때 쓴다.
class AppCard extends StatelessWidget {
  /// 카드 안에 놓을 내용
  final Widget child;

  /// 카드 안쪽 여백. 기본은 사방 `AppDims.gap2`
  final EdgeInsetsGeometry padding;

  /// 카드의 최소 높이. null 이면 내용 높이를 따른다
  final double? minHeight;

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: AppCard
  /// 목적: 카드 내용과 여백을 받는다.
  /// 인자: child — 카드 내용
  ///       padding — 안쪽 여백
  ///       minHeight — 최소 높이 (dp). null 이면 내용 높이
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDims.gap2),
    this.minHeight,
  });

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: build
  /// 목적: 표면 바탕 · 모서리 · 테두리를 입힌 상자에 내용을 담는다.
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      alignment: minHeight == null ? null : Alignment.center,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
