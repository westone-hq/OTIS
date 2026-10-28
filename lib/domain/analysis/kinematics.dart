import 'dart:math' as math;

import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/dsp/butterworth.dart';
import 'package:vibration_checker/domain/dsp/units.dart';

/// 작성: 2026-10-20 14:05:12 · 박건준
/// 클래스: MotionWindow
/// 목적: 운행 거리 · 최대 속도를 적분한 "움직인 구간". 진동 · 소음 지표를
///       내는 운행 구간(`TravelWindow`, 출발 · 정지 0.5 m 제외)과 다르다 —
///       이 구간은 출발 직전부터 정지 직후까지다. 첨자는 100Hz 격자 기준이다.
class MotionWindow {
  /// 작성: 2026-10-20 14:05:12 · 박건준
  /// 함수: MotionWindow
  /// 목적: 구간 끝 첨자와 잘림 여부를 그대로 담는다.
  /// 인자: startIndex, endIndex — 구간 첫 · 끝 첨자 (끝 포함)
  ///       clippedAtStart — 앞 여유가 기록 앞을 넘어 잘렸는지. 측정 시작
  ///       때 이미 움직이고 있었을 수 있다
  ///       clippedAtEnd — 뒤 여유가 기록 끝을 넘어 잘렸는지. 승강기가 서기
  ///       전에 측정을 끝냈을 수 있다
  ///       sampleRate — 첨자를 초로 바꿀 표본 주기 (Hz)
  const MotionWindow({
    required this.startIndex,
    required this.endIndex,
    required this.clippedAtStart,
    required this.clippedAtEnd,
    required this.sampleRate,
  });

  /// 구간 첫 첨자
  final int startIndex;

  /// 구간 끝 첨자 (포함)
  final int endIndex;

  /// 앞 여유가 기록 앞에서 잘렸는지
  final bool clippedAtStart;

  /// 뒤 여유가 기록 끝에서 잘렸는지
  final bool clippedAtEnd;

  /// 첨자를 초로 바꿀 표본 주기 (Hz)
  final double sampleRate;

  /// 작성: 2026-10-20 14:05:12 · 박건준
  /// 함수: startSec
  /// 목적: 구간 시작 시각 (초, 격자 첫 행 기준).
  double get startSec => startIndex / sampleRate;

  /// 작성: 2026-10-20 14:05:12 · 박건준
  /// 함수: endSec
  /// 목적: 구간 끝 시각 (초, 격자 첫 행 기준).
  double get endSec => endIndex / sampleRate;
}

/// 작성: 2026-09-15 14:32:07 · 박건준
/// 수정: 2026-10-22 22:40:00 · 박건준
/// 클래스: Kinematics
/// 목적: 수직 진동에서 뽑아낸 파생 물리량과 거기서 나온 두 지표를 한
///       묶음으로 담는다. `derive()` 가 만들어 돌려준다.
class Kinematics {
  /// 가속도 시계열 (m/s²). 움직인 구간 평균(치우침)을 뺀 값
  final List<double> accel;

  /// `accel` 에 저크 저역(`CaptureConfig.jerkLowpassHz`)을 양방향으로 건
  /// 가속도 (m/s²). 저크와 정속 구간 판정이 함께 쓴다
  final List<double> accelSmooth;

  /// `accel` 에 차트 저역(`CaptureConfig.accelChartLowpassHz`)을 양방향으로
  /// 건 가속도 (m/s²). 리포트 3쪽 가속도 차트에만 쓴다
  final List<double> accelChart;

  /// 속도 시계열 (m/s). 움직인 구간 안만 적분한 값이고 밖은 0
  final List<double> speed;

  /// 누적 이동량 시계열 (m). 방향과 무관하게 움직인 거리. 운행 거리 ·
  /// 운행 구간이 쓴다
  final List<double> travelled;

  /// 하부층 정지레벨 기준 위치 시계열 (m). 상승은 0 에서 오르고 하강은
  /// 운행 거리에서 0 으로 내려온다. 리포트 3쪽 위치 차트와 수직 최대 위치가
  /// 쓴다
  final List<double> position;

  /// 저크 시계열 (m/s³)
  final List<double> jerk;

  /// 최대 속도 (m/s). 속도 절댓값의 최대
  final double maxSpeed;

  /// 운행 거리 (m). 누적 이동량의 마지막 값 (움직인 구간 안 이동량의 합)
  final double distance;

  /// 움직인 구간. 정지 측정이면 null
  final MotionWindow? motion;

  /// 작성: 2026-09-15 14:32:07 · 박건준
  /// 수정: 2026-10-22 22:40:00 · 박건준
  /// 함수: Kinematics
  /// 목적: 파생 물리량과 두 지표를 그대로 담는 생성자.
  /// 인자: accel — 가속도 시계열 (m/s²)
  ///       accelSmooth — 저크 저역을 건 가속도 (m/s²)
  ///       accelChart — 차트 저역을 건 가속도 (m/s²)
  ///       speed — 속도 시계열 (m/s)
  ///       travelled — 누적 이동량 시계열 (m)
  ///       position — 하부층 기준 위치 시계열 (m)
  ///       jerk — 저크 시계열 (m/s³)
  ///       maxSpeed — 최대 속도 (m/s)
  ///       distance — 운행 거리 (m)
  ///       motion — 움직인 구간. 정지 측정이면 null
  const Kinematics({
    required this.accel,
    required this.accelSmooth,
    required this.accelChart,
    required this.speed,
    required this.travelled,
    required this.position,
    required this.jerk,
    required this.maxSpeed,
    required this.distance,
    required this.motion,
  });

  /// 작성: 2026-09-15 19:14:22 · 박건준
  /// 수정: 2026-10-22 22:40:00 · 박건준
  /// 변수: minimumRows
  /// 목적: 변환에 필요한 최소 격자 행 수. 이보다 적으면 변환하지 않고
  ///       사유를 올린다.
  ///       저크 전에 거는 양방향 저역 필터(`CaptureConfig.jerkLowpassOrder`
  ///       차)는 양 끝을 덧대 늘려 거르므로(`Butterworth.filtfilt()`) 입력이
  ///       덧댐 길이보다 길어야 한다. 그보다 짧은 격자로 저크 · 가속도를
  ///       0 이나 거르지 않은 값으로 채우면 재서 나온 값과 구분할 수 없어,
  ///       변환하지 않고 사유를 올린다. 실제 측정은 신호 처리가 2초 미만을
  ///       먼저 돌려보내 늘 이보다 길다.
  /// 식: 덧댐 = 3 x (2 x 구간 수 + 1),  구간 수 = 차수 / 2
  ///     최소 행 = 덧댐 + 1 = 3 x (차수 + 1) + 1   (4차 → 16)
  /// 근거: 표준 — SciPy `sosfiltfilt()` 의 `padlen` 기본값
  ///       (`Butterworth.padLength()`)
  static const int minimumRows = 3 * (CaptureConfig.jerkLowpassOrder + 1) + 1;

  /// 작성: 2026-10-20 14:05:12 · 박건준
  /// 함수: kinematicsMethodLabel
  /// 목적: 운행 거리 · 최대 속도를 낸 방식을 결과 파일(result.json
  ///       `signalConditioning`)에 남길 문자열. 신호 처리 · 가중 표시 뒤에
  ///       이어 붙인다. 이 표시가 없는 2026-10-20 전 결과는 기록 전체를
  ///       적분한 예전 방식이다(정지 구간이 거리에 섞임).
  ///       - `motion(v>문턱,pad여유ms)` — 대략 속도가 문턱(m/s)을 넘는 구간에
  ///         앞뒤 여유를 더한 구간만 적분했다
  static String get kinematicsMethodLabel =>
      'motion(v>${CaptureConfig.motionSpeedThresholdMps},'
      'pad${CaptureConfig.motionPaddingMs}ms)';

  /// 작성: 2026-10-21 10:05:00 · 박건준
  /// 함수: jerkMethodLabel
  /// 목적: 저크를 낸 방식을 결과 파일(result.json `signalConditioning`)에
  ///       남길 문자열. 이 표시가 없는 2026-10-21 전 결과의 저크는 40Hz
  ///       저역 가속도를 그대로 미분한 값이라 수십 배 크다(±10 ~ 20 m/s³).
  ///       - `jerk(lp차단bw차수zp)` — 가속도에 버터워스 저역을 양방향(영위상)
  ///         으로 건 뒤 중앙 차분했다
  static String get jerkMethodLabel =>
      'jerk(lp${CaptureConfig.jerkLowpassHz}'
      'bw${CaptureConfig.jerkLowpassOrder}zp)';

  /// 작성: 2026-10-21 11:20:00 · 박건준
  /// 함수: accelChartMethodLabel
  /// 목적: 차트용 가속도(`accelSeries`)를 만든 방식을 결과 파일
  ///       (`signalConditioning`)에 남길 문자열. 이 표시가 없는 2026-10-21 전
  ///       결과의 `accelSeries` 는 거르지 않은 가속도다.
  ///       - `acc(lp차단bw차수zp)` — 버터워스 저역을 양방향으로 걸었다
  static String get accelChartMethodLabel =>
      'acc(lp${CaptureConfig.accelChartLowpassHz}'
      'bw${CaptureConfig.accelChartLowpassOrder}zp)';

  /// 작성: 2026-09-15 14:32:07 · 박건준
  /// 수정: 2026-10-28 10:30:00 · 박건준
  /// 함수: derive
  /// 목적: 수직 진동 시계열에서 가속도 · 속도 · 누적 이동량 · 저크와
  ///       최대 속도 · 운행 거리를 만든다. 순서대로 한다.
  ///       1. 진동값(mg)을 가속도(m/s²)로 바꾼다
  ///       2. 움직인 구간을 찾는다(`_findMotion()`). 전체를 한 번 적분한
  ///          대략 속도가 `CaptureConfig.motionSpeedThresholdMps` 를 넘는
  ///          처음부터 끝까지에 앞뒤 `CaptureConfig.motionPaddingMs` 를
  ///          더한 구간이다
  ///       3. 그 구간 가속도 평균을 치우침으로 보고 전체에서 뺀다
  ///       4. 구간 안만 적분해 속도를 만든다. 구간 밖 속도는 0 이다.
  ///          3단계로 구간 끝 속도가 정확히 0 이 된다
  ///       5. 속도의 절댓값을 더해 나가 누적 이동량(`travelled`)을 만든다.
  ///          구간 밖에서는 변하지 않는다. 운행 거리와 운행 구간
  ///          (`TravelWindow`)이 이것을 쓴다. 속도를 부호 그대로 더한 변위에서
  ///          그 최솟값을 빼 하부층 정지레벨 기준 위치(`position`)도 만든다 —
  ///          상승은 0 → 운행 거리, 하강은 운행 거리 → 0 이다(2026-10-21,
  ///          OTIS 리포트 3쪽 위치 차트와 같다)
  ///       6. 가속도에 `CaptureConfig.jerkLowpassHz` 저역을 양방향으로 걸고
  ///          (`accelSmooth`), 그 변화율로 저크를 만든다. 같은 저역
  ///          가속도를 정속 구간 판정에도 쓴다
  ///       7. 차트에 그릴 가속도(`accelChart`)는 `CaptureConfig.accelChartLowpassHz`
  ///          저역을 양방향으로 건 값이다. 표시용이라 1 ~ 5 단계(속도 ·
  ///          거리)에는 쓰지 않는다
  ///       움직인 구간이 없으면(정지 측정) 속도 · 이동량은 모두 0 이고,
  ///       치우침은 전체 평균으로 뺀다. 0 은 재지 않은 값이 아니라 "움직이지
  ///       않았다" 는 측정값이다.
  ///
  ///       왜 움직인 구간만 적분하는가
  ///         - 가속도를 적분하면 가만히 있어도 속도가 조금씩 떠다닌다
  ///           (1분에 ±0.02 m/s). 예전처럼 기록 전체를 적분하면 정지
  ///           구간의 떠다님이 거리에 섞여, 1분 정지 기록이 0.68 m 를
  ///           움직인 것으로 나왔고 같은 운행도 도착 뒤 기다린 시간(1 ~ 6초)
  ///           에 따라 거리가 0.57 m 까지 달라졌다
  ///         - 구간 양 끝은 서 있는 순간이라 속도가 0 이어야 한다. 구간
  ///           평균을 빼면 그 조건이 맞는다
  ///
  ///       누적 이동량은 속도의 절댓값을 더한다. 방향을 그대로 더하면
  ///       위로 갔다 내려온 측정에서 0 에 가까운 값이 나와, 실제로 얼마나
  ///       움직였는지를 알 수 없게 된다.
  /// 인자: zSeries — 수직 진동 시계열 (mg). `minimumRows` 개 이상이어야
  ///       한다. 부르기 전에
  ///       `MeasurementAssembler.assemble()`이 확인한다
  ///       sampleRate — 실측 샘플레이트 (Hz). 0 보다 커야 한다
  /// 반환: 파생 물리량과 최대 속도 · 운행 거리, 움직인 구간을 담은 묶음
  /// 식: accel(i) = zSeries(i) x 9.80665e-3 - 구간 평균
  ///     speed(i) = (누적합 accel(s..i)) x dt   (s ≤ i ≤ e, 밖은 0)
  ///     travelled(i) = (누적합 |speed(0..i)|) x dt
  ///     position(i) = d(i) - min(d),  d(i) = (누적합 speed(0..i)) x dt
  ///     smooth = filtfilt(버터워스 저역 1.6Hz 4차, accel)
  ///     jerk(i) = (smooth(i+1) - smooth(i-1)) / (2 x dt)
  /// 근거: 측정 — 2026-10-20 같은 승강기 같은 구간 기록 6건(오티스폰 ·
  ///       테스트폰, 원본은 분석 뒤 삭제)에서 기록 사이 거리 표준편차가
  ///       0.204 → 0.067 m, 동시 측정 두 폰 차이가 0.30 · 0.38 → 0.16 ·
  ///       0.17 m 로 줄었다. 1분 정지 기록은 0.68 → 0 m.
  ///       미확인: 실제 거리. 같은 기록에서 예전 방식보다 0.4 ~ 0.5 m
  ///       작고, 원본 리포트 기록(ride_reference)은 57.3 m(원본) 대비 예전
  ///       57.09 · 지금 56.84 m 다. 오티스 앱도 정지 구간까지 적분하는
  ///       것으로 보이나 확인하지 못했다. 층고 도면을 아는 운행으로 확인한다
  ///       저크 저역의 근거는 `CaptureConfig.jerkLowpassHz` 를 본다
  static Kinematics derive(List<double> zSeries, double sampleRate) {
    final n = zSeries.length; // 격자 행 수
    // 부르는 쪽의 `minimumRows` 가드가 이 조건을 보장한다. 방어 분기로
    // 받아내지 않고 `assert` 로 두는 이유는, 분기로 두면 가드를 거치지
    // 않고 부르는 코드가 생겼을 때 speed[0] = 0.0 같은 대체값이 잘못을
    // 덮어 터져야 할 자리에서 안 터지기 때문이다. 게다가 도달할 수 없는
    // 분기는 시험할 수 없어 그대로 썩는다. `assert` 는 계약을 코드에
    // 남기고 디버그 실행에서 곧바로 실패하며 릴리스 빌드에서는 지워져
    // 비용이 없다
    assert(n >= minimumRows, '격자 행이 $minimumRows개보다 적다: $n행');
    final dt = 1.0 / sampleRate; // 행 사이 시간 간격 (초)

    final accel = List<double>.generate(
      n,
      (i) => zSeries[i] * Units.mgToMetersPerSecondSquared,
    ); // 가속도 시계열 (m/s²). 아래에서 치우침을 뺀다

    // → 로직 이동: _findMotion()
    final motion = _findMotion(accel, sampleRate); // 움직인 구간, 없으면 null
    final from = motion?.startIndex ?? 0; // 치우침을 셀 구간 첫 첨자
    final to = motion?.endIndex ?? n - 1; // 치우침을 셀 구간 끝 첨자 (포함)
    var biasSum = 0.0; // 구간 가속도 합
    for (var i = from; i <= to; i++) {
      biasSum += accel[i];
    }
    final bias = biasSum / (to - from + 1); // 치우침 (m/s²)
    for (var i = 0; i < n; i++) {
      accel[i] -= bias;
    }

    final speed = List<double>.filled(n, 0.0); // 속도 시계열 (m/s)
    if (motion != null) {
      var running = 0.0; // 구간 첫 행부터 더한 가속도 누적합
      for (var i = motion.startIndex; i <= motion.endIndex; i++) {
        running += accel[i];
        speed[i] = running * dt;
      }
    }

    final travelled = List<double>.filled(n, 0.0); // 누적 이동량 시계열 (m)
    final displacement = List<double>.filled(n, 0.0); // 출발점 기준 변위 (m)
    var sumMagnitude = 0.0; // 여기까지 더한 속도 절댓값 누적합
    var sumSigned = 0.0; // 여기까지 더한 속도 누적합 (부호 그대로)
    var lowest = 0.0; // 변위의 최솟값 (m). 하부층 정지레벨이다
    var maxSpeed = 0.0; // 속도 절댓값의 최대 (m/s)
    for (var i = 0; i < n; i++) {
      final magnitude = speed[i].abs(); // 방향을 뺀 속도 크기
      sumMagnitude += magnitude;
      sumSigned += speed[i];
      travelled[i] = sumMagnitude * dt;
      displacement[i] = sumSigned * dt;
      if (displacement[i] < lowest) lowest = displacement[i];
      if (magnitude > maxSpeed) maxSpeed = magnitude;
    }
    final position = <double>[
      for (final d in displacement) d - lowest,
    ]; // 하부층 정지레벨 기준 위치 (m)

    // → 로직 이동: Butterworth.filtfilt()
    final accelSmooth = Butterworth.filtfilt(
      // → 로직 이동: Butterworth.lowpass()
      Butterworth.lowpass(
        order: CaptureConfig.jerkLowpassOrder,
        cutoffHz: CaptureConfig.jerkLowpassHz,
        sampleRateHz: sampleRate,
      ),
      accel,
    ); // 저크 저역을 건 가속도 (m/s²)
    // → 로직 이동: Butterworth.filtfilt()
    final accelChart = Butterworth.filtfilt(
      // → 로직 이동: Butterworth.lowpass()
      Butterworth.lowpass(
        order: CaptureConfig.accelChartLowpassOrder,
        cutoffHz: CaptureConfig.accelChartLowpassHz,
        sampleRateHz: sampleRate,
      ),
      accel,
    ); // 차트에 그릴 가속도 (m/s²)
    final jerk = List<double>.filled(n, 0.0); // 저크 시계열 (m/s³)
    jerk[0] = (accelSmooth[1] - accelSmooth[0]) / dt;
    jerk[n - 1] = (accelSmooth[n - 1] - accelSmooth[n - 2]) / dt;
    for (var i = 1; i < n - 1; i++) {
      jerk[i] = (accelSmooth[i + 1] - accelSmooth[i - 1]) / (2 * dt);
    }

    return Kinematics(
      accel: accel,
      accelSmooth: accelSmooth,
      accelChart: accelChart,
      speed: speed,
      travelled: travelled,
      position: position,
      jerk: jerk,
      maxSpeed: maxSpeed,
      distance: travelled[n - 1],
      motion: motion,
    );
  }

  /// 작성: 2026-10-20 14:05:12 · 박건준
  /// 함수: _findMotion
  /// 목적: 승강기가 움직인 구간을 찾는다. 예전 방식대로 전체를 한 번
  ///       적분해 대략 속도를 만들고(전체 평균 빼기 + 양 끝 직선 빼기),
  ///       그 크기가 `CaptureConfig.motionSpeedThresholdMps` 를 넘는 처음 ·
  ///       마지막 행에 앞뒤 `CaptureConfig.motionPaddingMs` 를 더한다. 더한
  ///       자리가 기록 밖이면 기록 끝에서 자르고 그 사실을 남긴다 — 그때는
  ///       구간 끝에서 승강기가 서 있었다고 볼 수 없어 거리가 작게 나올 수
  ///       있다.
  /// 인자: accel — 가속도 시계열 (m/s², 치우침을 빼기 전)
  ///       sampleRate — 실측 샘플레이트 (Hz)
  /// 반환: 움직인 구간. 문턱을 넘는 행이 없으면(정지 측정) null
  /// 식: v0(i) = (누적합 (accel - 평균)(0..i)) x dt - 두 끝을 잇는 직선
  ///     s = 처음 |v0| > 문턱 - 여유,  e = 마지막 |v0| > 문턱 + 여유
  static MotionWindow? _findMotion(List<double> accel, double sampleRate) {
    final n = accel.length; // 격자 행 수
    final dt = 1.0 / sampleRate; // 행 사이 시간 간격 (초)
    var sum = 0.0; // 평균을 구하려고 모으는 가속도 합
    for (final value in accel) {
      sum += value;
    }
    final mean = sum / n; // 가속도 전체 평균 (m/s²)
    final rough = List<double>.filled(n, 0.0); // 대략 속도 (m/s)
    var running = 0.0; // 여기까지 더한 가속도 누적합
    for (var i = 0; i < n; i++) {
      running += accel[i] - mean;
      rough[i] = running * dt;
    }
    final first = rough[0]; // 보정 전 첫 속도
    final last = rough[n - 1]; // 보정 전 마지막 속도
    var start = -1; // 문턱을 처음 넘은 행, 없으면 -1
    var end = -1; // 문턱을 마지막으로 넘은 행, 없으면 -1
    for (var i = 0; i < n; i++) {
      final v = rough[i] - (first + (last - first) * i / (n - 1)); // 보정 속도
      if (v.abs() > CaptureConfig.motionSpeedThresholdMps) {
        if (start < 0) start = i;
        end = i;
      }
    }
    if (start < 0) return null;
    final pad = (CaptureConfig.motionPaddingMs / 1000 * sampleRate)
        .round(); // 앞뒤로 더할 행 수
    return MotionWindow(
      startIndex: math.max(0, start - pad),
      endIndex: math.min(n - 1, end + pad),
      clippedAtStart: start - pad < 0,
      clippedAtEnd: end + pad > n - 1,
      sampleRate: sampleRate,
    );
  }
}
