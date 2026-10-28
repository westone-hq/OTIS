import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_page1_layout.dart';

/// 작성: 2026-09-15 19:43:50 · 박건준
/// 수정: 2026-10-28 15:10:01 · 박희정
/// 클래스: ReportChartPageLayout
/// 목적: 차트 쪽의 자리들을 담는다. 머리말 네 칸과 차트 네 자리가 있다.
///       1쪽과 달리 쪽 번호 칸이 있고, 쪽 제목이 금색으로 들어간다.
class ReportChartPageLayout {
  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 수정: 2026-10-21 17:10:00 · 박건준
  /// 변수: background
  /// 목적: 서식 배경 이미지 자산 경로. 정본이 가진 파일 이름 앞에 자산
  ///       디렉터리를 붙인 것이다. 2026-10-21 이미지에서 예전 차트를 붓으로
  ///       지운 자국(밝기 252 ~ 254 의 옅은 회색 덩어리, PDF 에서 차트 둘레
  ///       그림자처럼 보임)을 흰색(255)으로 바꿨다 — 세 채널이 모두 246
  ///       이상인 점만 바꿔 머리말 · 꼬리말 띠와 로고는 그대로다.
  static const String background = '${ReportLayout.assetDirectory}tem_2.jpg';

  /// 쪽 제목
  static const LayoutField title = LayoutField(
    key: 'title',
    x: 317,
    y: 315,
    size: 70,
    align: LayoutAlign.left,
    weight: LayoutWeight.regular,
    color: ReportColors.gold,
  );

  /// 측정 식별자 (제번). 확대 로고를 피하는 자리를 1쪽과 함께 쓴다
  static const LayoutField measurementId = ReportPage1Layout.measurementId;

  /// 엔지니어명. 1쪽과 같은 칸을 그대로 쓴다 — 자리를 두 곳에 적으면 한쪽만
  /// 고쳐져 어긋난다
  static const LayoutField engineerName = ReportPage1Layout.engineerName;

  /// 측정 일시. 1쪽과 같은 자리다
  static const LayoutField datetime = LayoutField(
    key: 'datetime',
    x: 2192,
    y: 80,
    size: 24,
    align: LayoutAlign.right,
    weight: LayoutWeight.bold,
    color: ReportColors.navy,
  );

  /// 쪽 번호
  static const LayoutField pageNumber = LayoutField(
    key: 'page_number',
    x: 2180,
    y: 3128,
    size: 22,
    align: LayoutAlign.right,
    weight: LayoutWeight.regular,
    color: ReportColors.navy,
  );

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 변수: fields
  /// 목적: 차트 쪽 머리말 네 칸을 모아 둔 것. 낱개 상수와 같은 값이며,
  ///       전부 훑어야 할 때 쓴다. 쪽 제목은 머리말이 아니라 따로 둔다.
  static const List<LayoutField> fields = <LayoutField>[
    measurementId,
    engineerName,
    datetime,
    pageNumber,
  ];

  /// 차트 자리의 왼쪽 가로 좌표 (픽셀). 네 자리가 모두 같다
  static const int slotX = 283;

  /// 차트 자리의 가로 길이 (픽셀). 네 자리가 모두 같다
  static const int slotWidth = 1458;

  /// 차트 자리의 세로 길이 (픽셀). 네 자리가 모두 같다
  static const int slotHeight = 198;

  /// 작성: 2026-09-15 19:43:50 · 박건준
  /// 변수: slots
  /// 목적: 차트 네 자리를 위에서 아래 차례대로 모아 둔 것. 세로 좌표만
  ///       다르고 가로 좌표와 크기는 같다.
  /// 근거: 인용 — 원본 리포트에서 잰 축 틀 위치다
  static const List<LayoutPlotBox> slots = <LayoutPlotBox>[
    LayoutPlotBox(x: slotX, y: 415, width: slotWidth, height: slotHeight),
    LayoutPlotBox(x: slotX, y: 896, width: slotWidth, height: slotHeight),
    LayoutPlotBox(x: slotX, y: 1377, width: slotWidth, height: slotHeight),
    LayoutPlotBox(x: slotX, y: 1858, width: slotWidth, height: slotHeight),
  ];
}
