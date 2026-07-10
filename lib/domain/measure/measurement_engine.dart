import 'dart:async';
import '../models/measurement_result.dart';
import 'metrics_config.dart';
import 'motion_integrator.dart';
import 'ride_detector.dart';
import 'sensor_sample.dart';
import 'signal_filters.dart';
import 'vibration_metrics.dart';

/// OTIS 진동·소음 측정 총괄 엔진 (순수 Dart)
/// - 스트림 수집 → 버퍼링 → 필터링 → 성분 분리 → 적분 → 구간 검출 → 지표 도출
class MeasurementEngine {
  final MetricsConfig config;
  final List<SensorSample> _buffer = [];
  StreamSubscription<SensorSample>? _subscription;
  bool _isMeasuring = false;

  MeasurementEngine({this.config = MetricsConfig.defaultConfig});

  bool get isMeasuring => _isMeasuring;
  int get sampleCount => _buffer.length;
  List<SensorSample> get bufferedSamples => List.unmodifiable(_buffer);

  /// 스트림 수집 시작
  void start(Stream<SensorSample> stream) {
    stop();
    _buffer.clear();
    _isMeasuring = true;
    _subscription = stream.listen((sample) {
      _buffer.add(sample);
    });
  }

  /// 수집 중단
  void stop() {
    _isMeasuring = false;
    _subscription?.cancel();
    _subscription = null;
  }

  /// 버퍼 리셋
  void clear() {
    stop();
    _buffer.clear();
  }

  /// 수동 샘플 투입 (테스트 또는 골든 픽스처 분석용)
  void addSamples(List<SensorSample> samples) {
    _buffer.addAll(samples);
  }

  /// 버퍼에 수집된 신호를 분석하여 MeasurementResult 도출
  MeasurementResult analyze({
    String? id,
    String jobNo = 'MOCK-JOB',
    String siteName = 'MOCK-SITE',
    int bottomFloor = 1,
    int topFloor = 10,
    String direction = '하부 → 상부',
    DateTime? dateTime,
  }) {
    final now = dateTime ?? DateTime.now();
    final compressedJobNo = jobNo.replaceAll(RegExp(r'\s+'), '');
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    final resultId = id ?? '${compressedJobNo}_$y$m${d}_$h$min$sec';

    if (_buffer.length < 2) {
      final s = _buffer.isNotEmpty
          ? _buffer.first
          : const SensorSample(tsUs: 0, x: 0.0, y: 0.0, z: 0.0, noiseDba: 0.0);
      return MeasurementResult(
        id: resultId,
        jobNo: jobNo,
        siteName: siteName,
        bottomFloor: bottomFloor,
        topFloor: topFloor,
        direction: direction,
        dateTime: now,
        xPtp: 0.0,
        yPtp: 0.0,
        zPtp: 0.0,
        noiseMax: double.parse(s.noiseDba.toStringAsFixed(1)),
        distance: 0.0,
        maxSpeed: 0.0,
        xSeries: [s.x],
        ySeries: [s.y],
        zSeries: [s.z],
        noiseSeries: [s.noiseDba],
        positionSeries: [0.0],
        speedSeries: [0.0],
        accelSeries: [double.parse((s.z * SensorSample.mgToMetersPerSecondSquared).toStringAsFixed(2))],
        jerkSeries: [0.0],
        sampleRate: 256.0,
        usedDetectedRideSegment: false,
        constantSpeedRange: '전체 구간',
        rawSamples: List.from(_buffer),
      );
    }

    // 1. 기준선 보정
    final correctedSamples = SignalFilters.applyBaselineCorrection(
      _buffer,
      baselineSec: config.baselineSec,
    );

    // 2. 실측 샘플레이트 도출
    final double sampleRate =
        SignalFilters.estimateSampleRate(_buffer);

    // 3. 성분 분리 (Motion vs Vibration) - Aptp 경로는 기준선 보정 미적용 (원신호 _buffer 직접 분리)
    // Aptp 경로는 baseline 보정 미적용: P2P는 DC 불변 + 이동평균 LPF의 edge effect와 상호작용해 Z 과소산출 유발. 적분 경로만 baseline 적용.
    final sep = SignalFilters.separateMotionAndVibration(
      _buffer,
      sampleRate: sampleRate,
      cutoffHz: config.motionLowpassCutoffHz,
    );

    // 4. 수직축 적분 (속도, 거리, 저크) - 기준선 보정된 원신호(correctedSamples) 기준
    final integ = MotionIntegrator.integrate(
      correctedSamples,
      sampleRate: sampleRate,
    );

    // 5. 주행 구간 검출 (Ride Detection)
    final rideRes = RideDetector.detectRideSegment(
      sep.vibration,
      integ.displaySpeedSeriesMs,
      speedThreshold: config.rideSpeedThreshold,
      paddingSec: config.rideActivityPaddingSec,
      minDurationSec: config.minRideDurationSec,
    );

    // 6. 정속 구간 검출 (Constant Speed Detection)
    final int safeEnd = mathMin(rideRes.endIndex, integ.displaySpeedSeriesMs.length - 1);
    final int safeStart = mathMin(rideRes.startIndex, safeEnd);
    final rideSpeedSub = integ.displaySpeedSeriesMs.sublist(safeStart, safeEnd + 1);

    final constRes = RideDetector.detectConstantSpeedRange(
      rideRes.samples,
      rideSpeedSub,
      constantRatio: config.constantSpeedRatio,
    );

    // 7. 지표 산출 (Aptp, noiseMax)
    final constX = constRes.samples.map((s) => s.x).toList();
    final constY = constRes.samples.map((s) => s.y).toList();
    final constZ = constRes.samples.map((s) => s.z).toList();

    final double xAptp = VibrationMetrics.calculateAptp(
      constX,
      sampleRate: sampleRate,
      windowSec: config.aptpWindowSecX,
      percentile: config.aptpPercentile,
    );
    final double yAptp = VibrationMetrics.calculateAptp(
      constY,
      sampleRate: sampleRate,
      windowSec: config.aptpWindowSecY,
      percentile: config.aptpPercentile,
    );
    final double zAptp = VibrationMetrics.calculateAptp(
      constZ,
      sampleRate: sampleRate,
      windowSec: config.aptpWindowSecZ,
      percentile: config.aptpPercentile,
    );

    final double noiseMax =
        VibrationMetrics.calculateNoiseMax(constRes.samples);

    // 시계열 데이터 구성 (전체 구간 기준 표시용)
    final xSeries = sep.vibration.map((s) => s.x).toList();
    final ySeries = sep.vibration.map((s) => s.y).toList();
    final zSeries = sep.vibration.map((s) => s.z).toList();
    final noiseSeries = sep.vibration.map((s) => s.noiseDba).toList();

    return MeasurementResult(
      id: resultId,
      jobNo: jobNo,
      siteName: siteName,
      bottomFloor: bottomFloor,
      topFloor: topFloor,
      direction: direction,
      dateTime: now,
      xPtp: double.parse(xAptp.toStringAsFixed(2)),
      yPtp: double.parse(yAptp.toStringAsFixed(2)),
      zPtp: double.parse(zAptp.toStringAsFixed(2)),
      noiseMax: double.parse(noiseMax.toStringAsFixed(1)),
      distance: double.parse(integ.distanceM.toStringAsFixed(2)),
      maxSpeed: double.parse(integ.maxSpeedMs.toStringAsFixed(2)),
      xSeries: xSeries,
      ySeries: ySeries,
      zSeries: zSeries,
      noiseSeries: noiseSeries,
      positionSeries: integ.displayPositionSeriesM
          .map((v) => double.parse(v.toStringAsFixed(2)))
          .toList(),
      speedSeries: integ.displaySpeedSeriesMs
          .map((v) => double.parse(v.toStringAsFixed(2)))
          .toList(),
      accelSeries: integ.accelSeriesMs2
          .map((v) => double.parse(v.toStringAsFixed(2)))
          .toList(),
      jerkSeries: integ.jerkSeriesMs3
          .map((v) => double.parse(v.toStringAsFixed(2)))
          .toList(),
      sampleRate: sampleRate,
      usedDetectedRideSegment: rideRes.usedDetectedRideSegment,
      constantSpeedRange: constRes.rangeSummary,
      rawSamples: List.from(_buffer),
    );
  }

  static int mathMin(int a, int b) => a < b ? a : b;
}
