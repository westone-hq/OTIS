import 'package:flutter/material.dart';

import '../theme.dart';

/// 작성: 2026-10-04 13:37:23 · nada
/// 클래스: AppScrollBody
/// 목적: 화면 본문의 공통 틀. 시스템 영역(상태 표시줄 · 노치)을 피하고,
///       화면 여백을 두고, 넓은 화면에서는 폭을 `AppDims.contentMaxWidth`
///       로 묶은 채 세로로 스크롤한다. 내용은 가로로 꽉 채워 쌓는다.
class AppScrollBody extends StatelessWidget {
  /// 위에서 아래로 쌓을 내용
  final List<Widget> children;

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: AppScrollBody
  /// 목적: 본문에 쌓을 내용을 받는다.
  /// 인자: children — 위에서 아래로 쌓을 위젯 목록
  const AppScrollBody({super.key, required this.children});

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: build
  /// 목적: 여백 · 최대 폭 · 스크롤을 입힌 세로 목록을 그린다.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 시스템 영역을 피해서 배치
      child: SingleChildScrollView(
        // 내용이 길면 세로로 스크롤
        padding: const EdgeInsets.all(AppDims.screenPad),
        child: Center(
          // 넓은 화면에서 본문을 가운데 둔다
          child: ConstrainedBox(
            // 넓은 화면에서 폭이 과하게 늘어나지 않게 제한
            constraints: const BoxConstraints(
              maxWidth: AppDims.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// 작성: 2026-10-04 13:37:23 · nada
/// 클래스: AppBottomBar
/// 목적: 화면 아래에 고정하는 주 행동 영역. 시스템 영역을 피하고 화면
///       여백을 둔다. `Scaffold.bottomNavigationBar` 자리에 넣는다.
class AppBottomBar extends StatelessWidget {
  /// 아래 영역에 놓을 내용 (버튼 하나, 또는 안내 + 버튼 묶음)
  final Widget child;

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: AppBottomBar
  /// 목적: 아래 영역에 놓을 내용을 받는다.
  /// 인자: child — 아래 영역 내용
  const AppBottomBar({super.key, required this.child});

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: build
  /// 목적: 시스템 영역을 피해 여백을 두고 내용을 놓는다.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 시스템 영역을 피해서 배치
      child: Padding(
        padding: const EdgeInsets.all(AppDims.screenPad),
        child: child,
      ),
    );
  }
}

/// 작성: 2026-10-04 13:37:23 · nada
/// 함수: showAppSheet
/// 목적: 앱 공통 모양의 바텀 시트(bottom sheet, 화면 아래에서 위로
///       올라오는 패널)를 띄운다. 위쪽 두 모서리만 둥글게 깎고, 시트가
///       내용 길이에 맞춰 화면 위쪽까지 늘어날 수 있게 한다. 기본값대로
///       두면 시트가 화면 절반 높이로 묶여 안내가 잘린다.
///       시트는 화면 맨 아래까지 붙어 올라오므로, 내용을 아래쪽 시스템
///       영역(홈 · 뒤로 키가 있는 막대) 위로 올려 둔다 — 그러지 않으면
///       시트 맨 아래 버튼이 그 막대에 가려 누를 수 없다.
/// 인자: context — 시트를 띄울 화면의 위치 정보
///       builder — 시트 안에 그릴 위젯을 돌려주는 함수
/// 반환: 시트가 닫힐 때 끝나는 비동기 작업
Future<void> showAppSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDims.radius)),
    ),
    useSafeArea: true,
    // 아래쪽 시스템 영역만 비킨다. 위쪽은 `useSafeArea` 가 맡는다
    builder: (sheetContext) =>
        SafeArea(top: false, child: builder(sheetContext)),
  );
}
