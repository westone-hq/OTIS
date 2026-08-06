import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// S5 결과 지표 요약 카드 위젯
/// - 6지표(X/Y/Z 진동, 소음, 거리, 속도) 표시
/// - 기준 초과 시 좌측 8dp red bar 및 색+아이콘+텍스트 3중 강조
class MetricCard extends StatelessWidget {
  final String label;
  final String valueStr;
  final String unit;
  final bool? isExceeded; // true: 초과, false: 정상, null: 판정 없음(거리/속도)
  final VoidCallback onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.valueStr,
    required this.unit,
    this.isExceeded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasExceeded = isExceeded == true;
    final bool hasPassed = isExceeded == false;

    final Color valueColor =
        hasExceeded
            ? AppColors.red
            : (hasPassed ? AppColors.green : AppColors.text);

    return Semantics(
      button: true,
      label:
          '$label $valueStr $unit ${hasExceeded ? "기준 초과" : (hasPassed ? "정상" : "")}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDims.radius),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDims.radius),
            border: Border.all(
              color: hasExceeded ? AppColors.red : AppColors.border,
              width: hasExceeded ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 기준 초과 시 왼쪽 8dp red bar
              if (hasExceeded) Container(width: 8, color: AppColors.red),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDims.gap2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 상단 라벨 및 태그
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: AppText.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isExceeded != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (hasExceeded
                                            ? AppColors.red
                                            : AppColors.green)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasExceeded
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    size: 16,
                                    color: valueColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasExceeded ? '기준 초과' : '정상',
                                    style: AppText.caption.copyWith(
                                      color: valueColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      // 하단 값(fontSize 30 w700) + 단위
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            valueStr,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: valueColor,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            unit,
                            style: AppText.caption.copyWith(
                              color: AppColors.textSub,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
