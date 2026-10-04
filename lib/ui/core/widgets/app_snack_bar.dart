import 'package:flutter/material.dart';

import '../theme.dart';

/// 작성: 2026-10-04 13:37:23 · nada
/// 함수: showSuccessSnackBar
/// 목적: 저장 · 발송 준비처럼 끝났다는 것을 알리는 스낵바(snack bar,
///       화면 아래에 잠깐 떴다 사라지는 알림 띠)를 띄운다. 남색 바탕에
///       초록 체크 아이콘을 붙여 색만이 아니라 모양으로도 성공을 알린다.
/// 인자: context — 스낵바를 띄울 화면의 위치 정보
///       message — 알릴 문구
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.green),
          const SizedBox(width: AppDims.gap),
          Expanded(
            child: Text(
              message,
              style: AppText.body.copyWith(color: AppColors.onDark),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.navy,
    ),
  );
}

/// 작성: 2026-10-04 13:37:23 · nada
/// 함수: showErrorSnackBar
/// 목적: 실패나 제한을 알리는 빨간 스낵바를 띄운다.
/// 인자: context — 스낵바를 띄울 화면의 위치 정보
///       message — 알릴 문구
///       duration — 떠 있는 시간. null 이면 앱 기본값(4초)을 쓴다. 문구가
///       길어 읽는 데 오래 걸리면 늘린다
void showErrorSnackBar(
  BuildContext context,
  String message, {
  Duration? duration,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppText.body.copyWith(color: AppColors.onDark),
      ),
      backgroundColor: AppColors.red,
      duration: duration ?? const Duration(seconds: 4),
    ),
  );
}
