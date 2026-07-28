import 'dart:math' as math;
import 'metrics_config.dart';
import 'sensor_sample.dart';

/// 이동 성분(Motion)과 진동 성분(Vibration) 분리 결과
class MotionAndVibration {
  final List<SensorSample> motion;
  final List<SensorSample> vibration;

  const MotionAndVibration({required this.motion, required this.vibration});
}

/// 2차 Butterworth biquad 필터 계수 (Direct Form II Transposed)
/// - 아날로그 프로토타입(Q=1/√2, maximally flat)을 bilinear 변환으로 이산화
class _BiquadCoeffs {
  final double b0, b1, b2, a1, a2;
  const _BiquadCoeffs(this.b0, this.b1, this.b2, this.a1, this.a2);
}

/// Direct Form II Transposed biquad 필터 (인과, 순방향 1회 적용)
class _Biquad {
  final _BiquadCoeffs c;
  double _z1 = 0.0;
  double _z2 = 0.0;

  _Biquad(this.c);

  double process(double x) {
    final double y = c.b0 * x + _z1;
    _z1 = c.b1 * x - c.a1 * y + _z2;
    _z2 = c.b2 * x - c.a2 * y;
    return y;
  }
}

/// 측정 신호 전처리 및 필터링 (기준선 보정, 샘플레이트 도출, 성분 분리)
class SignalFilters {
  /// 1. 기준선 보정 (Baseline Correction)
  /// - 측정 시작 후 처음 [baselineSec]초 동안의 평균 가속도를 정지 상태 0점으로 가정하고 3축에서 차감
  static List<SensorSample> applyBaselineCorrection(
    List<SensorSample> samples, {
    double baselineSec = 1.0,
  }) {
    if (samples.isEmpty) return [];
    if (samples.length == 1) {
      final s = samples.first;
      return [
        SensorSample(
          tsUs: s.tsUs,
          x: 0.0,
          y: 0.0,
          z: 0.0,
          noiseDba: s.noiseDba,
          rawX: s.rawX,
          rawY: s.rawY,
          rawZ: s.rawZ,
          gravityX: s.gravityX,
          gravityY: s.gravityY,
          gravityZ: s.gravityZ,
        ),
      ];
    }

    final int startTsUs = samples.first.tsUs;
    final int baselineDurationUs = (baselineSec * 1000000.0).round();
    final int endTsUs = startTsUs + baselineDurationUs;

    final baselineSamples = samples.where((s) => s.tsUs <= endTsUs).toList();

    final effectiveSamples = baselineSamples.isNotEmpty
        ? baselineSamples
        : [samples.first];

    double sumX = 0.0;
    double sumY = 0.0;
    double sumZ = 0.0;
    for (final s in effectiveSamples) {
      sumX += s.x;
      sumY += s.y;
      sumZ += s.z;
    }
    final double avgX = sumX / effectiveSamples.length;
    final double avgY = sumY / effectiveSamples.length;
    final double avgZ = sumZ / effectiveSamples.length;

    return samples
        .map(
          (s) => SensorSample(
            tsUs: s.tsUs,
            x: s.x - avgX,
            y: s.y - avgY,
            z: s.z - avgZ,
            noiseDba: s.noiseDba,
            rawX: s.rawX,
            rawY: s.rawY,
            rawZ: s.rawZ,
            gravityX: s.gravityX,
            gravityY: s.gravityY,
            gravityZ: s.gravityZ,
          ),
        )
        .toList();
  }

  /// 2. 실측 샘플레이트 도출 (Estimate Sample Rate)
  /// - 타임스탬프 간격(dt)의 중앙값(Median)을 이용해 정확한 샘플링 주파수(Hz) 산출
  static double estimateSampleRate(List<SensorSample> samples) {
    if (samples.length < 2) return 256.0; // 기본 폴백

    final List<double> dtSeconds = [];
    for (int i = 1; i < samples.length; i++) {
      final int dtUs = samples[i].tsUs - samples[i - 1].tsUs;
      if (dtUs > 0) {
        dtSeconds.add(dtUs / 1000000.0);
      }
    }

    if (dtSeconds.isEmpty) return 256.0;

    dtSeconds.sort();
    final double medianDt = dtSeconds[dtSeconds.length ~/ 2];
    if (medianDt <= 0.0) return 256.0;

    final double rate = 1.0 / medianDt;
    // 비정상적인 값 클램핑 (10Hz ~ 2000Hz 범위)
    return rate.clamp(10.0, 2000.0);
  }

  /// 3. 성분 분리 (Motion vs Vibration Separation)
  /// - motion(거리/속도용): 샘플레이트와 컷오프 주파수에 기반한 중심 이동평균 (LPF), 변경 없음
  /// - vibration(진동 지표용): 축별 필터 종류(MetricsConfig.vibrationFilterTypeX/Y/Z)에 따라
  ///   Z축은 2차 Butterworth band-limit(HP→LP) biquad, X/Y축은 ISO 8041 Wd 캐스케이드
  ///   (band-limit HP → band-limit LP → 가속도-속도 천이)를 인과(causal) 적용
  static MotionAndVibration separateMotionAndVibration(
    List<SensorSample> samples, {
    double sampleRate = 256.0,
    double cutoffHz = 0.8,
    double? cutoffHzX,
    double? cutoffHzY,
    double? cutoffHzZ,
    double? lowpassCutoffHz,
    double? lowpassCutoffHzX,
    double? lowpassCutoffHzY,
    double? lowpassCutoffHzZ,
    VibrationFilterType filterTypeX = VibrationFilterType.butterworthBandLimit,
    VibrationFilterType filterTypeY = VibrationFilterType.butterworthBandLimit,
    VibrationFilterType filterTypeZ = VibrationFilterType.butterworthBandLimit,
    double wdTransitionHz = 2.0,
    double wdTransitionQ = 0.63,
    double wkTransitionHz = 12.5,
    double wkTransitionQ = 0.63,
    double wkUpwardStepHz = 2.37,
    double wkUpwardStepHighHz = 3.3,
    double wkUpwardStepQ = 0.91,
  }) {
    if (samples.isEmpty) {
      return const MotionAndVibration(motion: [], vibration: []);
    }
    if (samples.length <= 2 || cutoffHz <= 0.0) {
      return MotionAndVibration(
        motion: List.from(samples),
        vibration: samples
            .map(
              (s) => SensorSample(tsUs: s.tsUs, x: 0, y: 0, z: 0, noiseDba: 0),
            )
            .toList(),
      );
    }

    final effectiveCutoffX = cutoffHzX ?? cutoffHz;
    final effectiveCutoffY = cutoffHzY ?? cutoffHz;
    final effectiveCutoffZ = cutoffHzZ ?? cutoffHz;
    final lowpassX = _centeredMovingAverage(
      samples.map((s) => s.x).toList(),
      sampleRate: sampleRate,
      cutoffHz: effectiveCutoffX,
    );
    final lowpassY = _centeredMovingAverage(
      samples.map((s) => s.y).toList(),
      sampleRate: sampleRate,
      cutoffHz: effectiveCutoffY,
    );
    final lowpassZ = _centeredMovingAverage(
      samples.map((s) => s.z).toList(),
      sampleRate: sampleRate,
      cutoffHz: effectiveCutoffZ,
    );

    // 진동 성분의 HP/LP/천이 필터는 축별 필터 종류(MetricsConfig)에 따라 산출한다.
    // (거리/속도용 motion 분리는 위 _centeredMovingAverage 결과를 그대로 사용, 변경하지 않음)
    final effectiveLowpassX = lowpassCutoffHzX ?? lowpassCutoffHz;
    final effectiveLowpassY = lowpassCutoffHzY ?? lowpassCutoffHz;
    final effectiveLowpassZ = lowpassCutoffHzZ ?? lowpassCutoffHz;

    final vibrationX = _computeAxisVibration(
      samples.map((s) => s.x).toList(),
      sampleRate: sampleRate,
      filterType: filterTypeX,
      highpassHz: effectiveCutoffX,
      lowpassHz: effectiveLowpassX,
      wdTransitionHz: wdTransitionHz,
      wdTransitionQ: wdTransitionQ,
    );
    final vibrationY = _computeAxisVibration(
      samples.map((s) => s.y).toList(),
      sampleRate: sampleRate,
      filterType: filterTypeY,
      highpassHz: effectiveCutoffY,
      lowpassHz: effectiveLowpassY,
      wdTransitionHz: wdTransitionHz,
      wdTransitionQ: wdTransitionQ,
    );
    final vibrationZ = _computeAxisVibration(
      samples.map((s) => s.z).toList(),
      sampleRate: sampleRate,
      filterType: filterTypeZ,
      highpassHz: effectiveCutoffZ,
      lowpassHz: effectiveLowpassZ,
      wdTransitionHz: wdTransitionHz,
      wdTransitionQ: wdTransitionQ,
      wkTransitionHz: wkTransitionHz,
      wkTransitionQ: wkTransitionQ,
      wkUpwardStepHz: wkUpwardStepHz,
      wkUpwardStepHighHz: wkUpwardStepHighHz,
      wkUpwardStepQ: wkUpwardStepQ,
    );

    final List<SensorSample> motion = [];
    final List<SensorSample> vibration = [];
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final double motX = lowpassX[i];
      final double motY = lowpassY[i];
      final double motZ = lowpassZ[i];
      motion.add(
        SensorSample(
          tsUs: s.tsUs,
          x: motX,
          y: motY,
          z: motZ,
          noiseDba: s.noiseDba,
        ),
      );
      vibration.add(
        SensorSample(
          tsUs: s.tsUs,
          x: vibrationX[i],
          y: vibrationY[i],
          z: vibrationZ[i],
          noiseDba: s.noiseDba,
        ),
      );
    }

    return MotionAndVibration(motion: motion, vibration: vibration);
  }

  static List<double> _centeredMovingAverage(
    List<double> values, {
    required double sampleRate,
    required double cutoffHz,
  }) {
    if (values.isEmpty) return [];
    if (values.length <= 2 || cutoffHz <= 0.0) return List.from(values);

    int windowSize = (sampleRate / cutoffHz).round();
    if (windowSize < 3) windowSize = 3;
    if (windowSize % 2 == 0) windowSize += 1;
    final int halfWindow = windowSize ~/ 2;

    final List<double> result = [];
    double currentSum = 0.0;
    int currentStart = 0;
    int currentEnd = -1;

    for (int i = 0; i < values.length; i++) {
      final int targetStart = math.max(0, i - halfWindow);
      final int targetEnd = math.min(values.length - 1, i + halfWindow);

      while (currentEnd < targetEnd) {
        currentEnd++;
        currentSum += values[currentEnd];
      }
      while (currentStart < targetStart) {
        currentSum -= values[currentStart];
        currentStart++;
      }

      final int count = targetEnd - targetStart + 1;
      result.add(currentSum / count);
    }

    return result;
  }

  /// Nyquist 안전 가드: 컷오프가 0.45 × sampleRate를 초과하면 클램프
  static double _clampCutoff(double cutoffHz, double sampleRate) {
    final double maxCutoff = 0.45 * sampleRate;
    return cutoffHz > maxCutoff ? maxCutoff : cutoffHz;
  }

  /// 2차 Butterworth high-pass 계수 (아날로그 프로토타입 Q=1/√2 → bilinear 변환, RBJ Cookbook)
  static _BiquadCoeffs _highpassCoeffs(double sampleRate, double cutoffHz) {
    final double fc = _clampCutoff(cutoffHz, sampleRate);
    final double w0 = 2 * math.pi * fc / sampleRate;
    final double cosw0 = math.cos(w0);
    final double sinw0 = math.sin(w0);
    const double q = 0.7071067811865476; // 1/sqrt(2), maximally flat
    final double alpha = sinw0 / (2 * q);

    final double a0 = 1 + alpha;
    final double b0 = (1 + cosw0) / 2;
    final double b1 = -(1 + cosw0);
    final double b2 = (1 + cosw0) / 2;
    final double a1 = -2 * cosw0;
    final double a2 = 1 - alpha;

    return _BiquadCoeffs(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  /// 2차 Butterworth low-pass 계수 (아날로그 프로토타입 Q=1/√2 → bilinear 변환, RBJ Cookbook)
  static _BiquadCoeffs _lowpassCoeffs(double sampleRate, double cutoffHz) {
    final double fc = _clampCutoff(cutoffHz, sampleRate);
    final double w0 = 2 * math.pi * fc / sampleRate;
    final double cosw0 = math.cos(w0);
    final double sinw0 = math.sin(w0);
    const double q = 0.7071067811865476; // 1/sqrt(2), maximally flat
    final double alpha = sinw0 / (2 * q);

    final double a0 = 1 + alpha;
    final double b0 = (1 - cosw0) / 2;
    final double b1 = 1 - cosw0;
    final double b2 = (1 - cosw0) / 2;
    final double a1 = -2 * cosw0;
    final double a2 = 1 - alpha;

    return _BiquadCoeffs(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }

  /// 인과(causal, 순방향 1회) biquad 적용. filtfilt(영위상) 미사용.
  static List<double> _applyBiquadCausal(
    List<double> values,
    _BiquadCoeffs coeffs,
  ) {
    final biquad = _Biquad(coeffs);
    final List<double> result = List<double>.filled(values.length, 0.0);
    for (int i = 0; i < values.length; i++) {
      result[i] = biquad.process(values[i]);
    }
    return result;
  }

  static List<double> _applyButterworthHighpass(
    List<double> values, {
    required double sampleRate,
    required double cutoffHz,
  }) {
    if (values.isEmpty) return [];
    if (values.length <= 2 || cutoffHz <= 0.0) return List.from(values);
    return _applyBiquadCausal(values, _highpassCoeffs(sampleRate, cutoffHz));
  }

  static List<double> _applyButterworthLowpass(
    List<double> values, {
    required double sampleRate,
    required double cutoffHz,
  }) {
    if (values.isEmpty) return [];
    if (values.length <= 2 || cutoffHz <= 0.0) return List.from(values);
    return _applyBiquadCausal(values, _lowpassCoeffs(sampleRate, cutoffHz));
  }

  /// 축 1개의 진동 성분 계산: 필터 종류에 따라 분기
  /// - butterworthBandLimit: HP(highpassHz) → 선택적 LP(lowpassHz)
  /// - isoWdWeighting: HP(highpassHz) → LP(lowpassHz) → 가속도-속도 천이(wdTransitionHz, wdTransitionQ)
  /// - isoWkWeighting: HP → LP → Wk 천이(12.5Hz) → upward-step(2.37/3.3Hz)
  static List<double> _computeAxisVibration(
    List<double> raw, {
    required double sampleRate,
    required VibrationFilterType filterType,
    required double highpassHz,
    double? lowpassHz,
    required double wdTransitionHz,
    required double wdTransitionQ,
    double wkTransitionHz = 12.5,
    double wkTransitionQ = 0.63,
    double wkUpwardStepHz = 2.37,
    double wkUpwardStepHighHz = 3.3,
    double wkUpwardStepQ = 0.91,
  }) {
    final hp = _applyButterworthHighpass(
      raw,
      sampleRate: sampleRate,
      cutoffHz: highpassHz,
    );
    final lp = (lowpassHz != null && lowpassHz > 0.0)
        ? _applyButterworthLowpass(hp, sampleRate: sampleRate, cutoffHz: lowpassHz)
        : hp;

    if (filterType == VibrationFilterType.isoWdWeighting) {
      return _applyWdTransition(
        lp,
        sampleRate: sampleRate,
        transitionHz: wdTransitionHz,
        transitionQ: wdTransitionQ,
      );
    }
    if (filterType == VibrationFilterType.isoWkWeighting) {
      final transitioned = _applyWdTransition(
        lp,
        sampleRate: sampleRate,
        transitionHz: wkTransitionHz,
        transitionQ: wkTransitionQ,
      );
      return _applyWkUpwardStep(
        transitioned,
        sampleRate: sampleRate,
        stepHz: wkUpwardStepHz,
        stepHighHz: wkUpwardStepHighHz,
        stepQ: wkUpwardStepQ,
      );
    }
    return lp;
  }

  /// 아날로그 주파수(Hz)를 표본화 주파수 기준 bilinear 변환 사전왜곡(pre-warp)한 각속도(rad/s)로 변환
  /// - Nyquist 안전 가드(0.45 × sampleRate)를 먼저 적용
  static double _prewarpOmega(double freqHz, double sampleRate) {
    final double fc = _clampCutoff(freqHz, sampleRate);
    return 2 * sampleRate * math.tan(math.pi * fc / sampleRate);
  }

  /// 일반 2차 아날로그 전달함수 (B2·s² + B1·s + B0) / (A2·s² + A1·s + A0)를
  /// K = 2·sampleRate 고정 bilinear 변환(s = K(z-1)/(z+1))으로 이산화한다.
  /// 특성 주파수는 호출부에서 [_prewarpOmega]로 미리 사전왜곡해 전달해야 -3dB/특성점이 정확히 맞는다.
  /// (RBJ Cookbook 형태의 [_highpassCoeffs]/[_lowpassCoeffs]와 수치적으로 동일한 결과를 내는
  /// 동일 원리의 변환이며, 영점을 갖는 천이 필터처럼 해당 템플릿이 없는 경우에 사용한다.)
  static _BiquadCoeffs _bilinearTransform({
    required double b2,
    required double b1,
    required double b0,
    required double a2,
    required double a1,
    required double a0,
  }) {
    final double n0 = b2 + b1 + b0;
    final double n1 = -2 * b2 + 2 * b0;
    final double n2 = b2 - b1 + b0;

    final double d0 = a2 + a1 + a0;
    final double d1 = -2 * a2 + 2 * a0;
    final double d2 = a2 - a1 + a0;

    return _BiquadCoeffs(n0 / d0, n1 / d0, n2 / d0, d1 / d0, d2 / d0);
  }

  /// ISO 8041 Wd 가속도-속도 천이(transition) 필터 계수
  /// H_t(s) = (ω4²/ω3)·(s + ω3) / (s² + (ω4/Q4)·s + ω4²), f3 = f4 (본 구현에서는 wdTransitionHz 하나로 표현)
  /// K = 2·sampleRate 고정 bilinear 변환 전, ω3 = ω4 = 2π·wdTransitionHz를 사전왜곡한다.
  /// B/A 계수는 K²으로 정규화한 형태(즉 K=1 기준)로 [_bilinearTransform]에 전달한다.
  static _BiquadCoeffs _wdTransitionCoeffs(
    double sampleRate,
    double transitionHz,
    double transitionQ,
  ) {
    final double omega = _prewarpOmega(transitionHz, sampleRate); // ω3 = ω4
    final double k = 2 * sampleRate;
    final double r = omega / k; // ω/K, K²으로 정규화하기 위한 무차원 비율

    // 원식: B1=ω4²/ω3=ω, B0=ω4²=ω², A2=1, A1=ω4/Q4=ω/Q4, A0=ω4²=ω²
    // 전체를 K²으로 나누어 무차원화: B2=0, B1=r, B0=r², A2=1, A1=r/Q4, A0=r²
    return _bilinearTransform(
      b2: 0.0,
      b1: r,
      b0: r * r,
      a2: 1.0,
      a1: r / transitionQ,
      a0: r * r,
    );
  }

  static List<double> _applyWdTransition(
    List<double> values, {
    required double sampleRate,
    required double transitionHz,
    required double transitionQ,
  }) {
    if (values.isEmpty) return [];
    if (values.length <= 2 || transitionHz <= 0.0) return List.from(values);
    return _applyBiquadCausal(
      values,
      _wdTransitionCoeffs(sampleRate, transitionHz, transitionQ),
    );
  }

  /// ISO 8041 Wk upward-step 필터 계수
  /// Hs(s) = (Q5·s² + ω5²) / (s² + (ω6/Q6)·s + ω6²)
  static _BiquadCoeffs _wkUpwardStepCoeffs(
    double sampleRate,
    double stepHz,
    double stepHighHz,
    double stepQ,
  ) {
    final double omega5 = _prewarpOmega(stepHz, sampleRate);
    final double omega6 = _prewarpOmega(stepHighHz, sampleRate);
    return _bilinearTransform(
      b2: stepQ,
      b1: 0.0,
      b0: omega5 * omega5,
      a2: 1.0,
      a1: omega6 / stepQ,
      a0: omega6 * omega6,
    );
  }

  static List<double> _applyWkUpwardStep(
    List<double> values, {
    required double sampleRate,
    required double stepHz,
    required double stepHighHz,
    required double stepQ,
  }) {
    if (values.isEmpty) return [];
    if (values.length <= 2 || stepHz <= 0.0 || stepHighHz <= 0.0) {
      return List.from(values);
    }
    return _applyBiquadCausal(
      values,
      _wkUpwardStepCoeffs(sampleRate, stepHz, stepHighHz, stepQ),
    );
  }
}
