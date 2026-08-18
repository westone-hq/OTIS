// 작성: 2026-08-17 18:55:14
// 작성자: 박건준

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';

/// 클래스: PlacementSheet
/// 목적: 휴대폰을 엘리베이터 카 바닥 중앙에 Y축 방향으로 맞춰 놓으라고
///       안내하는 바텀 시트.
///       - 어르신도 쓰기 쉽도록 도식은 크게, 단계 번호는 40dp 원형
///         뱃지로, 확인 버튼은 64dp로 키운다
class PlacementSheet extends StatelessWidget {
  const PlacementSheet({super.key});

  /// 함수: _buildStepItem
  /// 목적: 안내 단계 하나를 번호 뱃지 + 문구 형태로 만든다.
  /// 인자: stepNumber — 단계 번호 (원형 뱃지에 표시)
  ///       text — 그 단계의 안내 문구
  /// 반환: 안내 단계 한 줄 위젯
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

  /// 함수: build
  /// 목적: 거치 안내 바텀 시트의 레이아웃을 구성한다.
  ///       - 상단 헤더 — 제목과 닫기 버튼
  ///       - 스크롤 가능한 본문 — 거치 방향 도식, 4단계 안내, 소음 주의
  ///         경고 배너
  ///       - 하단 고정 버튼 — "확인했습니다"를 누르면 시트를 닫는다
  /// 인자: context — 이 시트가 화면 어디에 놓이는지 알려주는 값. 화면
  ///       크기를 읽거나, 버튼을 눌러 시트를 닫을 때 쓴다
  /// 반환: 화면 높이의 75%를 차지하는 바텀 시트 위젯
  @override
  Widget build(BuildContext context) {
    // 이 시트 높이를 화면 비율로 잡기 위한 화면 전체 높이
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      // 시트 전체 높이를 화면의 75%로 고정
      height: screenHeight * 0.75,
      child: SafeArea(
        // 노치 등 시스템 UI를 피해서 배치
        child: Column(
          // 헤더 · 본문 · 하단 버튼을 세로로 배치
          children: [
            Padding(
              // 상단 헤더 영역 여백
              padding: const EdgeInsets.only(
                left: AppDims.screenPad,
                right: AppDims.gap,
                top: AppDims.gap2,
                bottom: AppDims.gap,
              ),
              child: Row(
                // 제목 + 닫기 버튼을 양 끝에 배치
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('휴대폰 거치 방법', style: AppText.subhead),
                  AppDialogIconButton(
                    icon: Icons.close,
                    label: '닫기',
                    color: AppColors.text,
                    onPressed: () => Navigator.of(context).pop(), // 시트 닫기
                  ),
                ],
              ),
            ),
            const Divider(height: 1), // 헤더와 본문을 가르는 구분선

            Expanded(
              // 남은 세로 공간을 본문에 전부 배정
              child: SingleChildScrollView(
                // 안내 내용이 길면 스크롤
                padding: const EdgeInsets.all(AppDims.screenPad),
                child: Column(
                  // 도식 → 4단계 안내 → 경고 배너 순서로 배치
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDiagram(),
                    const SizedBox(height: AppDims.gap3),

                    // 4단계 안내
                    _buildStepItem(1, '카운트다운이 끝나기 전에 휴대폰을 바닥에 놓으세요'),
                    _buildStepItem(2, '휴대폰을 Y축 방향으로 맞추세요'),
                    _buildStepItem(3, '테스트가 시작되면 엘리베이터를 움직이세요'),
                    _buildStepItem(4, '완전히 멈추면 \'테스트 완료\'를 누르세요'),
                    const SizedBox(height: AppDims.gap),

                    Container(
                      // 경고 배너: 색 + 아이콘 + 텍스트 3중 표시
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

            Padding(
              // 하단 고정 버튼 영역 여백
              padding: const EdgeInsets.all(AppDims.screenPad),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(), // 시트 닫기
                child: const Text('확인했습니다'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 함수: _buildDiagram
  /// 목적: 엘리베이터 카 안에서 휴대폰을 어느 위치에 어느 방향으로
  ///       놓을지 보여주는 도식을 만든다. 출입구 라벨, 카 바닥 테두리,
  ///       중앙의 휴대폰 · Y축 화살표로 구성한다.
  /// 반환: 거치 방향 안내 도식 위젯
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
