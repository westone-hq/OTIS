import 'dart:math' as math;

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

/// 목적: 스마트폰에서 데이터가 얼마나 일정한 시간 간격으로 들어오는지(수신 간격)를 계산하고 검증한다.
///       주의할 점은 가속도(accel)와 중력(gravity) 센서 데이터가 섞여서 들어오기 때문에,
///       반드시 같은 종류의 데이터끼리만 묶어서 시간 간격을 재야 한다.
class SampleInterval {
  /// 목적: 지정 종류 이벤트의 앞뒤 수신 간격을 구한다.
  /// 인자: events — 원본 이벤트 목록 (파일 순서 유지 상태)
  ///       type — 간격을 잴 이벤트 종류
  /// 반환: 간격 목록 (마이크로초). 해당 종류가 2개 미만이면 빈 목록.
  ///       음수·0 간격(타임스탬프 역행)도 그대로 담는다 — 판정은 통계 쪽에서 한다
  static List<int> intervalsUs(
    List<NativeEvent> events,
    NativeEventType type,
  ) {
    final result = <int>[];
    int? prevTsUs;
    for (final e in events) {
      if (e.type != type) continue;
      if (prevTsUs != null) {
        result.add(e.tsUs - prevTsUs);
      }
      prevTsUs = e.tsUs;
    }
    return result;
  }

  /// 목적: 나중에 파일을 읽어들였을 때, 파일에 적혀있던 간격(dtUs)과 실제 타임스탬프로 재계산한 간격이 똑같은지 비교해 파일이 깨지지 않았는지 무결성을 검증한다.
  /// 인자: events — 원본 이벤트 목록
  ///       type — 검증할 이벤트 종류
  /// 반환: 불일치 건수 (0이 아니면 파일 기록 과정에 문제가 있었다는 뜻이다)
  static int recordedDtMismatchCount(
    List<NativeEvent> events,
    NativeEventType type,
  ) {
    var mismatch = 0;
    NativeEvent? prev;
    for (final e in events) {
      if (e.type != type) continue;
      if (prev != null) {
        final recomputed = e.tsUs - prev.tsUs;
        if (recomputed > 0 && e.dtUs != recomputed) {
          mismatch++;
        }
      }
      prev = e;
    }
    return mismatch;
  }
}

/// 목적: 센서가 얼마나 안정적으로 데이터를 주었는지 판별하기 위해, 수만 개의 수신 간격들을 모아 통계(최소, 최대, 평균, 표준편차 등)를 낸다.
class IntervalStats {
  const IntervalStats({
    required this.count,
    required this.minUs,
    required this.maxUs,
    required this.meanUs,
    required this.medianUs,
    required this.stdDevUs,
    required this.belowNormalCount,
    required this.aboveNormalCount,
  });

  /// 간격 개수
  final int count;

  /// 최소 간격 (마이크로초)
  final int minUs;

  /// 최대 간격 (마이크로초)
  final int maxUs;

  /// 평균 간격 (마이크로초)
  final double meanUs;

  /// 중앙값 간격 (마이크로초)
  final double medianUs;

  /// 표본 표준편차 (마이크로초)
  final double stdDevUs;

  /// 정상 하한 미만 간격 수 (설정값 기준. 음수·0 포함)
  final int belowNormalCount;

  /// 정상 상한 초과 간격 수 (설정값 기준. 수신 지연·유실 의심)
  final int aboveNormalCount;

  /// 목적: 여러 센서 데이터들의 시간 간격 리스트를 받아와서 최솟값, 최댓값, 중앙값, 표본 표준편차 등 핵심 통계량을 한 번에 계산한다.
  /// 인자: intervalsUs — 센서 수신 간격 목록 (단위: 마이크로초)
  ///       config — 지연/폭주를 판정할 정상 간격 범위 설정값
  /// 반환: 계산이 완료된 IntervalStats 객체 (데이터가 없으면 0으로 채워 반환)
  /// 식: stdDev(표준편차) = sqrt( Σ(x - mean)² / (n - 1) )
  /// 근거: 인용 — 통계학 표본 표준편차(Sample Standard Deviation) 공식
  factory IntervalStats.from(
    List<int> intervalsUs, {
    required CaptureConfig config,
  }) {
    if (intervalsUs.isEmpty) {
      return const IntervalStats(
        count: 0,
        minUs: 0,
        maxUs: 0,
        meanUs: 0,
        medianUs: 0,
        stdDevUs: 0,
        belowNormalCount: 0,
        aboveNormalCount: 0,
      );
    }
    final sorted = List<int>.from(intervalsUs)..sort();
    final n = sorted.length;
    final sum = sorted.fold<int>(0, (a, b) => a + b);
    final mean = sum / n;
    final median = n.isOdd
        ? sorted[n ~/ 2].toDouble()
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
    double stdDev = 0;
    if (n > 1) {
      final sumSq = sorted.fold<double>(
        0,
        (a, b) => a + (b - mean) * (b - mean),
      );
      stdDev = math.sqrt(sumSq / (n - 1));
    }
    var below = 0;
    var above = 0;
    for (final v in intervalsUs) {
      if (v < config.normalIntervalMinUs) below++;
      if (v > config.normalIntervalMaxUs) above++;
    }
    return IntervalStats(
      count: n,
      minUs: sorted.first,
      maxUs: sorted.last,
      meanUs: mean,
      medianUs: median,
      stdDevUs: stdDev,
      belowNormalCount: below,
      aboveNormalCount: above,
    );
  }

  /// 목적: 평균값이 아닌 '중앙값(Median)'을 이용해 스마트폰의 실제 센서 수집 속도(Hz)를 역추산한다.
  ///       (스마트폰이 가끔 데이터를 늦게 줄 때 발생하는 튀는 값(Outlier)이 평균을 왜곡하는 것을 막기 위함)
  /// 인자: 없음
  /// 반환: 추산된 실제 주기 (단위: Hz)
  /// 식: 주파수(Hz) = 1,000,000 / 중앙값(us)
  /// 근거: 인용 — 주파수(Hz)와 주기(T)의 역수 관계 공식
  double get estimatedRateHz {
    if (medianUs <= 0) return 0;
    return 1000000 / medianUs;
  }

  /// 목적: 개발팀 및 엔지니어가 수집 상태를 한눈에 볼 수 있도록, 통계 결과를 사람이 읽기 쉬운 한국어 텍스트로 정리해 반환한다.
  String toReportText({
    required String label,
    required CaptureConfig config,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('[$label] 간격 통계 (단위: 마이크로초)');
    buffer.writeln('  간격 수: $count');
    buffer.writeln('  최소 / 최대: $minUs / $maxUs');
    buffer.writeln(
      '  평균 / 중앙값: ${meanUs.toStringAsFixed(1)} / '
      '${medianUs.toStringAsFixed(1)}',
    );
    buffer.writeln('  표준편차: ${stdDevUs.toStringAsFixed(1)}');
    buffer.writeln(
      '  실측 주기: ${estimatedRateHz.toStringAsFixed(1)} Hz '
      '(목표 ${config.targetSampleRateHz} Hz, '
      '이상 간격 ${config.idealIntervalUs} us)',
    );
    buffer.writeln(
      '  정상 범위 벗어남: 하한(${config.normalIntervalMinUs}) 미만 '
      '$belowNormalCount건, 상한(${config.normalIntervalMaxUs}) 초과 '
      '$aboveNormalCount건',
    );
    buffer.writeln('  ※ 정상 범위 경계값은 CaptureConfig 참조');
    return buffer.toString();
  }
}
