import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/time/korea_time.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/core/widgets/app_card.dart';

/// 작성: 2026-10-04 18:15:24 · nada
/// 수정: 2026-10-22 22:55:00 · nada
/// 클래스: CompareSheet
/// 목적: 비교할 저장 결과를 고르는 시트. 최근 것부터 한 줄씩 보여주고,
///       누르면 그 결과를 고른 것으로 알린다.
class CompareSheet extends StatelessWidget {
  /// 고를 수 있는 저장 결과. 최근 것부터
  final List<MeasurementResult> candidates;

  /// 하나를 골랐을 때 부를 함수. 고른 결과를 받는다
  final void Function(MeasurementResult) onPicked;

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 수정: 2026-10-22 22:55:00 · nada
  /// 함수: CompareSheet
  /// 목적: 고를 결과 목록과 골랐을 때 할 일을 받는다.
  /// 인자: candidates, onPicked — 위 필드 설명을 따른다
  const CompareSheet({
    super.key,
    required this.candidates,
    required this.onPicked,
  });

  /// 작성: 2026-10-04 18:15:24 · nada
  /// 수정: 2026-10-15 15:53:26 · nada
  /// 함수: build
  /// 목적: 제목 아래에 저장 결과를 한 줄씩 늘어놓는다. 줄마다 제번 ·
  ///       현장명과 측정 일시를 보여준다.
  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.of(context).size.height * AppDims.sheetHeightFactor; // 시트 높이
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(AppDims.screenPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('비교할 결과 선택', style: AppText.subhead),
            const SizedBox(height: AppDims.gap2),
            Expanded(
              child: ListView.separated(
                itemCount: candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppDims.gap),
                itemBuilder: (_, index) {
                  final item = candidates[index]; // 이 줄의 저장 결과
                  final when = DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(KoreaTime.of(item.dateTime)); // 측정 일시 (한국 시간)
                  return InkWell(
                    onTap: () => onPicked(item),
                    borderRadius: BorderRadius.circular(AppDims.radius),
                    child: AppCard(
                      minHeight: AppDims.rowMinH,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.jobNo} · ${item.siteName}',
                            style: AppText.bodyBold,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(when, style: AppText.caption),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
