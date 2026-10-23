import 'dart:math' as math;

import 'package:vibration_checker/domain/analysis/half_cycle.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';

/// 작성: 2026-10-21 13:10:00 · 박건준
/// 클래스: MotionZones
/// 목적: 운행 한 번을 정속 구간과 가감속 구간으로 나눈 결과. 첨자는 100Hz
///       격자 기준이고 끝 첨자를 포함한다.
///       - 운행 = `runStartIndex` ~ `runEndIndex`
///       - 정속 = `steadyStartIndex` ~ `steadyEndIndex`
///       - 가감속 = 운행 − 정속 (운행 시작 ~ 정속 시작 앞, 정속 끝 뒤 ~
///         운행 끝)
///       OTIS 리포트 2쪽 수직 차트의 `a_z,ptp` 는 정속 구간의, `a_z,Jptp` 는
///       가감속 구간의 반주기 P2P 최대다(2026-10-21 오티스폰 원시데이터로
///       재계산해 확인, 1 · 2회는 최대가 나온 시각까지 같다).
class MotionZones {
  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: MotionZones
  /// 목적: 구간 첨자를 그대로 담는다.
  /// 인자: runStartIndex, runEndIndex — 운행 첫 · 끝 첨자
  ///       steadyStartIndex, steadyEndIndex — 정속 첫 · 끝 첨자
  ///       sampleRate — 첨자를 초로 바꿀 표본 주기 (Hz)
  const MotionZones({
    required this.runStartIndex,
    required this.runEndIndex,
    required this.steadyStartIndex,
    required this.steadyEndIndex,
    required this.sampleRate,
  });

  /// 운행 첫 첨자
  final int runStartIndex;

  /// 운행 끝 첨자 (포함)
  final int runEndIndex;

  /// 정속 첫 첨자
  final int steadyStartIndex;

  /// 정속 끝 첨자 (포함)
  final int steadyEndIndex;

  /// 첨자를 초로 바꿀 표본 주기 (Hz)
  final double sampleRate;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: steadyStartSec
  /// 목적: 정속 시작 시각 (초, 격자 첫 행 기준).
  double get steadyStartSec => steadyStartIndex / sampleRate;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: steadyEndSec
  /// 목적: 정속 끝 시각 (초, 격자 첫 행 기준).
  double get steadyEndSec => steadyEndIndex / sampleRate;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 수정: 2026-10-22 15:40:00 · 박건준
  /// 함수: methodLabel
  /// 목적: 구간을 나눈 방식을 결과 파일(result.json `signalConditioning`)에
  ///       남길 문자열. 이 표시가 없는 2026-10-21 전 결과의 수직 최대
  ///       (`zPtp`)는 운행 구간(출발 · 정지 0.5 m 제외) 전체의 최대라 가감속
  ///       구간이 섞여 있고 `zJptp` 가 없다.
  ///       - `zones(v>속도,pk비율,a<가속도,min길이ms,jpad넓힘ms)` — `of()` 의
  ///         네 상수와 Jptp 구간을 넓힌 길이. `jpad` 가 없는 2026-10-22 전
  ///         결과의 Jptp 는 운행(|v| > 문턱) 안에서만 낸 값이다
  static String get methodLabel =>
      'zones(v>${CaptureConfig.zoneRunSpeedMps},'
      'pk${CaptureConfig.zonePeakRatio},'
      'a<${CaptureConfig.zoneSteadyAccelMps2},'
      'min${CaptureConfig.zoneMinimumSteadyMs}ms,'
      'jpad${CaptureConfig.zoneTransientPaddingMs}ms)';

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: steadyMaximum
  /// 목적: 정속 구간 안 최대 반주기 P2P 를 찾는다. 리포트 1쪽 "수직진동,
  ///       최대" 와 2쪽 수직 차트 `ptp` 다.
  /// 인자: series — 가중한 진동 시계열 (mg, 이 구간과 같은 격자)
  /// 반환: 최대 반주기 P2P. 반주기가 두 개도 안 되면 null
  HalfCyclePeakToPeak? steadyMaximum(List<double> series) {
    if (steadyEndIndex >= series.length) return null;
    // → 로직 이동: HalfCycle.maximum()
    return HalfCycle.maximum(
      series,
      start: steadyStartIndex,
      end: steadyEndIndex,
    );
  }

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 수정: 2026-10-22 19:00:00 · 박건준
  /// 함수: transientMaximum
  /// 목적: 가감속 구간 안 최대 반주기 P2P 를 찾는다. 2쪽 수직 차트 `Jptp`
  ///       다. 가감속 구간은 운행 시작 `CaptureConfig.zoneTransientPaddingMs`
  ///       앞 ~ 정속 앞, 정속 뒤 ~ 운행 끝 같은 길이 뒤다(기록 끝에서 자른다).
  ///       속도가 문턱을 넘기 전 출발 충격을 넣기 위해서다(2026-10-22). 두
  ///       조각을 따로 세고(정속 구간을 건너 이웃 봉우리를 잇지 않는다) 큰
  ///       쪽을 고른다.
  /// 인자: series — 가중한 진동 시계열 (mg, 이 구간과 같은 격자)
  /// 반환: 최대 반주기 P2P. 두 조각 모두 반주기가 두 개도 안 되면 null
  HalfCyclePeakToPeak? transientMaximum(List<double> series) {
    if (runEndIndex >= series.length) return null;
    final pad = _transientPadRows; // 운행 앞뒤로 넓힐 행 수
    HalfCyclePeakToPeak? best; // 두 조각 가운데 큰 것
    for (final (start, end) in <(int, int)>[
      (math.max(0, runStartIndex - pad), steadyStartIndex - 1),
      (steadyEndIndex + 1, math.min(series.length - 1, runEndIndex + pad)),
    ]) {
      if (end <= start) continue;
      // → 로직 이동: HalfCycle.maximum()
      final found = HalfCycle.maximum(series, start: start, end: end);
      if (found != null && (best == null || found.value > best.value)) {
        best = found;
      }
    }
    return best;
  }

  /// 작성: 2026-10-22 19:00:00 · 박건준
  /// 함수: _transientPadRows
  /// 목적: 가감속 구간을 운행 앞뒤로 넓힐 행 수.
  /// 식: round(zoneTransientPaddingMs / 1000 x sampleRate)
  int get _transientPadRows =>
      (CaptureConfig.zoneTransientPaddingMs / 1000 * sampleRate).round();

  /// 작성: 2026-10-22 19:00:00 · 박건준
  /// 함수: transientPadClippedAtEnd
  /// 목적: 운행 끝 뒤로 넓힌 가감속 구간이 기록 끝에 막혔는지 알려 준다.
  ///       막히면 `transientMaximum()` 은 있는 데까지만 쓴다. 정지 직후
  ///       측정을 끝낸 기록이다(2026-10-22 개발폰 상승, 정지 뒤 0.27초).
  /// 인자: length — 시계열 길이 (행)
  /// 반환: 넓힌 끝이 마지막 행을 넘으면 true
  bool transientPadClippedAtEnd(int length) =>
      runEndIndex + _transientPadRows > length - 1;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: toMap
  /// 목적: 결과 파일(result.json)에 담을 표로 바꾼다. 초는 사람이 읽기
  ///       쉽게 함께 남긴다. `MotionZones.fromMap` 이 되읽는다.
  /// 반환: 항목 이름을 열쇠로 하는 표
  Map<String, dynamic> toMap() => <String, dynamic>{
    'runStartIndex': runStartIndex,
    'runEndIndex': runEndIndex,
    'steadyStartIndex': steadyStartIndex,
    'steadyEndIndex': steadyEndIndex,
    'sampleRate': sampleRate,
    'steadyStartSec': steadyStartSec,
    'steadyEndSec': steadyEndSec,
  };

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 수정: 2026-10-23 11:00:00 · 박건준
  /// 함수: MotionZones.fromMap
  /// 목적: `toMap()` 이 만든 표에서 구간을 되살린다.
  /// 인자: map — 결과 파일에서 읽은 표
  /// 반환: 되살린 구간. 첨자나 표본 주기가 빠졌으면 `FormatException`
  factory MotionZones.fromMap(Map<String, dynamic> map) {
    // 열쇠 하나의 첨자를 읽는다. 정수가 아니면 사유를 올린다
    int index(String key) {
      final value = map[key]; // 첨자 값
      if (value is! int) throw FormatException('구간 첨자 $key 가 없다: $value');
      return value;
    }

    final rate = map['sampleRate']; // 표본 주기 (Hz)
    if (rate is! num) throw FormatException('구간 sampleRate 가 없다: $rate');
    return MotionZones(
      runStartIndex: index('runStartIndex'),
      runEndIndex: index('runEndIndex'),
      steadyStartIndex: index('steadyStartIndex'),
      steadyEndIndex: index('steadyEndIndex'),
      sampleRate: rate.toDouble(),
    );
  }

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: of
  /// 목적: 속도와 1.6Hz 저역 가속도로 정속 · 가감속 구간을 정한다.
  ///       1. 운행: 속도 크기가 `CaptureConfig.zoneRunSpeedMps` 를 넘는 처음
  ///          ~ 마지막
  ///       2. 운행 안 저역 가속도 크기의 최대를 구하고, 그 최대의
  ///          `CaptureConfig.zonePeakRatio` 를 처음 넘는 곳을 가속 봉우리,
  ///          마지막으로 넘는 곳을 감속 봉우리로 둔다
  ///       3. 정속 시작: 가속 봉우리 뒤 처음으로 저역 가속도 크기가
  ///          `CaptureConfig.zoneSteadyAccelMps2` 보다 작아지는 곳. 정속 끝:
  ///          감속 봉우리 앞에서 마지막으로 작은 곳
  ///       4. 정속이 `CaptureConfig.zoneMinimumSteadyMs` 보다 짧으면 실패
  ///       가속도만 보고 속도의 "최대의 99%" 같은 기준을 쓰지 않는 이유는,
  ///       속도는 적분이라 떠다님이 쌓여 정속 중에도 기울기 때문이다
  ///       (H6N1AP65 에서 정속이 25 ~ 37초로 잘못 잡혔다).
  /// 인자: speed — 속도 시계열 (m/s, 부호 상관없음)
  ///       accelSmooth — 1.6Hz 저역 가속도 (m/s², `speed` 와 같은 길이)
  ///       sampleRate — 표본 주기 (Hz)
  /// 반환: 구간, 또는 정하지 못한 사유
  static MotionZonesResult of(
    List<double> speed,
    List<double> accelSmooth,
    double sampleRate,
  ) {
    assert(speed.length == accelSmooth.length, '두 시계열 길이가 같아야 한다');
    var runStart = -1; // 운행 첫 첨자, 못 찾으면 -1
    var runEnd = -1; // 운행 끝 첨자
    for (var i = 0; i < speed.length; i++) {
      if (speed[i].abs() > CaptureConfig.zoneRunSpeedMps) {
        if (runStart < 0) runStart = i;
        runEnd = i;
      }
    }
    if (runStart < 0) {
      return const MotionZonesResult.failure(
        '속도가 ${CaptureConfig.zoneRunSpeedMps} m/s 를 넘는 운행이 없다',
      );
    }

    var peak = 0.0; // 운행 안 저역 가속도 크기의 최대 (m/s²)
    for (var i = runStart; i <= runEnd; i++) {
      if (accelSmooth[i].abs() > peak) peak = accelSmooth[i].abs();
    }
    final limit = peak * CaptureConfig.zonePeakRatio; // 봉우리로 보는 크기
    var accelPeak = -1; // 가속 봉우리 첨자
    var decelPeak = -1; // 감속 봉우리 첨자
    for (var i = runStart; i <= runEnd; i++) {
      if (accelSmooth[i].abs() > limit) {
        if (accelPeak < 0) accelPeak = i;
        decelPeak = i;
      }
    }

    var steadyStart = -1; // 정속 첫 첨자
    for (var i = accelPeak; i >= 0 && i <= decelPeak; i++) {
      if (accelSmooth[i].abs() < CaptureConfig.zoneSteadyAccelMps2) {
        steadyStart = i;
        break;
      }
    }
    var steadyEnd = -1; // 정속 끝 첨자
    for (var i = decelPeak; i >= accelPeak && i >= 0; i--) {
      if (accelSmooth[i].abs() < CaptureConfig.zoneSteadyAccelMps2) {
        steadyEnd = i;
        break;
      }
    }
    final minimumRows = (CaptureConfig.zoneMinimumSteadyMs / 1000 * sampleRate)
        .round(); // 정속 최소 행 수
    if (steadyStart < 0 ||
        steadyEnd < 0 ||
        steadyEnd - steadyStart + 1 < minimumRows) {
      return MotionZonesResult.failure(
        '가감속 봉우리 사이에 저역 가속도가 '
        '${CaptureConfig.zoneSteadyAccelMps2} m/s² 아래인 정속이 '
        '${CaptureConfig.zoneMinimumSteadyMs / 1000}초 이상 없다 '
        '(시작 첨자 $steadyStart, 끝 첨자 $steadyEnd)',
      );
    }
    return MotionZonesResult.success(
      MotionZones(
        runStartIndex: runStart,
        runEndIndex: runEnd,
        steadyStartIndex: steadyStart,
        steadyEndIndex: steadyEnd,
        sampleRate: sampleRate,
      ),
    );
  }
}

/// 작성: 2026-10-21 13:10:00 · 박건준
/// 클래스: MotionZonesResult
/// 목적: `MotionZones.of()` 의 결과. 구간을 정했으면 구간을, 못 정했으면
///       사유를 담는다.
class MotionZonesResult {
  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: MotionZonesResult.success
  /// 목적: 정한 구간을 담는다.
  /// 인자: zones — 정한 구간
  const MotionZonesResult.success(MotionZones this.zones)
    : failureReason = null;

  /// 작성: 2026-10-21 13:10:00 · 박건준
  /// 함수: MotionZonesResult.failure
  /// 목적: 구간을 정하지 못한 사유를 담는다.
  /// 인자: failureReason — 사유
  const MotionZonesResult.failure(String this.failureReason) : zones = null;

  /// 정한 구간. 못 정했으면 null
  final MotionZones? zones;

  /// 정하지 못한 사유. 정했으면 null
  final String? failureReason;
}
