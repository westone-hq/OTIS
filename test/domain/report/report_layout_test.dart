import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/report_layout.dart';

/// 작성: 2026-09-15 19:43:50 · nada
/// 변수: _layoutJsonPath
/// 목적: 좌표 정본 기록의 경로. `report_layout.dart` 는 이 파일을 사람이
///       옮긴 사본이다.
const _layoutJsonPath = 'docs/report_layout.json';

/// 작성: 2026-09-15 19:43:50 · nada
/// 변수: _layoutJsonMd5
/// 목적: 옮길 때 본 정본 기록의 md5. 정본이 바뀌면 이 값이 달라져,
///       사본을 함께 고쳐야 한다는 사실이 시험 실패로 드러난다.
const _layoutJsonMd5 = '38cde4c2b9730fa8ae66e84b902b175c';

/// 작성: 2026-09-15 19:43:50 · nada
/// 함수: _layout
/// 목적: 좌표 정본 기록을 읽어 들인다.
/// 반환: json 을 그대로 풀어놓은 Map
Map<String, dynamic> _layout() {
  return jsonDecode(File(_layoutJsonPath).readAsStringSync())
      as Map<String, dynamic>;
}

/// 작성: 2026-09-15 19:43:50 · nada
/// 함수: _fieldByKey
/// 목적: json 의 칸 목록에서 이름이 같은 칸 하나를 찾는다.
/// 인자: fields — json 의 `fields` 목록
///       key — 찾을 칸 이름
/// 반환: 찾은 칸. 없으면 시험을 실패시킨다
Map<String, dynamic> _fieldByKey(List<dynamic> fields, String key) {
  return fields.cast<Map<String, dynamic>>().firstWhere(
    (field) => field['key'] == key,
    orElse: () => fail('json 에 "$key" 칸이 없다'),
  );
}

/// 작성: 2026-09-15 19:43:50 · nada
/// 함수: _expectField
/// 목적: 옮겨 적은 칸 하나가 정본과 같은지 본다. 자리 · 크기 · 정렬 ·
///       굵기 · 색을 모두 맞춰 본다.
/// 인자: actual — 옮겨 적은 칸
///       expected — json 에 적힌 같은 이름의 칸
void _expectField(LayoutField actual, Map<String, dynamic> expected) {
  final where = actual.key; // 어긋났을 때 어느 칸인지 알리는 이름
  expect(actual.x, expected['x'], reason: '$where x');
  expect(actual.y, expected['y'], reason: '$where y');
  expect(actual.size, expected['size'], reason: '$where size');
  expect(actual.align.name, expected['align'], reason: '$where align');
  expect(actual.weight.name, expected['weight'], reason: '$where weight');
}

/// 작성: 2026-09-15 19:43:50 · nada
/// 함수: main
/// 목적: `report_layout.dart` 의 좌표가 정본 `docs/report_layout.json` 과
///       같은지 대조한다. 사람이 손으로 옮기는 과정에서 숫자 하나가
///       틀어지는 것을 잡는 용도다.
void main() {
  group('ReportLayout 과 report_layout.json 대조', () {
    test('정본 기록이 옮길 때 본 그대로다', () {
      final digest = md5
          .convert(File(_layoutJsonPath).readAsBytesSync())
          .toString(); // 지금 정본의 md5

      expect(
        digest,
        _layoutJsonMd5,
        reason: '정본이 바뀌었다. report_layout.dart 를 함께 고치고 이 값을 갱신할 것',
      );
    });

    test('페이지 크기와 환산 계수가 같다', () {
      final page = _layout()['page'] as Map<String, dynamic>; // json 의 페이지 정보

      expect(ReportLayout.pageWidthPx, page['width_px']);
      expect(ReportLayout.pageHeightPx, page['height_px']);
      expect(ReportLayout.pageWidthPt, page['width_pt']);
      expect(ReportLayout.pageHeightPt, page['height_pt']);
      // json 에는 소수로 끊은 사본이, 여기서는 페이지 크기에서 직접 나눈
      // 값이 들어 있다. 끊은 자리만큼만 벌어진다
      expect(
        ReportLayout.ptPerPxX,
        closeTo(page['pt_per_px_x'] as double, 1e-9),
      );
      expect(
        ReportLayout.ptPerPxY,
        closeTo(page['pt_per_px_y'] as double, 1e-9),
      );
    });

    test('두 축의 환산 계수가 서로 다르다', () {
      // 서식 비율과 A4 비율이 달라 한 계수로는 두 축을 못 맞춘다
      expect(ReportLayout.ptPerPxX, isNot(ReportLayout.ptPerPxY));
    });

    test('색이 모두 같다', () {
      final colors = _layout()['colors'] as Map<String, dynamic>; // json 의 색 목록
      const moved = <String, int>{
        'navy': ReportColors.navy,
        'gold': ReportColors.gold,
        'text': ReportColors.text,
        'white': ReportColors.white,
        'judge_green': ReportColors.judgeGreen,
        'judge_yellow': ReportColors.judgeYellow,
        'judge_red': ReportColors.judgeRed,
        'judge_unknown': ReportColors.judgeUnknown,
        'chart_line': ReportColors.chartLine,
        'chart_grid': ReportColors.chartGrid,
        'chart_marker': ReportColors.chartMarker,
        'chart_guide': ReportColors.chartGuide,
        'stripe_odd': ReportColors.stripeOdd,
        'stripe_even': ReportColors.stripeEven,
      }; // 옮겨 적은 색

      expect(moved.length, colors.length, reason: '색 개수');
      moved.forEach((key, value) {
        final hex = '#${value.toRadixString(16).toUpperCase().padLeft(6, '0')}';
        expect(hex, colors[key], reason: key);
      });
    });

    test('1쪽 머리말 11칸이 같다', () {
      final page1 = _layout()['page1'] as Map<String, dynamic>; // json 의 1쪽
      final fields = page1['fields'] as List<dynamic>; // json 의 칸 목록

      expect(ReportPage1.fields.length, fields.length);
      for (final moved in ReportPage1.fields) {
        _expectField(moved, _fieldByKey(fields, moved.key));
      }
    });

    test('Performance Metrics 표 8행이 같다', () {
      final page1 = _layout()['page1'] as Map<String, dynamic>; // json 의 1쪽
      final table =
          page1['metrics_table'] as Map<String, dynamic>; // json 의 지표 표
      final rows = table['rows'] as List<dynamic>; // json 의 행 목록
      final col = table['col'] as Map<String, dynamic>; // json 의 열 좌표
      final dot = table['dot'] as Map<String, dynamic>; // json 의 신호등 원

      expect(ReportPage1.metricRows.length, rows.length);
      for (var i = 0; i < rows.length; i++) {
        final expected = rows[i] as Map<String, dynamic>; // json 의 그 행
        final moved = ReportPage1.metricRows[i]; // 옮겨 적은 그 행
        expect(moved.key, expected['key'], reason: '$i번째 행 이름');
        expect(moved.y, expected['y'], reason: '${moved.key} y');
        expect(moved.judge, expected['judge'], reason: '${moved.key} judge');
        expect(
          moved.hasLabel,
          expected['has_label'],
          reason: '${moved.key} has_label',
        );
      }

      expect(ReportPage1.dotCenterX, dot['cx']);
      expect(ReportPage1.dotDiameter, dot['diameter']);
      expect(ReportPage1.colCategoryX, col['category']);
      expect(ReportPage1.colDescLabelStartX, col['desc_label_start']);
      expect(ReportPage1.colDescLabelEndX, col['desc_label_end']);
      expect(ReportPage1.colValueX, col['value']);
      expect(ReportPage1.colValueNoLabelX, col['value_no_label']);
      expect(ReportPage1.colYellowX, col['yellow']);
      expect(ReportPage1.colRedX, col['red']);
      expect(ReportPage1.valueSize, table['value_size']);
      expect(ReportPage1.thresholdSize, table['threshold_size']);
      expect(
        ReportPage1.eraseRedWidth,
        (table['erase_red'] as Map<String, dynamic>)['w'],
      );
      expect(
        ReportPage1.eraseRedHeight,
        (table['erase_red'] as Map<String, dynamic>)['h'],
      );

      final align = table['col_align'] as Map<String, dynamic>; // json 의 열 정렬
      expect(ReportPage1.colCategoryAlign.name, align['category']);
      expect(ReportPage1.colValueAlign.name, align['value']);
      expect(ReportPage1.colValueNoLabelAlign.name, align['value_no_label']);
      expect(ReportPage1.colYellowAlign.name, align['yellow']);
      expect(ReportPage1.colRedAlign.name, align['red']);
    });

    test('마지막 행은 균등 피치로 계산하면 어긋난다', () {
      // 실측 간격은 106 109 110 109 109 110 95 다. 마지막 한 칸만
      // 뚜렷하게 좁아서, 위 여섯 행의 평균 간격으로 넘겨짚으면 마지막
      // 행이 12픽셀 넘게 밀린다. 계산으로 구하면 안 된다는 사실을
      // 시험으로 남긴다
      const pitch =
          (ReportPage1.horizMaxY - ReportPage1.noiseAvgY) / 5; // 1~6행 평균 간격
      const guessedLast = ReportPage1.horizMaxY + 2 * pitch; // 넘겨짚은 8행 자리

      expect(
        (guessedLast - ReportPage1.travelDistanceY).abs(),
        greaterThan(10),
        reason: '균등 피치로는 마지막 행을 맞힐 수 없다',
      );
      expect(
        ReportPage1.travelDistanceY - ReportPage1.maxSpeedY,
        lessThan(ReportPage1.maxSpeedY - ReportPage1.horizMaxY),
        reason: '마지막 칸이 그 앞 칸보다 좁다',
      );
    });

    test('분석 자료 표 7행이 같다', () {
      final table =
          (_layout()['page1'] as Map<String, dynamic>)['analysis_table']
              as Map<String, dynamic>;
      final rows = table['rows'] as List<dynamic>; // json 의 행 목록

      expect(ReportPage1.analysisRowYs.length, rows.length);
      expect(ReportPage1.analysisRowKeys.length, rows.length);
      for (var i = 0; i < rows.length; i++) {
        final expected = rows[i] as Map<String, dynamic>; // json 의 그 행
        expect(ReportPage1.analysisRowKeys[i], expected['key'], reason: '$i');
        expect(ReportPage1.analysisRowYs[i], expected['y'], reason: '$i');
      }

      expect(
        ReportPage1.analysisDescriptionX,
        (table['col'] as Map<String, dynamic>)['description'],
      );
      expect(ReportPage1.analysisDescriptionSize, table['description_size']);

      final align = table['col_align'] as Map<String, dynamic>; // json 의 열 정렬
      expect(ReportPage1.analysisCategoryAlign.name, align['category']);
      expect(ReportPage1.analysisDescriptionAlign.name, align['description']);
    });

    test('차트 쪽 머리말 4칸과 제목이 같다', () {
      final chart = _layout()['chart_page'] as Map<String, dynamic>;
      final fields = chart['fields'] as List<dynamic>; // json 의 칸 목록

      expect(ReportChartPage.fields.length, fields.length);
      for (final moved in ReportChartPage.fields) {
        _expectField(moved, _fieldByKey(fields, moved.key));
      }

      final title = chart['title'] as Map<String, dynamic>; // json 의 쪽 제목
      expect(ReportChartPage.title.x, title['x']);
      expect(ReportChartPage.title.y, title['y']);
      expect(ReportChartPage.title.size, title['size']);
      expect(ReportChartPage.title.align.name, title['align']);
      expect(ReportChartPage.title.weight.name, title['weight']);
    });

    test('배경 경로는 정본의 파일 이름에 자산 디렉터리를 붙인 것이다', () {
      // 정본은 파일 이름만 갖고 디렉터리는 구현이 붙인다. 정본이 디렉터리를
      // 함께 갖게 되면 이 시험이 먼저 깨진다
      final page1 = _layout()['page1'] as Map<String, dynamic>; // json 의 1쪽
      final chart =
          _layout()['chart_page'] as Map<String, dynamic>; // json 의 차트 쪽

      expect(
        ReportPage1.background,
        '${ReportLayout.assetDirectory}${page1['background']}',
      );
      expect(
        ReportChartPage.background,
        '${ReportLayout.assetDirectory}${chart['background']}',
      );
      expect(page1['background'], isNot(contains('/')), reason: '정본은 파일 이름만');
      expect(chart['background'], isNot(contains('/')), reason: '정본은 파일 이름만');
    });

    test('차트 자리 4개가 같다', () {
      final chart = _layout()['chart_page'] as Map<String, dynamic>;
      final slots = chart['slots'] as List<dynamic>; // json 의 차트 자리 목록

      expect(ReportChartPage.slots.length, slots.length);
      for (var i = 0; i < slots.length; i++) {
        final box =
            (slots[i] as Map<String, dynamic>)['plot_box']
                as Map<String, dynamic>; // json 의 그 자리
        final moved = ReportChartPage.slots[i]; // 옮겨 적은 그 자리
        expect(moved.x, box['x'], reason: '$i번째 x');
        expect(moved.y, box['y'], reason: '$i번째 y');
        expect(moved.width, box['w'], reason: '$i번째 w');
        expect(moved.height, box['h'], reason: '$i번째 h');
      }
    });
  });

  group('ReportLayout 좌표 변환', () {
    test('가로는 배율만 곱한다', () {
      expect(ReportLayout.xToPoints(0), 0.0);
      expect(
        ReportLayout.xToPoints(1000),
        closeTo(1000 * ReportLayout.ptPerPxX, 1e-12),
      );
    });

    test('세로는 위아래가 뒤집힌다', () {
      // 이미지 맨 위(0)는 PDF 맨 위(페이지 높이)가 되고, 이미지 맨
      // 아래는 PDF 0 에 가까워진다
      expect(
        ReportLayout.yToPoints(0),
        closeTo(ReportLayout.pageHeightPt, 1e-9),
      );
      expect(
        ReportLayout.yToPoints(1000),
        closeTo(
          ReportLayout.pageHeightPt - 1000 * ReportLayout.ptPerPxY,
          1e-12,
        ),
      );
    });

    test('서식 오른쪽 아래 끝이 A4 와 정확히 맞는다', () {
      // 축별 계수를 페이지 크기에서 직접 나눠 쓰므로 어림수가 끼지 않고
      // 양쪽 끝이 종이 끝에 그대로 떨어진다
      expect(
        ReportLayout.xToPoints(ReportLayout.pageWidthPx),
        ReportLayout.pageWidthPt,
      );
      expect(ReportLayout.yToPoints(ReportLayout.pageHeightPx), 0.0);
      expect(ReportLayout.yToPoints(0), ReportLayout.pageHeightPt);
    });

    test('길이는 뒤집지 않고 가로 배율만 곱한다', () {
      expect(
        ReportLayout.lengthToPoints(ReportPage1.dotDiameter),
        closeTo(ReportPage1.dotDiameter * ReportLayout.ptPerPxX, 1e-12),
      );
    });
  });
}
