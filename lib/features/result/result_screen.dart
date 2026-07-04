import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme.dart';
import '../../domain/models/measurement_result.dart';
import '../../domain/parse_raw.dart';
import '../../domain/repository/measurement_repository.dart';
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
    } catch (_) {}
  }

  Future<void> _loadRawSample() async {
    try {
      final rawContent = await rootBundle.loadString('assets/sample/2024F1447R01.txt');
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
            content: Text('실제 2024F1447R01 파싱 데이터 로드 완료 (${parsed.xSeries.length}개 샘플)'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.navy,
          ),
        );
      }
    } catch (_) {
      // fallback to mock
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
              valueStr: _result.noiseMax <= 0.0 ? 'N/A' : _result.noiseMax.toStringAsFixed(1),
              unit: _result.noiseMax <= 0.0 ? '' : 'dBA',
              isExceeded: _result.noiseMax <= 0.0 ? null : _result.noiseExceeded,
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

        // 차트 섹션 제목
        Text('데이터 차트', style: AppText.subhead),
        const SizedBox(height: AppDims.gap2),
      ],
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

    final double sampleRate = _result.sampleRate > 0 ? _result.sampleRate : 256.0;
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
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
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
          scrollCacheExtent: const ScrollCacheExtent.pixels(3000), // 카드 탭 시 8개 차트 위치 스크롤 보장을 위해 충분한 캐시 지정
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
