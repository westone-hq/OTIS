import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// S3 측정 거치 안내 바텀 시트
/// - 휴대폰을 카 바닥 중앙에 Y축 방향으로 정렬하라는 안내
/// - 어르신 UX: 큼직한 도식, 40dp 원형 번호 뱃지, 64dp 확인 버튼
class PlacementSheet extends StatelessWidget {
  const PlacementSheet({super.key});

  Widget _buildStepItem(int stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDims.gap2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: AppText.button.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(width: AppDims.gap2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(text, style: AppText.body),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.75,
      child: SafeArea(
        child: Column(
          children: [
            // 상단 헤더 및 닫기 버튼
            Padding(
              padding: const EdgeInsets.only(
                left: AppDims.screenPad,
                right: AppDims.gap,
                top: AppDims.gap2,
                bottom: AppDims.gap,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('휴대폰 거치 방법', style: AppText.subhead),
                  Semantics(
                    button: true,
                    label: '닫기',
                    child: SizedBox(
                      width: AppDims.touchMin,
                      height: AppDims.touchMin,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 28,
                          color: AppColors.text,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 스크롤 가능한 본문 내용
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDims.screenPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // OI-1: 확정 후 방향 검증
                    _buildDiagram(),
                    const SizedBox(height: AppDims.gap3),

                    // 4단계 안내
                    _buildStepItem(1, '카운트다운이 끝나기 전에 휴대폰을 바닥에 놓으세요'),
                    _buildStepItem(2, '휴대폰을 Y축 방향으로 맞추세요'),
                    _buildStepItem(3, '테스트가 시작되면 엘리베이터를 움직이세요'),
                    _buildStepItem(4, '완전히 멈추면 \'테스트 완료\'를 누르세요'),
                    const SizedBox(height: AppDims.gap),

                    // 경고 배너 (3중 표시: 색 + 아이콘 + 텍스트)
                    Container(
                      padding: const EdgeInsets.all(AppDims.gap2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppDims.radius),
                        border: Border.all(color: AppColors.gold, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.volume_off_outlined,
                            color: AppColors.gold,
                            size: 28,
                          ),
                          const SizedBox(width: AppDims.gap2),
                          Expanded(
                            child: Text(
                              '측정 중에는 조용히 해주세요',
                              style: AppText.bodyBold.copyWith(
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 고정 버튼
            Padding(
              padding: const EdgeInsets.all(AppDims.screenPad),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인했습니다'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // OI-1: 확정 후 방향 검증
  Widget _buildDiagram() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 상단 출입구 라벨 박스
          Positioned(
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppDims.radius),
              ),
              child: Text(
                '출입구',
                style: AppText.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // 카 내부 바닥(도식 배경 라인)
          Positioned.fill(
            left: 24,
            top: 24,
            right: 24,
            bottom: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.navy.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            ),
          ),

          // 중앙 스마트폰 및 Y축 화살표 도식
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blue, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: AppColors.blue,
                      size: 36,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Y축',
                      style: AppText.caption.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
