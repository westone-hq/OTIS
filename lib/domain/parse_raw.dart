import 'dart:math' as math;

import 'metrics.dart';
import 'models/measurement_result.dart';

/// P9 · EVIMP1 형식 RAW 텍스트 파일 파싱 및 시계열 변환 유틸
class RawDataParser {
  /// EVIMP1 문자열 데이터를 파싱하여 MeasurementResult 인스턴스를 반환한다.
  /// - 헤더(EVIMP1, 샘플링 레이트) 인식 및 4컬럼(X, Y, Z 진동 mg + 소음 dBA) 파싱
  /// - P10 수치 해석 모듈(VibrationMetrics)을 연동하여 속도, 거리, 저크 시계열 도출
  static MeasurementResult parseEvimp1({
    required String rawContent,
    required String id,
    required String jobNo,
    required String siteName,
    required int bottomFloor,
    required int topFloor,
    required String direction,
    required DateTime dateTime,
  }) {
    final lines = rawContent.split(RegExp(r'\r?\n'));
    int sampleRate = 256;

    final List<double> xList = [];
    final List<double> yList = [];
    final List<double> zList = [];
    final List<double> noiseList = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line == 'EVIMP1') continue;

      // 두 번째 줄 등에서 정수 샘플링 레이트 판별
      if (xList.isEmpty && int.tryParse(line) != null && !line.contains('.')) {
        sampleRate = int.parse(line);
        continue;
      }

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        final x = double.tryParse(parts[0]);
        final y = double.tryParse(parts[1]);
        final z = double.tryParse(parts[2]);
        final noise = double.tryParse(parts[3]);

        if (x != null && y != null && z != null && noise != null) {
          xList.add(x);
          yList.add(y);
          zList.add(z);
          noiseList.add(noise);
        }
      }
    }

    // 데이터가 전혀 없는 경우 안전하게 0 배열 처리
    if (xList.isEmpty) {
      xList.add(0.0);
      yList.add(0.0);
      zList.add(0.0);
      noiseList.add(0.0);
    }

    // P10 수치 해석 모듈을 통해 P2P 및 최대값 산출
    final double xPtp = VibrationMetrics.calculateP2P(xList);
    final double yPtp = VibrationMetrics.calculateP2P(yList);
    final double zPtp = VibrationMetrics.calculateP2P(zList);
    final double noiseMax = VibrationMetrics.calculateMax(noiseList);

    // Z축 진동/가속도 기반으로 속도, 이동 거리, 저크 산출
    final double sr = sampleRate.toDouble();
    final speedList = VibrationMetrics.calculateSpeedSeries(zList, sampleRate: sr);
    final posList = VibrationMetrics.calculatePositionSeries(speedList, sampleRate: sr);
    final jerkList = VibrationMetrics.calculateJerkSeries(zList, sampleRate: sr);

    final double distance = posList.isNotEmpty
        ? double.parse(posList.last.toStringAsFixed(1))
        : 0.0;
    final double maxSpeed = speedList.isNotEmpty
        ? double.parse(speedList.reduce(math.max).toStringAsFixed(2))
        : 0.0;

    return MeasurementResult(
      id: id,
      jobNo: jobNo,
      siteName: siteName,
      bottomFloor: bottomFloor,
      topFloor: topFloor,
      direction: direction,
      dateTime: dateTime,
      xPtp: xPtp,
      yPtp: yPtp,
      zPtp: zPtp,
      noiseMax: noiseMax,
      distance: distance,
      maxSpeed: maxSpeed,
      xSeries: xList,
      ySeries: yList,
      zSeries: zList,
      noiseSeries: noiseList,
      positionSeries: posList,
      speedSeries: speedList,
      accelSeries: zList,
      jerkSeries: jerkList,
    );
  }
}
