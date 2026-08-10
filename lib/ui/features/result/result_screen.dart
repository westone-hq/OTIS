import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme.dart';
import 'package:vibration_checker/model/raw_sensor_diagnostics.dart';
import 'package:vibration_checker/model/sensor_sample.dart';
import 'package:vibration_checker/model/measurement_result.dart';
import 'package:vibration_checker/adapter/parse_raw.dart';
import 'package:vibration_checker/adapter/measurement_repository.dart';
import '../shared/measurement_session.dart';
import '../shared/send_email_sheet.dart';
import 'metric_card.dart';

/// S5 결과 통합 화면 (요약 카드 + 차트 스크롤)
/// - 신규 측정 결과 및 저장된 결과 공용 화면
/// - 어르신 UX: 6지표 카드 및 8종 차트 시각화, 카드 탭 시 차트로 자동 스크롤
class ResultScreen extends StatefulWidget {
  final String id;

  const ResultScreen({super.key, required this.id});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

/// 측정 결과 지표 조회, RAW 데이터 비동기 파싱, 차트 렌더링 및 스크롤 이동을 관리합니다.
class _ResultScreenState extends State<ResultScreen> {
  // P9 RAW 데이터 파싱 모듈(RawDataParser) 연동 준비 완료
  late MeasurementResult _result;
  bool _isRealSample = false;
  final List<GlobalKey> _chartKeys = List.generate(8, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    if (widget.id == MeasurementSession.instance.lastResultId &&
        MeasurementSession.instance.lastResult != null) {
      _result = MeasurementSession.instance.lastResult!;
      _isRealSample = true;
    } else if (widget.id == 'sample' ||
        widget.id == 'raw' ||
        widget.id == '2024F1447R01') {
      _result = MeasurementResult.mock;
      _loadRawSample();
    } else {
      _result = MeasurementResult.mock;
      _loadFromRepository(widget.id);
    }
  }

  Future<void> _loadFromRepository(String id) async {
    try {
      final loaded = await MeasurementRepository.instance.load(id);
      if (loaded != null && mounted) {
        setState(() {
          _result = loaded;
          _isRealSample = true;
        });
      }
    } catch (_) {
      _showMockFailure('측정 기록 조회');
    }
  }

  /// 목적: 저장·출력 계층 미구현 실패를 사용자가 이해할 수 있는 문구로 화면에 보여준다.
  /// 인자: request — 시도한 동작을 설명하는 한국어 문구
  /// 반환: 없음
  void _showMockFailure(String request) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('저장·출력 기능은 아직 구현되지 않았습니다.\n(요청: $request)'),
        backgroundColor: AppColors.red,
      ),
    );
  }

  Future<void> _loadRawSample() async {
    try {
      final rawContent = await rootBundle.loadString(
        'assets/sample/2024F1447R01.txt',
      );
      final parsed = RawDataParser.parseEvimp1(
        rawContent: rawContent,
        id: widget.id,
        jobNo: '2024F 1447R01',
        siteName: '럭키종합건설/송정동근생',
        bottomFloor: 1,
        topFloor: 8,
        direction: '상향',
        dateTime: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _result = parsed;
          _isRealSample = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '실제 2024F1447R01 파싱 데이터 로드 완료 (${parsed.xSeries.length}개 샘플)',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.navy,
          ),
        );
      }
    } catch (_) {
      _showMockFailure('측정 데이터 파싱');
    }
  }

  void _toggleDataSource() {
    if (_isRealSample) {
      setState(() {
        _result = MeasurementResult.mock;
        _isRealSample = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기본 예시(Mock) 데이터로 전환되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _loadRawSample();
    }
  }

  void _scrollToChart(int index) {
    final key = _chartKeys[index];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _sendEmail() {
    showSendEmailSheet(context, jobId: _result.id);
  }

  Widget _buildSummaryHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_result.lowMotionWarning) ...[
          Container(
            padding: const EdgeInsets.all(AppDims.gap),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDims.radius),
            ),
            child: Text(
              '참고: 움직임 미감지 상태로 저장된 결과입니다',
              style: AppText.caption.copyWith(
                color: AppColors.textSub,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppDims.gap),
        ],
        if (!_result.usedDetectedRideSegment) ...[
          Container(
            padding: const EdgeInsets.all(AppDims.gap),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDims.radius),
            ),
            child: Text(
              '참고: 주행 구간 자동검출 실패 — 전체 구간 기준 산출',
              style: AppText.caption.copyWith(
                color: AppColors.textSub,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppDims.gap),
        ],
        // 현장 요약 한 줄
        Text(
          '${_result.jobNo} · ${_result.siteName} · ${_result.bottomFloor}층 → ${_result.topFloor}층',
          style: AppText.caption.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDims.gap2),

        // 6지표 요약 카드 (GridView 2열)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppDims.gap2,
          crossAxisSpacing: AppDims.gap2,
          childAspectRatio: 1.4,
          children: [
            MetricCard(
              label: 'X축 진동 (P2P)',
              valueStr: _result.xPtp.toStringAsFixed(1),
              unit: 'mg',
              isExceeded: _result.xExceeded,
              onTap: () => _scrollToChart(0),
            ),
            MetricCard(
              label: 'Y축 진동 (P2P)',
              valueStr: _result.yPtp.toStringAsFixed(1),
              unit: 'mg',
              isExceeded: _result.yExceeded,
              onTap: () => _scrollToChart(1),
            ),
            MetricCard(
              label: 'Z축 진동 (P2P)',
              valueStr: _result.zPtp.toStringAsFixed(1),
              unit: 'mg',
              isExceeded: _result.zExceeded,
              onTap: () => _scrollToChart(2),
            ),
            MetricCard(
              label: '최대 소음',
              valueStr: _result.noiseMax <= 0.0
                  ? 'N/A'
                  : _result.noiseMax.toStringAsFixed(1),
              unit: _result.noiseMax <= 0.0 ? '' : 'dBA',
              isExceeded: _result.noiseMax <= 0.0
                  ? null
                  : _result.noiseExceeded,
              onTap: () => _scrollToChart(3),
            ),
            MetricCard(
              label: '운행 거리',
              valueStr: _result.distance.toStringAsFixed(1),
              unit: 'm',
              isExceeded: null,
              onTap: () => _scrollToChart(4),
            ),
            MetricCard(
              label: '최대 속도',
              valueStr: _result.maxSpeed.toStringAsFixed(2),
              unit: 'm/s',
              isExceeded: null,
              onTap: () => _scrollToChart(5),
            ),
          ],
        ),
        const SizedBox(height: AppDims.gap3),
        _buildOriginalSensorDataBox(),
        const SizedBox(height: AppDims.gap2),
        _buildRideSegmentBox(),
        const SizedBox(height: AppDims.gap2),
        _buildDebugMetricsBox(),
        const SizedBox(height: AppDims.gap3),

        // 차트 섹션 제목
        Text('데이터 차트', style: AppText.subhead),
        const SizedBox(height: AppDims.gap2),
      ],
    );
  }

  Widget _buildRideSegmentBox() {
    return Container(
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDims.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('정속 구간 진단', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          Text('정속 구간: ${_result.constantSpeedRange}', style: AppText.caption),
          Text(
            '검출 상태: ${_result.usedDetectedConstantSpeed ? '자동 검출' : '전체 구간 사용'}',
            style: AppText.caption,
          ),
          Text(
            '샘플 수: ${_result.constantSpeedSampleCount} / ${_result.totalVibrationSampleCount} '
            '(${(_result.constantSpeedRatio * 100).toStringAsFixed(1)}%)',
            style: AppText.caption,
          ),
          const SizedBox(height: AppDims.gap),
          Text(
            'P-P 비교 (필터 전 → 후)',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDims.gap),
          _buildFilterPtpCompareRow(
            axis: 'X',
            preFull: _result.preFilterFullXPtp,
            postFull: _result.fullXPtp,
            preConstant: _result.preFilterConstantXPtp,
            postConstant: _result.constantXPtp,
          ),
          _buildFilterPtpCompareRow(
            axis: 'Y',
            preFull: _result.preFilterFullYPtp,
            postFull: _result.fullYPtp,
            preConstant: _result.preFilterConstantYPtp,
            postConstant: _result.constantYPtp,
          ),
          _buildFilterPtpCompareRow(
            axis: 'Z',
            preFull: _result.preFilterFullZPtp,
            postFull: _result.fullZPtp,
            preConstant: _result.preFilterConstantZPtp,
            postConstant: _result.constantZPtp,
          ),
          const SizedBox(height: AppDims.gap),
          Text(
            'Aptp 판정은 정속 구간의 필터 후 신호 기준이며, 위 값은 원인 분석용 P-P 비교입니다.',
            style: AppText.caption.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPtpCompareRow({
    required String axis,
    required double preFull,
    required double postFull,
    required double preConstant,
    required double postConstant,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDims.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$axis축',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '전체 ${preFull.toStringAsFixed(1)} → ${postFull.toStringAsFixed(1)} mg',
            style: AppText.caption,
          ),
          Text(
            '정속 ${preConstant.toStringAsFixed(1)} → ${postConstant.toStringAsFixed(1)} mg',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// S22 원본 센서 XYZ + raw 값 전용 표시 (계산값과 분리)
  Widget _buildOriginalSensorDataBox() {
    final samples = _result.rawSamples;
    if (samples == null || samples.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDims.gap2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDims.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('원본 센서 데이터', style: AppText.bodyBold),
            const SizedBox(height: AppDims.gap),
            Text(
              '저장된 raw 샘플이 없습니다. 새로 측정한 결과에서 확인하세요.',
              style: AppText.caption.copyWith(color: AppColors.textSub),
            ),
          ],
        ),
      );
    }

    final diag = RawSensorDiagnostics.fromSamples(
      samples,
      sampleRateHz: _result.sampleRate,
    );
    final extended = diag.hasExtendedRaw;
    final previewLines = _buildRawDataPreviewLines(samples, extended: extended);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.navy, width: 1.5),
        borderRadius: BorderRadius.circular(AppDims.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('원본 센서 데이터 (S22)', style: AppText.bodyBold),
          const SizedBox(height: 4),
          Text(
            '${diag.sampleCount}샘플 · ${diag.durationSec.toStringAsFixed(1)}초 · '
            '${diag.sampleRateHz.toStringAsFixed(0)}Hz · 단위 mg',
            style: AppText.caption.copyWith(color: AppColors.textSub),
          ),
          const SizedBox(height: AppDims.gap2),

          Text('① Linear XYZ (중력 제외 · 진동용)', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          _buildXyzLine('X', diag.linearX),
          _buildXyzLine('Y', diag.linearY),
          _buildXyzLine('Z', diag.linearZ),
          const SizedBox(height: AppDims.gap2),

          Text('② Raw XYZ (가속도계 원값 · 중력 포함)', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          if (extended) ...[
            _buildXyzLine('X', diag.rawX),
            _buildXyzLine('Y', diag.rawY),
            _buildXyzLine('Z', diag.rawZ, hint: '정지 시 Z ≈ 1000'),
          ] else
            Text('미수집 (옛 raw 포맷)', style: AppText.caption.copyWith(color: AppColors.textSub)),
          const SizedBox(height: AppDims.gap2),

          Text('③ Gravity XYZ (중력 추정)', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          if (extended) ...[
            _buildXyzLine('X', diag.gravityX),
            _buildXyzLine('Y', diag.gravityY),
            _buildXyzLine('Z', diag.gravityZ, hint: '정지 시 Z ≈ 1000'),
          ] else
            Text('미수집 (옛 raw 포맷)', style: AppText.caption.copyWith(color: AppColors.textSub)),
          const SizedBox(height: AppDims.gap2),

          if (diag.noise.available)
            Text(
              '소음: min ${diag.noise.min.toStringAsFixed(1)} / '
              'max ${diag.noise.max.toStringAsFixed(1)} / '
              'mean ${diag.noise.mean.toStringAsFixed(1)} dBA',
              style: AppText.caption,
            ),
          const SizedBox(height: AppDims.gap2),

          Text('④ Raw 샘플 값 (시작·중간·끝)', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            extended
                ? 'tsUs  linX linY linZ  noise  rawX rawY rawZ  gX gY gZ'
                : 'linX linY linZ  noise',
            style: AppText.caption.copyWith(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textSub,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(AppDims.gap),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                previewLines,
                style: AppText.caption.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDims.gap),
          Text(
            '전체 샘플은 저장 폴더의 raw.txt에 있습니다.',
            style: AppText.caption.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildXyzLine(String axis, ChannelStats stats, {String? hint}) {
    if (!stats.available) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '$axis: —',
          style: AppText.caption.copyWith(color: AppColors.textSub),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$axis: min ${stats.min.toStringAsFixed(1)}  '
        'max ${stats.max.toStringAsFixed(1)}  '
        'mean ${stats.mean.toStringAsFixed(1)}  '
        'P-P ${stats.peakToPeak.toStringAsFixed(1)}'
        '${hint != null ? '  ($hint)' : ''}',
        style: AppText.caption.copyWith(color: AppColors.text),
      ),
    );
  }

  String _buildRawDataPreviewLines(
    List<SensorSample> samples, {
    required bool extended,
  }) {
    final list = selectRawPreviewSamples(samples, edgeCount: 8);
    final buf = StringBuffer();
    for (final s in list) {
      buf.writeln(formatRawSampleLine(s, extended: extended));
    }
    return buf.toString().trimRight();
  }

  Widget _buildDebugMetricsBox() {
    final metrics = _result.debugMetrics;
    if (metrics.isEmpty) {
      return const SizedBox.shrink();
    }

    String f(String key, {String unit = '', int digits = 2}) {
      final value = metrics[key];
      if (value == null) return '-';
      return '${value.toStringAsFixed(digits)}$unit';
    }

    return Container(
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDims.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('센서 진단값 (계산용)', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          Text(
            'sampleRate: ${f('sampleRate', unit: ' Hz', digits: 1)}',
            style: AppText.caption,
          ),
          Text(
            'max accel: ${f('maxAccelMs2', unit: ' m/s²')}',
            style: AppText.caption,
          ),
          Text(
            'velocity max: ${f('velocityMax', unit: ' m/s')}',
            style: AppText.caption,
          ),
          Text(
            'distance raw: ${f('distanceRaw', unit: ' m')}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildChartItem(int index) {
    String title;
    String unit;
    List<double> series;
    double? threshold;
    bool isOver = false;
    String? noteText;

    switch (index) {
      case 0:
        title = '1. X축 진동';
        unit = 'mg';
        series = _result.xSeries;
        threshold = null;
        isOver = _result.xExceeded;
        noteText = 'Aptp: ${_result.xPtp.toStringAsFixed(1)} mg (임계: 10mg)';
        break;
      case 1:
        title = '2. Y축 진동';
        unit = 'mg';
        series = _result.ySeries;
        threshold = null;
        isOver = _result.yExceeded;
        noteText = 'Aptp: ${_result.yPtp.toStringAsFixed(1)} mg (임계: 10mg)';
        break;
      case 2:
        title = '3. Z축 진동';
        unit = 'mg';
        series = _result.zSeries;
        threshold = null;
        isOver = _result.zExceeded;
        noteText = 'Aptp: ${_result.zPtp.toStringAsFixed(1)} mg (임계: 15mg)';
        break;
      case 3:
        title = '4. 소음';
        unit = 'dBA';
        series = _result.noiseSeries;
        threshold = 50.0;
        isOver = _result.noiseExceeded;
        break;
      case 4:
        title = '5. 위치';
        unit = 'm';
        series = _result.positionSeries;
        threshold = null;
        break;
      case 5:
        title = '6. 속도';
        unit = 'm/s';
        series = _result.speedSeries;
        threshold = null;
        break;
      case 6:
        title = '7. 가속도';
        unit = 'm/s²';
        series = _result.accelSeries;
        threshold = null;
        break;
      case 7:
      default:
        title = '8. 저크';
        unit = 'm/s³';
        series = _result.jerkSeries;
        threshold = null;
        break;
    }

    final double sampleRate = _result.sampleRate > 0
        ? _result.sampleRate
        : 256.0;
    List<FlSpot> spots;
    if (series.length > 800) {
      final int stride = (series.length / 800).ceil();
      spots = [];
      for (int i = 0; i < series.length; i += stride) {
        spots.add(FlSpot(i / sampleRate, series[i]));
      }
    } else {
      spots = series
          .asMap()
          .entries
          .map((e) => FlSpot(e.key / sampleRate, e.value))
          .toList();
    }
    final double maxTime = series.length / sampleRate;
    final double interval = maxTime > 5 ? (maxTime / 5).floorToDouble() : 1.0;

    return Container(
      key: _chartKeys[index],
      margin: const EdgeInsets.only(bottom: AppDims.gap2),
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(
          color: isOver ? AppColors.red : AppColors.border,
          width: isOver ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 차트 제목 및 임계값 안내
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$title ($unit)',
                style: AppText.bodyBold.copyWith(
                  color: isOver ? AppColors.red : AppColors.navy,
                ),
              ),
              if (threshold != null)
                Text(
                  '임계: ${threshold.toInt()}$unit',
                  style: AppText.caption.copyWith(
                    color: isOver ? AppColors.red : AppColors.textSub,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (noteText != null)
                Text(
                  noteText,
                  style: AppText.caption.copyWith(
                    color: isOver ? AppColors.red : AppColors.textSub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDims.gap2),

          // 180dp 높이 LineChart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: interval > 0 ? interval : 1.0,
                      getTitlesWidget: (val, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${val.toInt()}s',
                            style: AppText.caption.copyWith(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) {
                        return Text(
                          val.toStringAsFixed(1),
                          style: AppText.caption.copyWith(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.border),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: isOver ? AppColors.red : AppColors.blue,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isOver ? AppColors.red : AppColors.blue)
                          .withValues(alpha: 0.1),
                    ),
                  ),
                ],
                extraLinesData: threshold != null
                    ? ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: threshold,
                            color: AppColors.red,
                            strokeWidth: 2,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              style: AppText.caption.copyWith(
                                color: AppColors.red,
                                fontWeight: FontWeight.w700,
                              ),
                              labelResolver: (_) => '임계: ${threshold!.toInt()}',
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('측정 결과'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: Icon(
                _isRealSample ? Icons.dataset : Icons.dataset_outlined,
                color: _isRealSample ? AppColors.blue : null,
              ),
              tooltip: _isRealSample ? '기본 예시로 전환' : '실제 샘플 데이터 로드',
              onPressed: _toggleDataSource,
            ),
        ],
      ),
      body: SafeArea(
        // 성능을 위해 ListView.builder 사용 (lazy build)
        child: ListView.builder(
          padding: const EdgeInsets.all(AppDims.screenPad),
          scrollCacheExtent: const ScrollCacheExtent.pixels(
            3000,
          ), // 카드 탭 시 8개 차트 위치 스크롤 보장을 위해 충분한 캐시 지정
          itemCount: 9, // 0: 요약 헤더 + 1~8: 차트 8종
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildSummaryHeader();
            } else {
              return _buildChartItem(index - 1);
            }
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: ElevatedButton(
            onPressed: _sendEmail,
            child: const Text('이메일로 보내기'),
          ),
        ),
      ),
    );
  }
}
