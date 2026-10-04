import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_notice.dart';

/// 작성: 2026-10-04 13:37:23 · nada
/// 클래스: _DiagramSize
/// 목적: 거치 안내 그림의 치수 (dp). 이 그림에만 쓰는 값이라 앱 공통
///       토큰(theme.dart)에 두지 않고 여기에 모은다.
abstract final class _DiagramSize {
  /// 그림 전체 높이
  static const height = 220.0;

  /// 출입구 라벨과 그림 위쪽 끝 사이 간격
  static const doorTop = 12.0;

  /// 출입구 라벨 안쪽 좌우 여백
  static const doorPadH = 24.0;

  /// 출입구 라벨 안쪽 위아래 여백
  static const doorPadV = 6.0;

  /// 카 바닥 윤곽선을 그림 테두리에서 들여 넣는 거리
  static const floorInset = 24.0;

  /// 휴대폰 그림을 출입구 라벨 아래로 내리는 거리
  static const phoneTop = 24.0;

  /// 가로로 눕힌 휴대폰 그림의 긴 변
  static const phoneLong = 128.0;

  /// 가로로 눕힌 휴대폰 그림의 짧은 변
  static const phoneShort = 64.0;

  /// 휴대폰 그림 테두리 두께
  static const phoneBorder = 3.0;

  /// 뒷면 카메라 모듈 한 변
  static const cameraSize = 26.0;

  /// 카메라 모듈을 휴대폰 모서리에서 들여 넣는 거리
  static const cameraInset = 6.0;

  /// 카메라 렌즈 지름
  static const lensSize = 8.0;
}

/// 작성: 2026-08-17 18:55:14 · 박건준
/// 수정: 2026-10-04 16:54:15 · nada
/// 클래스: PlacementSheet
/// 목적: 휴대폰을 엘리베이터 카 바닥 중앙에 뒤집어서, 휴대폰 위쪽이
///       출입구 기준 오른쪽을 보게 놓으라고 안내하는 바텀 시트. 화면이
///       바닥을 보므로 측정은 볼륨키로 끝낸다.
///       - 어르신도 쓰기 쉽도록 도식은 크게, 단계 번호는 40dp 원형
///         뱃지로, 확인 버튼은 64dp로 키운다
class PlacementSheet extends StatelessWidget {
  const PlacementSheet({super.key});

  /// 작성: 2026-08-17 18:55:14 · 박건준
  /// 수정: 2026-10-04 13:37:23 · nada
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
            width: AppDims.badgeSize,
            height: AppDims.badgeSize,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: AppText.bodyBold.copyWith(color: AppColors.onDark),
            ),
          ),
          const SizedBox(width: AppDims.gap2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppDims.gap),
              child: Text(text, style: AppText.body),
            ),
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-08-17 18:55:14 · 박건준
  /// 수정: 2026-10-04 16:54:15 · nada
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
    final screenHeight = MediaQuery.of(
      context,
    ).size.height; // 시트 높이를 비율로 잡을 화면 전체 높이
    return SizedBox(
      // 시트 전체 높이를 화면의 75%로 고정
      height: screenHeight * AppDims.sheetHeightFactor,
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
                    _buildStepItem(1, '카운트다운이 끝나기 전에 휴대폰을 카 바닥 중앙에 놓으세요'),
                    _buildStepItem(2, '휴대폰을 뒤집어 그림과 같은 방향으로 놓으세요'),
                    _buildStepItem(3, '측정이 시작되면 엘리베이터를 움직이세요'),
                    _buildStepItem(4, '엘리베이터가 완전히 멈추면 볼륨키를 눌러 측정을 끝내세요'),
                    const SizedBox(height: AppDims.gap),

                    // 주의 배너: 색 + 아이콘 + 텍스트 3중 표시
                    const AppNotice(
                      icon: Icons.volume_off_outlined,
                      message: '측정 중에는 조용히 해주세요',
                      tone: NoticeTone.caution,
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

  /// 작성: 2026-08-17 18:55:14 · 박건준
  /// 수정: 2026-10-04 16:54:15 · nada
  /// 함수: _buildDiagram
  /// 목적: 엘리베이터 카 안에서 휴대폰을 어느 위치에 어느 방향으로
  ///       놓을지 보여주는 도식을 만든다. 위쪽에 출입구, 가운데에 뒤집어
  ///       가로로 눕힌 휴대폰(뒷면과 카메라가 보인다)을 두고, 휴대폰
  ///       위쪽이 오른쪽을 향한다는 화살표와 설명을 붙인다.
  /// 반환: 거치 방향 안내 도식 위젯
  /// 근거: 인용 — 격자 환산의 부호 기준이 이 거치 방식(화면을 아래로,
  ///       위쪽은 출입구 기준 오른쪽)을 전제로 한다
  ///       (`GridResampler.resample()`)
  Widget _buildDiagram() {
    return Container(
      height: _DiagramSize.height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: AppColors.border, width: AppDims.borderW),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 상단 출입구 라벨 박스
          Positioned(
            top: _DiagramSize.doorTop,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _DiagramSize.doorPadH,
                vertical: _DiagramSize.doorPadV,
              ),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppDims.radius),
              ),
              child: Text(
                '출입구',
                style: AppText.caption.copyWith(
                  color: AppColors.onDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // 카 내부 바닥(도식 배경 라인)
          Positioned.fill(
            left: _DiagramSize.floorInset,
            top: _DiagramSize.floorInset,
            right: _DiagramSize.floorInset,
            bottom: _DiagramSize.floorInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.navyFaint,
                  width: AppDims.borderWThick,
                ),
              ),
            ),
          ),

          // 뒤집어 눕힌 휴대폰과 설명
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: _DiagramSize.phoneTop),
              _buildPhoneBack(), // → 로직 이동: _buildPhoneBack()
              const SizedBox(height: AppDims.gap),
              Text(
                '뒤집어서, 휴대폰 위쪽이 오른쪽',
                style: AppText.caption.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 작성: 2026-10-04 16:54:15 · nada
  /// 함수: _buildPhoneBack
  /// 목적: 위에서 내려다본, 뒤집어 놓은 휴대폰을 그린다. 뒷면이 보이므로
  ///       남색으로 칠하고, 휴대폰 위쪽 끝(오른쪽)에 카메라 모듈을 둔다.
  ///       가운데의 "위쪽 →" 이 휴대폰 위쪽이 가리킬 방향이다.
  /// 반환: 휴대폰 뒷면 그림 위젯
  Widget _buildPhoneBack() {
    return Container(
      width: _DiagramSize.phoneLong,
      height: _DiagramSize.phoneShort,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(
          color: AppColors.blue,
          width: _DiagramSize.phoneBorder,
        ),
      ),
      child: Stack(
        children: [
          // 뒷면 카메라 모듈 — 휴대폰 위쪽 끝에 붙어 있다
          Positioned(
            top: _DiagramSize.cameraInset,
            right: _DiagramSize.cameraInset,
            child: Container(
              width: _DiagramSize.cameraSize,
              height: _DiagramSize.cameraSize,
              decoration: BoxDecoration(
                color: AppColors.onDarkSub,
                borderRadius: BorderRadius.circular(AppDims.gap),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var lens = 0; lens < 2; lens++)
                    Container(
                      width: _DiagramSize.lensSize,
                      height: _DiagramSize.lensSize,
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 휴대폰 위쪽이 가리킬 방향
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '위쪽',
                  style: AppText.caption.copyWith(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  color: AppColors.onDark,
                  size: AppDims.iconM,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
