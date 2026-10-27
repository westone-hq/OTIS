import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vibration_checker/adapter/report/report_chart_renderer.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';
import 'package:vibration_checker/domain/report/chart_axes.dart';
import 'package:vibration_checker/domain/report/chart_series.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/ui/core/theme.dart';
import 'package:vibration_checker/ui/core/widgets/app_card.dart';

/// 작성: 2026-10-27 10:00:00 · 박건준
/// 클래스: _ChartSize
/// 목적: 결과 화면 그래프 그림 하나에만 쓰는 치수 묶음 (dp). 다른 화면은 쓰지
///       않아 `theme.dart` 토큰으로 올리지 않는다.
abstract final class _ChartSize {
  /// 그림 한 장의 높이. 세로 눈금 라벨 7개(소음 40 ~ 54)가 16sp 로 겹치지
  /// 않는 높이다
  static const double height = 220.0;

  /// 파형 선 두께
  static const double seriesWidth = 1.5;

  /// 축 틀 · 격자 선 두께
  static const double lineWidth = 1.0;

  /// 눈금 표시선 길이
  static const double tickLength = 4.0;

  /// 눈금 표시선과 눈금 라벨 사이, 이웃 라벨 사이 최소 간격
  static const double labelGap = 4.0;

  /// 빨간 점 반지름
  static const double markerRadius = 5.0;

  /// 빨간 점 둘레 흰 테 두께. 파란 파형 위에서도 점이 갈라져 보이게 한다
  static const double markerRing = 2.0;
}

/// 작성: 2026-10-27 10:00:00 · 박건준
/// 클래스: _ChartEntry
/// 목적: 결과 화면에 그릴 그래프 하나의 정의. 축 사양과 카드 제목 · 빨간 점
///       설명을 묶는다.
class _ChartEntry {
  /// 그릴 축의 사양. 범위 · 시계열 · 표시점 규칙은 리포트와 같은 것을 쓴다
  final ChartAxisSpec spec;

  /// 카드 제목. 지표 줄 이름과 같은 말로 쓴다
  final String title;

  /// 그림 아래 빨간 점 설명
  final String markerNote;

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: _ChartEntry
  /// 목적: 그래프 정의를 받는다.
  /// 인자: spec, title, markerNote — 위 필드 설명을 따른다
  const _ChartEntry({
    required this.spec,
    required this.title,
    required this.markerNote,
  });
}

/// 작성: 2026-10-27 10:00:00 · 박건준
/// 변수: _entries
/// 목적: 결과 화면에 그릴 그래프와 그 차례. 적색 판정이 있는 지표(X · Y · Z
///       진동 P2P, 소음 최대)의 파형만 그린다 — 화면에서 값이 왜 그렇게
///       나왔는지 보는 용도다. 위치 · 속도 · 가속도 · 저크는 리포트 3쪽에
///       있다.
/// 근거: 미정 — 결과 화면 그래프의 차트 종류는 사양이 없어 권장안으로
///       정했다(`docs/pending_checks.md`)
const List<_ChartEntry> _entries = <_ChartEntry>[
  _ChartEntry(
    spec: ReportChartAxes.x,
    title: 'X축 진동 [mg]',
    markerNote: '빨간 점: Peak to Peak 두 지점',
  ),
  _ChartEntry(
    spec: ReportChartAxes.y,
    title: 'Y축 진동 [mg]',
    markerNote: '빨간 점: Peak to Peak 두 지점',
  ),
  _ChartEntry(
    spec: ReportChartAxes.z,
    title: 'Z축 진동 [mg]',
    markerNote: '빨간 점: 정속 구간 Peak to Peak 두 지점',
  ),
  _ChartEntry(
    spec: ReportChartAxes.noise,
    title: '소음 [dBA]',
    // 소음 최대는 운행 구간 안에서 낸 값이라 구간 밖 더 큰 소리에는 찍지
    // 않는다(리포트와 같다). 그 차이를 글로 밝힌다
    markerNote: '빨간 점: 운행 구간 소음 최대',
  ),
];

/// 작성: 2026-10-27 10:00:00 · 박건준
/// 클래스: ResultCharts
/// 목적: 결과 화면 아래쪽 그래프 묶음. 리포트 2쪽과 같은 시계열 · 세로축
///       범위(`ChartScale`) · 가로축 눈금(`ReportChartRenderer.timeWindow()`)
///       · 빨간 점(`ReportChartAxes.ptpMarkers()`)을 써서, 화면과 PDF 가 같은
///       모양 · 같은 점을 보인다. 값은 위 지표 줄에 있어 그림에 다시 적지
///       않는다.
class ResultCharts extends StatelessWidget {
  /// 그릴 측정 결과
  final MeasurementResult result;

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: ResultCharts
  /// 목적: 그릴 측정 결과를 받는다.
  /// 인자: result — 측정 결과
  const ResultCharts({super.key, required this.result});

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: build
  /// 목적: 그래프 카드를 차례로 쌓는다(`_buildCard()`).
  /// 인자: context — 이 위젯이 어디에 놓이는지 알려주는 값
  /// 반환: 그래프 카드 묶음
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in _entries) ...[
          _buildCard(context, entry), // → 로직 이동: _buildCard()
          const SizedBox(height: AppDims.gap),
        ],
      ],
    );
  }

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: _buildCard
  /// 목적: 그래프 하나를 카드로 만든다. 제목 → 그림 → 빨간 점 · 가로축
  ///       설명 순서다. 시계열이 비었으면(마이크 권한이 없던 측정의 소음 등)
  ///       그림 대신 그렇다고 적는다 — 빈 틀만 그리면 고장으로 보인다.
  ///       눈금 숫자는 캡션 크기에 둘레 글자의 글꼴을 이어받는다 — 그림
  ///       안 글자는 `Text` 와 달리 둘레 글꼴을 스스로 따르지 않는다.
  /// 인자: context — 이 위젯이 어디에 놓이는지 알려주는 값
  ///       entry — 그래프 정의
  /// 반환: 그래프 카드 위젯
  Widget _buildCard(BuildContext context, _ChartEntry entry) {
    // → 로직 이동: ReportChartAxes.seriesOf()
    final values = ReportChartAxes.seriesOf(entry.spec, result); // 그릴 값
    final labelStyle = DefaultTextStyle.of(
      context,
    ).style.merge(AppText.caption); // 눈금 숫자 글자 모양
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title, style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          if (values.isEmpty)
            Text('기록된 파형이 없습니다', style: AppText.caption)
          else ...[
            SizedBox(
              height: _ChartSize.height,
              width: double.infinity,
              child: CustomPaint(
                // → 로직 이동: _ResultChartPainter.paint()
                painter: _ResultChartPainter(
                  spec: entry.spec,
                  values: values,
                  result: result,
                  labelStyle: labelStyle,
                ),
              ),
            ),
            const SizedBox(height: AppDims.gap),
            Text('가로: 시간 [s] · ${entry.markerNote}', style: AppText.caption),
          ],
        ],
      ),
    );
  }
}

/// 작성: 2026-10-27 10:00:00 · 박건준
/// 클래스: _ResultChartPainter
/// 목적: 그래프 한 장을 그린다. 축 범위 · 눈금 · 시계열 줄이기 · 표시점
///       자리는 모두 리포트와 같은 함수에서 받고, 여기서는 화면 좌표로 옮겨
///       긋기만 한다.
class _ResultChartPainter extends CustomPainter {
  /// 그릴 축의 사양
  final ChartAxisSpec spec;

  /// 그릴 시계열 (줄이기 전). 비어 있지 않다 — 빈 시계열은 카드가 글로
  /// 대신한다(`ResultCharts._buildCard()`)
  final List<double> values;

  /// 지표 · 구간 · 표본 주기를 가진 측정 결과
  final MeasurementResult result;

  /// 눈금 숫자 글자 모양. 캡션 크기(16sp)에 둘레 글꼴을 이어받은 것이다
  final TextStyle labelStyle;

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: _ResultChartPainter
  /// 목적: 그릴 축 · 시계열 · 측정 결과 · 눈금 글자 모양을 받는다.
  /// 인자: spec, values, result, labelStyle — 위 필드 설명을 따른다
  _ResultChartPainter({
    required this.spec,
    required this.values,
    required this.result,
    required this.labelStyle,
  }) : assert(values.isNotEmpty, '빈 시계열은 카드가 글로 대신한다');

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: paint
  /// 목적: 그래프를 그린다. 순서대로 한다.
  ///       1. 세로축 범위(`ChartAxisSpec.rangeFor()`)와 가로축 창
  ///          (`ReportChartRenderer.timeWindow()`)을 리포트와 같게 정한다.
  ///          가로축은 가장 긴 시계열 길이로 잡아 네 장이 같은 시간대를
  ///          그린다
  ///       2. 세로 눈금 라벨 폭만큼 왼쪽, 가로 눈금 라벨 높이만큼 아래를
  ///          비워 그림 틀을 정한다
  ///       3. 격자 → 파형(틀 안으로 자름) → 틀 → 눈금 라벨 → 빨간 점
  /// 인자: canvas — 그리기 도구
  ///       size — 그림 자리 크기 (dp)
  @override
  void paint(Canvas canvas, Size size) {
    // → 로직 이동: ChartAxisSpec.rangeFor()
    final range = spec.rangeFor(values); // 세로축 범위
    final valueTicks = range.ticks(); // 세로 눈금 값
    // → 로직 이동: ReportChartRenderer.timeWindow()
    final time = ReportChartRenderer.timeWindow(
      // → 로직 이동: ReportChartAxes.longestSeriesLength()
      ReportChartAxes.longestSeriesLength(result),
      result.sampleRate,
    ); // 가로축 왼쪽 끝 · 폭 · 눈금 간격 (초)
    // → 로직 이동: ReportChartRenderer.timeTicks()
    final timeTicks = ReportChartRenderer.timeTicks(time); // 가로 눈금 (초)

    final valueLabels = <TextPainter>[
      for (final tick in valueTicks)
        // → 로직 이동: ReportChartRenderer.formatTick()
        _label(ReportChartRenderer.formatTick(tick, range.tickStep)),
    ]; // 세로 눈금 라벨
    final timeLabels = <TextPainter>[
      for (final tick in timeTicks)
        // → 로직 이동: ReportChartRenderer.formatTick()
        _label(ReportChartRenderer.formatTick(tick, time.step)),
    ]; // 가로 눈금 라벨
    var widest = 0.0; // 세로 눈금 라벨 중 가장 넓은 폭 (dp)
    for (final label in valueLabels) {
      if (label.width > widest) widest = label.width;
    }
    final labelHeight = timeLabels.isEmpty
        ? 0.0
        : timeLabels.first.height; // 가로 눈금 라벨 높이 (dp)

    final plot = Rect.fromLTRB(
      widest + _ChartSize.tickLength + _ChartSize.labelGap,
      labelHeight / 2,
      size.width - _ChartSize.markerRadius,
      size.height - labelHeight - _ChartSize.tickLength - _ChartSize.labelGap,
    ); // 그림 틀. 위는 맨 위 눈금 라벨 반 줄만큼 비운다
    // 값 · 시각을 화면 자리로 옮긴다
    double yOf(double value) =>
        plot.bottom - (value - range.min) / range.span * plot.height;
    double xOf(double sec) =>
        plot.left + (sec - time.start) / time.span * plot.width;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ChartSize.lineWidth; // 틀 · 격자 붓

    // 1) 격자
    line.color = AppColors.border;
    for (final tick in valueTicks) {
      final y = yOf(tick); // 이 눈금의 세로 자리
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), line);
    }
    for (final tick in timeTicks) {
      final x = xOf(tick); // 이 눈금의 가로 자리
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), line);
    }

    // 2) 파형. 축 범위가 모든 값을 담지만 계산이 어긋나도 틀 밖으로
    // 뻗지 않게 자른다
    canvas
      ..save()
      ..clipRect(plot);
    // → 로직 이동: reduceSeriesSegments()
    final segments = reduceSeriesSegments(
      values,
      columns: math.max(1, plot.width.ceil()), // 가로 dp 한 칸에 최소 · 최대
      skipZeros: spec.scale.ignoreZeros,
    ); // 0(미측정) 구간에서 끊은 실측 구간들
    final series = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ChartSize.seriesWidth
      ..color = AppColors.blue; // 파형 붓
    for (final segment in segments) {
      final path = Path(); // 이 구간의 꺾은선
      for (var i = 0; i < segment.length; i++) {
        final x = xOf(segment[i].index / result.sampleRate); // 가로 자리
        final y = yOf(segment[i].value); // 세로 자리
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, series);
    }
    canvas.restore();

    // 3) 틀 · 눈금 표시선
    line.color = AppColors.textSub;
    canvas.drawRect(plot, line);
    for (final tick in valueTicks) {
      final y = yOf(tick); // 이 눈금의 세로 자리
      canvas.drawLine(
        Offset(plot.left - _ChartSize.tickLength, y),
        Offset(plot.left, y),
        line,
      );
    }
    for (final tick in timeTicks) {
      final x = xOf(tick); // 이 눈금의 가로 자리
      canvas.drawLine(
        Offset(x, plot.bottom),
        Offset(x, plot.bottom + _ChartSize.tickLength),
        line,
      );
    }

    // 4) 눈금 라벨. 이웃 라벨과 겹치는 것은 건너뛴다 — 좁은 폭에서 16sp
    // 라벨이 다 들어가지 않는다
    final labelRight = plot.left - _ChartSize.tickLength - _ChartSize.labelGap;
    var lastTop = double.infinity; // 바로 앞(아래쪽)에 적은 라벨 위끝
    for (var i = 0; i < valueTicks.length; i++) {
      final label = valueLabels[i]; // 이 눈금의 라벨
      final top = yOf(valueTicks[i]) - label.height / 2; // 라벨 위끝
      if (top + label.height + _ChartSize.labelGap > lastTop) continue;
      label.paint(canvas, Offset(labelRight - label.width, top));
      lastTop = top;
    }
    final labelTop =
        plot.bottom + _ChartSize.tickLength + _ChartSize.labelGap; // 라벨 위끝
    var lastRight = double.negativeInfinity; // 바로 앞(왼쪽)에 적은 라벨 오른끝
    for (var i = 0; i < timeTicks.length; i++) {
      final label = timeLabels[i]; // 이 눈금의 라벨
      final left = xOf(timeTicks[i]) - label.width / 2; // 라벨 왼끝
      if (left < lastRight + _ChartSize.labelGap) continue;
      if (left + label.width > size.width) continue;
      label.paint(canvas, Offset(left, labelTop));
      lastRight = left + label.width;
    }
    for (final label in [...valueLabels, ...timeLabels]) {
      label.dispose(); // 글자 배치에 잡은 자원을 돌려준다
    }

    // 5) 빨간 점. 틀 선에 걸쳐도 잘리지 않게 자르기를 푼 뒤 찍는다
    // → 로직 이동: _markerIndices()
    for (final index in _markerIndices()) {
      // → 로직 이동: _drawMarker()
      _drawMarker(
        canvas,
        Offset(xOf(index / result.sampleRate), yOf(values[index])),
      );
    }
  }

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: _markerIndices
  /// 목적: 빨간 점을 찍을 시계열 자리를 고른다. 리포트 2쪽과 같은 규칙이다.
  ///       - 진동 세 축 — 최대 P2P 두 지점(`ReportChartAxes.ptpMarkers()`)
  ///       - 소음 — 1쪽 표 소음 최대(`ReportMetrics.from()`)가 나온 운행 구간
  ///         안 자리(`ReportChartAxes.indexInTravel()`). 못 찾으면 찍지
  ///         않는다
  /// 반환: 점 자리 목록. 찍을 것이 없으면 빈 목록
  List<int> _markerIndices() {
    // → 로직 이동: ReportChartAxes.ptpMarkers()
    final pair = ReportChartAxes.ptpMarkers(spec, values, result); // P2P 쌍
    if (pair != null) return <int>[pair.low, pair.high];
    final peakKey = spec.peakKey; // 최댓값 지표 이름, 없는 축이면 null
    if (peakKey == null) return const <int>[];
    // → 로직 이동: ReportMetrics.from()
    final peak = ReportMetrics.from(result).byKey(peakKey)?.value; // 최댓값
    if (peak == null) return const <int>[];
    // → 로직 이동: ReportChartAxes.indexInTravel()
    final at = ReportChartAxes.indexInTravel(values, peak, result); // 자리
    return at < 0 ? const <int>[] : <int>[at];
  }

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: _drawMarker
  /// 목적: 표시점 하나를 흰 테를 두른 빨간 원으로 찍는다.
  /// 인자: canvas — 그리기 도구
  ///       center — 점 중심 (dp)
  void _drawMarker(Canvas canvas, Offset center) {
    canvas
      ..drawCircle(
        center,
        _ChartSize.markerRadius + _ChartSize.markerRing,
        Paint()..color = AppColors.bg,
      )
      ..drawCircle(
        center,
        _ChartSize.markerRadius,
        Paint()..color = AppColors.red,
      );
  }

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: _label
  /// 목적: 눈금 라벨 글자 하나를 잴 수 있게 준비한다. 캡션 크기(16sp)다 —
  ///       현장 사용자 기준 캡션 하한이다.
  /// 인자: text — 적을 글자
  /// 반환: 크기를 잰 글자 그리기 도구
  TextPainter _label(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: TextDirection.ltr,
  )..layout();

  /// 작성: 2026-10-27 10:00:00 · 박건준
  /// 함수: shouldRepaint
  /// 목적: 그릴 결과 · 축 · 글자 모양이 바뀌었을 때만 다시 그린다.
  /// 인자: oldDelegate — 앞서 그린 그리기 도구
  /// 반환: 다시 그려야 하면 true
  @override
  bool shouldRepaint(_ResultChartPainter oldDelegate) =>
      oldDelegate.result != result ||
      oldDelegate.spec != spec ||
      oldDelegate.values != values ||
      oldDelegate.labelStyle != labelStyle;
}
