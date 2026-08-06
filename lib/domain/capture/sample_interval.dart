import 'dart:math' as math;

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

/// 원본 이벤트의 수신 간격 산출.
///
/// 간격은 반드시 같은 종류의 이벤트끼리만 계산한다.
/// raw(accel)와 gravity 이벤트는 한 파일에 섞여 도착하므로,
/// 종류 구분 없이 간격을 재면 실제 수신 주기의 절반 수준 값이 나와 판정을 왜곡한다.
class SampleInterval {
  /// 목적: 지정 종류 이벤트의 앞뒤 수신 간격을 구한다.
  /// 인자: events — 원본 이벤트 목록 (파일 순서 유지 상태)
  ///       type — 간격을 잴 이벤트 종류
  /// 반환: 간격 목록 (마이크로초). 해당 종류가 2개 미만이면 빈 목록.
  ///       음수·0 간격(타임스탬프 역행)도 그대로 담는다 — 판정은 통계 쪽에서 한다
  /// 근거: 측정 — 수집 주기 편차 판정 자료
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

  /// 목적: 재계산 간격과 기록 당시 dtUs 를 대조해 불일치 수를 센다.
  /// 인자: events — 원본 이벤트 목록, type — 대조할 이벤트 종류
  /// 반환: 불일치 건수. 첫 이벤트(dtUs=0 규약)는 대조에서 제외.
  ///       0이 아니면 기록 과정에 문제가 있다는 뜻이다
  /// 근거: 측정 — 기록 무결성 검증 (RD-5)
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

/// 간격 통계.
///
/// 주기별 수신 확인과 간격 편차 판정의 근거 자료를 만든다.
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

  /// 목적: 간격 목록에서 통계를 구한다.
  /// 인자: intervalsUs — 간격 목록 (마이크로초)
  ///       config — 정상 간격 범위를 담은 설정
  /// 반환: 통계. 목록이 비면 전부 0.
  ///       표준편차는 표본 표준편차(n-1)이며 간격이 1개면 0
  /// 식:   stdDev = sqrt( Σ(x - mean)² / (n - 1) )
  /// 근거: 측정 — 수집 주기 편차 판정 자료.
  ///       정상 범위 경계값은 CaptureConfig 참조 (근거: 미정 상태)
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

  /// 목적: 중앙값으로 실제 수신 주기를 구한다.
  ///       평균을 쓰지 않는 이유는, 운영체제가 가끔 값을 늦게 주는데
  ///       그 몇 개의 큰 간격이 평균을 밀어 주기를 실제보다 낮게 만들기 때문이다.
  /// 인자: 없음
  /// 반환: 주기 (헤르츠). 중앙값이 0 이하면 0
  /// 식:   rateHz = 1,000,000 / medianUs
  /// 근거: 표준 — 단위 정의 (1초 = 1,000,000 마이크로초)
  double get estimatedRateHz {
    if (medianUs <= 0) return 0;
    return 1000000 / medianUs;
  }

  /// 목적: 회의 자료용 요약 글을 만든다.
  /// 인자: label — 자료 제목 (예: 이벤트 종류, 측정 회차)
  ///       config — 목표 주기와 정상 범위 표기용
  /// 반환: 여러 줄 요약 문자열
  /// 근거: 측정 — 판정 근거 제시용 서식
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
    buffer.writeln('  ※ 정상 범위 경계값은 미확정 임시 기준 (CaptureConfig 참조)');
    return buffer.toString();
  }
}
