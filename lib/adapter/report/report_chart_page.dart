import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:vibration_checker/adapter/report/report_chart_renderer.dart';
import 'package:vibration_checker/adapter/report/report_text.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/chart_axes.dart';
import 'package:vibration_checker/domain/report/report_chart_page_layout.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_page1_layout.dart';
import 'package:vibration_checker/domain/time/korea_time.dart';

/// 작성: 2026-09-23 09:40:00 · 박건준
/// 클래스: ReportChartPagePlan
/// 목적: 차트 쪽 한 장에 무엇이 들어가는지 담는다. 쪽 번호와 그 쪽에 놓일
///       축 넷을 한 자리에 묶어, 번호와 내용이 따로 놀지 않게 한다.
class ReportChartPagePlan {
  /// 리포트에서 이 쪽이 갖는 번호. 1쪽 뒤에 이어지므로 2 부터다
  final int pageNumber;

  /// 이 쪽에 위에서 아래 차례로 놓일 축 넷
  final List<ChartAxisSpec> axes;

  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 함수: ReportChartPagePlan
  /// 목적: 쪽 번호와 그 쪽에 놓일 축 넷을 그대로 담는 생성자.
  /// 인자: pageNumber — 이 쪽의 번호
  ///       axes — 위에서 아래 차례로 놓일 축 넷
  const ReportChartPagePlan({required this.pageNumber, required this.axes});
}

/// 작성: 2026-09-23 09:40:00 · 박건준
/// 수정: 2026-10-23 10:00:00 · 박건준
/// 클래스: ReportChartPageRenderer
/// 목적: TUNE 리포트의 차트 쪽을 PDF 로 그린다. 2쪽과 3쪽이 같은 서식을
///       쓰고 놓이는 축만 달라, 한 렌더러가 두 쪽을 모두 그린다.
///
///       자리는 `ReportLayout` 이, 축 사양은 `chart_axes.dart` 가, 파형은
///       `report_chart_renderer.dart` 가 정해 둔 것을 받아 놓기만 한다 — 여기서
///       좌표를 계산하거나 축 범위를 정하지 않는다.
///
///       1쪽(`report_page1.dart`)과 달리 서식에 덮어야 할 옛 값이 없다.
///       차트 자리가 서식에서 비어 있어 그대로 얹으면 된다.
class ReportChartPageRenderer {
  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 수정: 2026-10-21 16:30:00 · 박건준
  /// 변수: title
  /// 목적: 차트 쪽 제목. 두 쪽 모두 같은 제목을 쓴다. "테이터" 는 오타가
  ///       아니다 — OTIS 원본 리포트 표기를 그대로 따른 의도된 표기이니
  ///       "데이터" 로 되돌리지 않는다.
  /// 근거: 인용 — 2026-10-21 사용자 지시 "제목 '데이터 차트' 를 '테이터
  ///       차트' 로". OTIS 리포트 2쪽과 3쪽 제목이 "테이터 차트" 다
  static const String title = '테이터 차트';

  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 변수: pages
  /// 목적: 차트 쪽 두 장의 구성. 쪽 번호와 놓일 축을 짝지어 둔다.
  ///       - 2쪽 — 진동 세 축과 소음. 사람이 직접 느끼는 양이다
  ///       - 3쪽 — 위치 · 속도 · 가속도 · 저크. 수직 가속도에서 이끌어 낸
  ///         양이라 한 쪽에 모은다
  /// 근거: 인용 — 원본 리포트의 2쪽과 3쪽 차트 차례를 그대로 옮겼다
  static const List<ReportChartPagePlan> pages = <ReportChartPagePlan>[
    ReportChartPagePlan(
      pageNumber: 2,
      axes: <ChartAxisSpec>[
        ReportChartAxes.x,
        ReportChartAxes.y,
        ReportChartAxes.z,
        ReportChartAxes.noise,
      ],
    ),
    ReportChartPagePlan(
      pageNumber: 3,
      axes: <ChartAxisSpec>[
        ReportChartAxes.position,
        ReportChartAxes.speed,
        ReportChartAxes.accel,
        ReportChartAxes.jerk,
      ],
    ),
  ];

  /// 그림을 얹을 PDF 문서
  final PdfDocument document;

  /// A4 전면에 깔 차트 쪽 서식 이미지
  final PdfImage background;

  /// 서식 좌표에 글자를 찍는 도구
  final ReportTextWriter textWriter;

  /// 차트 한 개씩을 그리는 렌더러
  final ReportChartRenderer chartRenderer;

  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 함수: ReportChartPageRenderer
  /// 목적: 문서와 미리 읽어 둔 자산을 그대로 담는 생성자. 직접 부르지 말고
  ///       `load()` 를 쓴다.
  /// 인자: document — 그림을 얹을 PDF 문서
  ///       background — 차트 쪽 서식 이미지
  ///       textWriter — 서식 좌표에 글자를 찍는 도구. 글꼴 두 벌을 갖고
  ///       있어 이 클래스가 따로 들고 있지 않는다
  ///       chartRenderer — 차트 한 개씩을 그릴 렌더러
  const ReportChartPageRenderer({
    required this.document,
    required this.background,
    required this.textWriter,
    required this.chartRenderer,
  });

  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: load
  /// 목적: 글꼴 두 벌과 차트 쪽 서식 이미지를 자산에서 읽어 렌더러를
  ///       만든다. 자산 읽기는 느리고 두 쪽에 한 번이면 되므로 그리기와
  ///       떼어 둔다.
  /// 인자: document — 그림을 얹을 PDF 문서
  /// 반환: 바로 그릴 수 있는 렌더러
  static Future<ReportChartPageRenderer> load(PdfDocument document) async {
    final regularBytes = await rootBundle.load(
      ReportLayout.regularFontAsset,
    ); // 본문 글꼴 원본
    final boldBytes = await rootBundle.load(
      ReportLayout.boldFontAsset,
    ); // 굵은 글꼴 원본
    final backgroundBytes = await rootBundle.load(
      ReportChartPageLayout.background,
    ); // 차트 쪽 서식 이미지 원본

    final regular = PdfTtfFont(document, regularBytes); // 본문 글꼴
    final bold = PdfTtfFont(document, boldBytes); // 굵은 글꼴
    return ReportChartPageRenderer(
      document: document,
      background: PdfImage.file(
        document,
        bytes: backgroundBytes.buffer.asUint8List(),
      ),
      textWriter: ReportTextWriter(regular: regular, bold: bold),
      chartRenderer: ReportChartRenderer(font: regular, labelFont: bold),
    );
  }

  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 수정: 2026-10-12 02:15:16 · 박건준
  /// 함수: draw
  /// 목적: 차트 쪽 한 장을 문서에 더한다. 순서대로 그린다.
  ///       1. 서식 이미지를 A4 전면에 깐다
  ///       2. 머리말 네 칸과 쪽 제목을 찍는다
  ///       3. 차트 자리 넷에 축을 차례로 그린다
  ///
  ///       시계열이 빈 축도 축 틀까지는 그려진다. 마이크 권한이 없어
  ///       소음이 0 으로만 들어온 측정이 그렇다. 그때도 자리를 비우지
  ///       않는 것이 맞다 — 비우면 서식이 바뀐 것처럼 보인다.
  /// 인자: result — 값을 가져올 측정 결과
  ///       plan — 그릴 쪽의 번호와 놓을 축 넷
  /// 반환: 문서에 더해진 차트 쪽
  PdfPage draw({
    required MeasurementResult result,
    required ReportChartPagePlan plan,
  }) {
    // 축 넷과 자리 넷은 서식에서 짝이 정해져 있다. 수가 어긋나면 자리가
    // 남거나 모자라므로, 갈래를 두지 않고 확인만 해 둔다
    assert(
      plan.axes.length == ReportChartPageLayout.slots.length,
      '축 수와 차트 자리 수가 다르다',
    );

    final page = PdfPage(
      document,
      pageFormat: PdfPageFormat(
        ReportLayout.pageWidthPt,
        ReportLayout.pageHeightPt,
      ),
    ); // 이번에 그릴 쪽
    final canvas = page.getGraphics(); // 그리기 도구

    canvas.drawImage(
      background,
      0,
      0,
      ReportLayout.pageWidthPt,
      ReportLayout.pageHeightPt,
    );

    // → 로직 이동: headerValues()
    final header = headerValues(result, plan.pageNumber); // 머리말에 채울 문구
    for (final field in ReportChartPageLayout.fields) {
      // → 로직 이동: ReportTextWriter.drawField()
      textWriter.drawField(
        canvas,
        field: field,
        text: header[field.key] ?? '',
        // → 로직 이동: ReportPage1Layout.maxWidthOf()
        maxWidthPx: ReportPage1Layout.maxWidthOf(field),
      );
    }
    // → 로직 이동: ReportTextWriter.drawField()
    textWriter.drawField(
      canvas,
      field: ReportChartPageLayout.title,
      text: title,
    );

    for (var index = 0; index < plan.axes.length; index++) {
      // → 로직 이동: ReportChartRenderer.draw()
      chartRenderer.draw(
        canvas,
        spec: plan.axes[index],
        box: ReportChartPageLayout.slots[index],
        result: result,
      );
    }
    return page;
  }

  /// 작성: 2026-09-23 09:40:00 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: headerValues
  /// 목적: 머리말 네 칸에 채울 문구를 만든다.
  ///       - 제번 → 측정 ID, 쪽 번호 → 받은 번호
  ///       - 측정 일시 → 1쪽과 같은 한국 시간(`KoreaTime.of()`)
  ///       - 엔지니어명 → 1쪽과 같은 저장 시점 이름. 없으면 자리 표시
  ///         문구(`ReportPage1Layout.placeholder`). 서식에 "엔지니어:" 라벨이
  ///         찍혀 있어 비우면 빠뜨린 것처럼 보인다(2026-10-11 사용자 지시
  ///         "엔지니어 칸에 무조건 기입")
  ///       시험이 칸마다 문구를 확인할 수 있게 공개해 둔다.
  /// 인자: result — 값을 가져올 측정 결과
  ///       pageNumber — 이 쪽의 번호
  /// 반환: 서식 칸 이름을 열쇠로 하는 문구 표
  static Map<String, String> headerValues(
    MeasurementResult result,
    int pageNumber,
  ) {
    final stamp = DateFormat(
      ReportLayout.datetimePattern,
    ).format(KoreaTime.of(result.dateTime)); // 머리말 측정 일시 (한국 시간)
    return <String, String>{
      'measurement_id': result.jobNo,
      'engineer_name': result.engineerName ?? ReportPage1Layout.placeholder,
      'datetime': stamp,
      'page_number': '$pageNumber',
    };
  }
}

/// 작성: 2026-09-23 09:40:00 · 박건준
/// 수정: 2026-10-23 11:00:00 · 박건준
/// 함수: renderReportChartPages
/// 목적: 차트 쪽 두 장만 담은 PDF 한 부를 만든다. 앱은 세 쪽을 이어 붙인
///       `TuneReportBuilder` 를 쓰고, 이 함수는 시험이 차트 쪽만 따로 확인할
///       때 쓴다.
/// 인자: result — 값을 가져올 측정 결과
/// 반환: PDF 파일 내용
Future<Uint8List> renderReportChartPages({
  required MeasurementResult result,
}) async {
  final document = PdfDocument(); // 만들어 낼 PDF 문서
  // → 로직 이동: ReportChartPageRenderer.load()
  final renderer = await ReportChartPageRenderer.load(document); // 자산을 읽은 렌더러

  for (final plan in ReportChartPageRenderer.pages) {
    // → 로직 이동: ReportChartPageRenderer.draw()
    renderer.draw(result: result, plan: plan);
  }
  return document.save();
}
