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
        accelSeries: [
          double.parse(
            (s.z * SensorSample.mgToMetersPerSecondSquared).toStringAsFixed(2),
          ),
        ],
        jerkSeries: [0.0],
        sampleRate: 256.0,
        usedDetectedRideSegment: false,
        constantSpeedRange: '전체 구간',
        rawSamples: List.from(_buffer),
      );
    }

    // 1. 거리/속도용 모션 소스 구성 및 기준선 보정
    final motionSourceSamples = _buildMotionSourceSamples(_buffer);
    final correctedMotionSamples = SignalFilters.applyBaselineCorrection(
      motionSourceSamples,
      baselineSec: config.baselineSec,
    );

    // 2. 실측 샘플레이트 도출
    final double sampleRate = SignalFilters.estimateSampleRate(_buffer);

    // 3. 진동용 성분 분리
    // 거리/속도 적분과 분리하여 출발·정지 저주파 이동 성분을 제거한 신호로 Aptp를 산출한다.
    final sep = SignalFilters.separateMotionAndVibration(
      _buffer,
      sampleRate: sampleRate,
      cutoffHz: config.vibrationHighpassCutoffHz,
      cutoffHzX: config.vibrationHighpassCutoffHzX,
      cutoffHzY: config.vibrationHighpassCutoffHzY,
      cutoffHzZ: config.vibrationHighpassCutoffHzZ,
      lowpassCutoffHz: config.vibrationLowpassCutoffHz,
      lowpassCutoffHzX: config.vibrationLowpassCutoffHzX,
      lowpassCutoffHzY: config.vibrationLowpassCutoffHzY,
      lowpassCutoffHzZ: config.vibrationLowpassCutoffHzZ,
      filterTypeX: config.vibrationFilterTypeX,
      filterTypeY: config.vibrationFilterTypeY,
      filterTypeZ: config.vibrationFilterTypeZ,
      wdTransitionHz: config.wdTransitionHz,
      wdTransitionQ: config.wdTransitionQ,
    );

    // 4. 수직축 적분 (속도, 거리, 저크)
    // 진동용 linear acceleration과 분리하여, 가능하면 raw accelerometer - gravity 기반 모션 성분을 사용한다.
    final integ = MotionIntegrator.integrate(
      correctedMotionSamples,
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
    final int safeEnd = mathMin(
      rideRes.endIndex,
      integ.displaySpeedSeriesMs.length - 1,
    );
    final int safeStart = mathMin(rideRes.startIndex, safeEnd);
    final rideSpeedSub = integ.displaySpeedSeriesMs.sublist(
      safeStart,
      safeEnd + 1,
    );

    final constRes = RideDetector.detectConstantSpeedRange(
      rideRes.samples,
      rideSpeedSub,
      constantRatio: config.constantSpeedRatio,
    );

    // 7. 지표 산출 (Aptp, noiseMax)
    final int rawRideStart = mathMax(0, rideRes.startIndex);
    final int rawRideEnd = mathMin(rideRes.endIndex, _buffer.length - 1);
    final rawRideSamples = _buffer.sublist(rawRideStart, rawRideEnd + 1);
    final int rawConstStart = mathMin(
      constRes.startIndex,
      rawRideSamples.length - 1,
    );
    final int rawConstEnd = mathMin(
      constRes.endIndex,
      rawRideSamples.length - 1,
    );
    final rawConstSamples = rawRideSamples.sublist(
      rawConstStart,
      rawConstEnd + 1,
    );

    final rideX = rideRes.samples.map((s) => s.x).toList();
    final rideY = rideRes.samples.map((s) => s.y).toList();
    final rideZ = rideRes.samples.map((s) => s.z).toList();
    final constX = constRes.samples.map((s) => s.x).toList();
    final constY = constRes.samples.map((s) => s.y).toList();
    final constZ = constRes.samples.map((s) => s.z).toList();
    final rawRideX = rawRideSamples.map((s) => s.x).toList();
    final rawRideY = rawRideSamples.map((s) => s.y).toList();
    final rawRideZ = rawRideSamples.map((s) => s.z).toList();
    final rawConstX = rawConstSamples.map((s) => s.x).toList();
    final rawConstY = rawConstSamples.map((s) => s.y).toList();
    final rawConstZ = rawConstSamples.map((s) => s.z).toList();
    final constantRatio = sep.vibration.isEmpty
        ? 0.0
        : constRes.samples.length / sep.vibration.length;

    final fullXPtp = VibrationMetrics.calculateP2P(rideX);
    final fullYPtp = VibrationMetrics.calculateP2P(rideY);
    final fullZPtp = VibrationMetrics.calculateP2P(rideZ);
    final constantXPtp = VibrationMetrics.calculateP2P(constX);
    final constantYPtp = VibrationMetrics.calculateP2P(constY);
    final constantZPtp = VibrationMetrics.calculateP2P(constZ);
    final preFilterFullXPtp = VibrationMetrics.calculateP2P(rawRideX);
    final preFilterFullYPtp = VibrationMetrics.calculateP2P(rawRideY);
    final preFilterFullZPtp = VibrationMetrics.calculateP2P(rawRideZ);
    final preFilterConstantXPtp = VibrationMetrics.calculateP2P(rawConstX);
    final preFilterConstantYPtp = VibrationMetrics.calculateP2P(rawConstY);
    final preFilterConstantZPtp = VibrationMetrics.calculateP2P(rawConstZ);

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

    final double noiseMax = VibrationMetrics.calculateNoiseMax(
      constRes.samples,
    );

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
      fullXPtp: fullXPtp,
      fullYPtp: fullYPtp,
      fullZPtp: fullZPtp,
      constantXPtp: constantXPtp,
      constantYPtp: constantYPtp,
      constantZPtp: constantZPtp,
      preFilterFullXPtp: preFilterFullXPtp,
      preFilterFullYPtp: preFilterFullYPtp,
      preFilterFullZPtp: preFilterFullZPtp,
      preFilterConstantXPtp: preFilterConstantXPtp,
      preFilterConstantYPtp: preFilterConstantYPtp,
      preFilterConstantZPtp: preFilterConstantZPtp,
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
      usedDetectedConstantSpeed: constRes.isDetected,
      constantSpeedSampleCount: constRes.samples.length,
      totalVibrationSampleCount: sep.vibration.length,
      constantSpeedRatio: constantRatio,
      rawSamples: List.from(_buffer),
      debugMetrics: _buildDebugMetrics(
        config: config,
        sampleRate: sampleRate,
        linearSamples: _buffer,
        motionSamples: correctedMotionSamples,
        integ: integ,
      ),
    );
  }

  static int mathMin(int a, int b) => a < b ? a : b;
  static int mathMax(int a, int b) => a > b ? a : b;

  List<SensorSample> _buildMotionSourceSamples(List<SensorSample> samples) {
    return samples
        .map(
          (sample) => SensorSample(
            tsUs: sample.tsUs,
            x: sample.motionX,
            y: sample.motionY,
            z: sample.motionZ,
            noiseDba: sample.noiseDba,
            rawX: sample.rawX,
            rawY: sample.rawY,
            rawZ: sample.rawZ,
            gravityX: sample.gravityX,
            gravityY: sample.gravityY,
            gravityZ: sample.gravityZ,
          ),
        )
        .toList();
  }

  Map<String, double> _buildDebugMetrics({
    required MetricsConfig config,
    required double sampleRate,
    required List<SensorSample> linearSamples,
    required List<SensorSample> motionSamples,
    required IntegrationResult integ,
  }) {
    final linearZValues = linearSamples.map((sample) => sample.z).toList();
    final motionZValues = motionSamples.map((sample) => sample.z).toList();
    final rawZValues = linearSamples
        .where((sample) => sample.rawZ != null)
        .map((sample) => sample.rawZ!)
        .toList();
    final gravityZValues = linearSamples
        .where((sample) => sample.gravityZ != null)
        .map((sample) => sample.gravityZ!)
        .toList();

    return {
      'sampleRate': sampleRate,
      'linearZMin': _minOrZero(linearZValues),
      'linearZMax': _maxOrZero(linearZValues),
      'rawZMin': _minOrZero(rawZValues),
      'rawZMax': _maxOrZero(rawZValues),
      'gravityZMin': _minOrZero(gravityZValues),
      'gravityZMax': _maxOrZero(gravityZValues),
      'motionZMin': _minOrZero(motionZValues),
      'motionZMax': _maxOrZero(motionZValues),
      'maxAccelMs2': _maxAbsOrZero(integ.accelSeriesMs2),
      'velocityMax': integ.maxSpeedMs,
      'distanceRaw': integ.distanceM,
      'vibrationHighpassX': config.vibrationHighpassCutoffHzX,
      'vibrationHighpassY': config.vibrationHighpassCutoffHzY,
      'vibrationHighpassZ': config.vibrationHighpassCutoffHzZ,
      'vibrationLowpassX': config.vibrationLowpassCutoffHzX,
      'vibrationLowpassY': config.vibrationLowpassCutoffHzY,
      'vibrationLowpassZ': config.vibrationLowpassCutoffHzZ,
    };
  }

  double _minOrZero(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a < b ? a : b);
  }

  double _maxOrZero(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double _maxAbsOrZero(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.map((value) => value.abs()).reduce((a, b) => a > b ? a : b);
  }
}
