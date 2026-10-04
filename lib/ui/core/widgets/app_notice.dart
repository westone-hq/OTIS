import 'package:flutter/material.dart';

import '../theme.dart';

/// 작성: 2026-10-04 13:37:23 · nada
/// 클래스: NoticeTone
/// 목적: 안내 박스의 색 조합. 어르신도 놓치지 않도록 색 · 아이콘 · 문구를
///       함께 쓰고, 상황의 무게에 따라 셋 중 하나를 고른다.
///       - `danger` — 옅은 빨강 바탕 + 빨강 테두리 · 글자. 입력 오류,
///         측정 불가 안내
///       - `caution` — 옅은 금색 바탕 + 금색 테두리. 지켜 달라는 주의
///       - `alert` — 빨강으로 채운 바탕 + 흰 글자. 측정 중 반드시 봐야 할
///         경고
enum NoticeTone { danger, caution, alert }

/// 작성: 2026-10-04 13:37:23 · nada
/// 클래스: AppNotice
/// 목적: 아이콘 하나와 안내 문구 한 덩이를 담은 박스. 홈 화면 입력 오류,
///       시작 화면 센서 미지원, 거치 안내 주의 문구, 측정 화면 경고처럼
///       화면마다 따로 그리던 박스를 한 모양으로 모은다.
class AppNotice extends StatelessWidget {
  /// 박스 앞에 놓을 아이콘
  final IconData icon;

  /// 안내 문구. 줄바꿈 문자로 여러 줄을 쓸 수 있다
  final String message;

  /// 색 조합
  final NoticeTone tone;

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: AppNotice
  /// 목적: 안내 박스에 넣을 아이콘 · 문구 · 색 조합을 받는다.
  /// 인자: icon — 박스 앞 아이콘
  ///       message — 안내 문구
  ///       tone — 색 조합
  const AppNotice({
    super.key,
    required this.icon,
    required this.message,
    required this.tone,
  });

  /// 작성: 2026-10-04 13:37:23 · nada
  /// 함수: build
  /// 목적: 색 조합에 맞춰 바탕 · 테두리 · 아이콘 · 글자색을 정해 박스를
  ///       그린다.
  @override
  Widget build(BuildContext context) {
    final (background, accent, textColor) = switch (tone) {
      NoticeTone.danger => (AppColors.redTint, AppColors.red, AppColors.red),
      NoticeTone.caution => (
        AppColors.goldTint,
        AppColors.gold,
        AppColors.text,
      ),
      NoticeTone.alert => (AppColors.red, AppColors.onDark, AppColors.onDark),
    }; // 바탕색, 테두리 · 아이콘색, 글자색
    return Container(
      // 바탕 · 테두리
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: tone == NoticeTone.alert
            ? null
            : Border.all(color: accent, width: AppDims.borderW),
      ),
      child: Row(
        // 아이콘 + 문구
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: AppDims.iconM),
          const SizedBox(width: AppDims.gap2),
          Expanded(
            child: Text(
              message,
              style: AppText.bodyBold.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
