import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';
import 'package:vibration_checker/domain/dsp/units.dart';

/// 작성: 2026-10-10 11:54:43 · 박건준
/// 수정: 2026-10-22 22:40:00 · 박건준
/// 클래스: LiveSpeedEstimator
/// 목적: 측정 중에 들어오는 센서 이벤트로 승강기 속도를 그때그때 어림한다.
///       측정 화면에 보여 주기만 하고 저장 · 리포트에는 쓰지 않는다.
///
///       저장하는 속도(`Kinematics.derive()`)는 측정이
///       끝난 뒤 전체 평균과 두 끝을 잇는 직선을 빼 적분 오차를 없앤다.
///       끝을 모르는 측정 중에는 그렇게 할 수 없어, 아래처럼 따로 어림한다.
///       그래서 두 값은 다를 수 있다.
///       1. 수직 가속도 — raw 와 바로 앞 gravity 로 `GridResampler.motionOf()`
///          를 불러 Z 를 쓴다. 격자와 같은 부호다
///       2. 기준선 — 첫 `CaptureConfig.baselineWindowMs` 동안의 평균을
///          모아 이후 값에서 뺀다. 그동안 속도는 null 이다
///       3. 거르기 — 1차 저역(`CaptureConfig.liveSmoothingMs`)을 건 뒤
///          적분한다
///       4. 정지 되돌림 — 거른 가속도가 작고(`liveStillAccelMg`) 속도도
///          작은(`liveStillSpeedMps`) 상태가 `liveStillHoldMs` 이어지면
///          속도를 0 으로 되돌린다. 정지 중 작은 치우침이 쌓이는 것을
///          막는다
///       이벤트는 일정한 간격으로 오지 않으므로 시간 간격은 이벤트 시각
///       차이로 잰다.
class LiveSpeedEstimator {
  /// 기준선 구간 길이를 꺼낼 수집 설정
  final CaptureConfig config;

  /// 바로 앞 gravity 이벤트. raw 마다 이 값을 빼 중력을 없앤다. 아직
  /// gravity 를 받기 전이면 null
  NativeEvent? _gravity;

  /// 쓴 raw 이벤트 중 첫 것의 시각 (마이크로초). 기준선 구간을 이
  /// 시각부터 잰다. 아직 없으면 null
  int? _startUs;

  /// 쓴 raw 이벤트 중 마지막 것의 시각 (마이크로초). 다음 이벤트와의
  /// 시간 간격을 재고, 시각이 뒤로 간 이벤트를 걸러 낸다. 아직 없으면 null
  int? _lastUs;

  /// 기준선 구간 동안 모은 수직 가속도 합 (mg)
  double _baselineSum = 0.0;

  /// 기준선 구간 동안 모은 이벤트 수
  int _baselineCount = 0;

  /// 기준선 (mg). 기준선 구간이 끝나고 첫 이벤트에서 정해진다. 그 전이면
  /// null
  double? _baselineMg;

  /// 기준선을 빼고 1차 저역을 건 수직 가속도 (mg)
  double _smoothedMg = 0.0;

  /// 어림한 수직 속도 (m/s). 부호는 격자 Z 와 같다
  double _velocity = 0.0;

  /// 정지 판정 조건이 이어진 시간 (마이크로초). 조건이 깨지면 0
  int _stillUs = 0;

  /// 작성: 2026-10-10 11:54:43 · 박건준
  /// 함수: LiveSpeedEstimator
  /// 목적: 기준선 구간 길이를 꺼낼 수집 설정을 받는다.
  /// 인자: config — 수집 설정. 안 주면 기본값
  LiveSpeedEstimator({this.config = const CaptureConfig()});

  /// 작성: 2026-10-10 11:54:43 · 박건준
  /// 함수: velocityMps
  /// 목적: 어림한 수직 속도 (m/s). 부호는 격자 Z 와 같다. 기준선이 정해지기
  ///       전이면 null.
  double? get velocityMps => _baselineMg == null ? null : _velocity;

  /// 작성: 2026-10-10 11:54:43 · 박건준
  /// 함수: speedMps
  /// 목적: 어림한 속도의 크기 (m/s). 화면에 보이는 값이다. 기준선이
  ///       정해지기 전이면 null.
  double? get speedMps => velocityMps?.abs();

  /// 작성: 2026-10-10 11:54:43 · 박건준
  /// 수정: 2026-10-22 23:55:00 · 박건준
  /// 함수: onEvent
  /// 목적: 센서 이벤트 한 건을 받아 속도 어림을 한 걸음 진행한다. 쓰지
  ///       못하는 이벤트는 조용히 건너뛴다 — 저장용 격자
  ///       (`GridResampler.onEvent()`)가 같은 이벤트를 따로 집계한다.
  ///       - `linear` 는 격자처럼 쓰지 않는다
  ///       - `gravity` 는 다음 raw 에서 뺄 값으로 담아 둔다. 세 축이 모두 0
  ///         이면 버린다(센서 버퍼가 차기 전 값, 격자와 같은 기준)
  ///       - `accel`(raw) 은 gravity 를 받은 뒤부터 쓴다. 세 축이 모두 0
  ///         이거나 시각이 앞 이벤트보다 늦지 않으면 버린다 — 격자가 버리는
  ///         것과 같은 기준이다
  /// 인자: event — 안드로이드에서 도착한 원본 이벤트
  /// 식: a = motionOf(raw, gravity).z - 기준선                 (mg)
  ///     s = s + dt / (τ + dt) x (a - s),  τ = liveSmoothingMs
  ///     v = v + s x 9.80665e-3 x dt                         (m/s)
  ///     |s| < liveStillAccelMg 이고 |v| < liveStillSpeedMps 가
  ///     liveStillHoldMs 이어지면 v = 0
  void onEvent(NativeEvent event) {
    switch (event.type) {
      case NativeEventType.linear:
        return;
      case NativeEventType.gravity:
        // 세 축 0 인 gravity 는 센서 버퍼가 차기 전 값이라 버린다
        // (`GridResampler._accept()` 와 같은 규칙). 크기 0 인 중력에는
        // 수직을 투영할 수 없다(`GridResampler.motionOf()`)
        if (event.xMg == 0.0 && event.yMg == 0.0 && event.zMg == 0.0) return;
        _gravity = event;
        return;
      case NativeEventType.accel:
        break;
    }

    final gravity = _gravity; // 이 raw 에서 뺄 중력, 아직 없으면 null
    if (gravity == null) return;
    if (event.xMg == 0.0 && event.yMg == 0.0 && event.zMg == 0.0) return;
    final lastUs = _lastUs; // 앞 이벤트 시각, 첫 이벤트면 null
    if (lastUs != null && event.tsUs <= lastUs) return;

    // → 로직 이동: GridResampler.motionOf()
    final motion = GridResampler.motionOf(
      rawX: event.xMg,
      rawY: event.yMg,
      rawZ: event.zMg,
      gravityX: gravity.xMg,
      gravityY: gravity.yMg,
      gravityZ: gravity.zMg,
    ); // 중력을 뺀 세 축 가속도 (mg)
    _lastUs = event.tsUs;
    final startUs = _startUs ??= event.tsUs; // 기준선 구간 시작 시각

    var baseline = _baselineMg; // 정해진 기준선, 아직이면 null
    if (baseline == null) {
      if (event.tsUs - startUs < config.baselineWindowMs * 1000) {
        _baselineSum += motion.z;
        _baselineCount++;
        return;
      }
      // 첫 이벤트는 경과 0 이라 반드시 위 갈래에서 모이므로 이 자리에서
      // 개수가 0 일 수 없다. 나눗셈 전에 확인만 해 둔다
      assert(_baselineCount > 0, '기준선 구간에 모인 이벤트가 없다');
      baseline = _baselineMg = _baselineSum / _baselineCount;
    }

    final dtUs = event.tsUs - lastUs!; // 앞 이벤트와의 간격 (마이크로초)
    final dtSec = dtUs / 1e6; // 같은 간격 (초)
    const tauSec = CaptureConfig.liveSmoothingMs / 1000; // 저역 시간 상수 (초)
    final accelMg = motion.z - baseline; // 기준선을 뺀 수직 가속도 (mg)
    _smoothedMg += dtSec / (tauSec + dtSec) * (accelMg - _smoothedMg);
    _velocity += _smoothedMg * Units.mgToMetersPerSecondSquared * dtSec;

    final still =
        _smoothedMg.abs() < CaptureConfig.liveStillAccelMg &&
        _velocity.abs() < CaptureConfig.liveStillSpeedMps; // 정지 조건인지
    _stillUs = still ? _stillUs + dtUs : 0;
    if (_stillUs >= CaptureConfig.liveStillHoldMs * 1000) _velocity = 0.0;
  }
}
