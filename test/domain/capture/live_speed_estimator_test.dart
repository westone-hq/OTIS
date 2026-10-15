import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/live_speed_estimator.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

/// 작성: 2026-10-10 11:54:43 · nada
/// 변수: _rateHz
/// 목적: 합성 이벤트를 넣는 주기 (Hz).
/// 근거: 측정 — `CaptureConfig.normalIntervalMinUs` 근거의 실측 수신 주기
///       421 ~ 471Hz 에 가깝게 잡았다
const int _rateHz = 400;

/// 작성: 2026-10-10 11:54:43 · nada
/// 변수: _gravityMg
/// 목적: 합성 이벤트의 중력 성분 Z (mg). 화면을 아래로 놓은 거치를 흉내
///       낸다.
const double _gravityMg = 1000.0;

/// 작성: 2026-10-10 11:54:43 · nada
/// 변수: _mgPerMps2
/// 목적: m/s² 를 mg 로 바꾸는 배수. 합성 운행을 m/s² 로 적고 이벤트에는
///       mg 로 넣는다.
/// 근거: 표준 — 1000 / 9.80665
const double _mgPerMps2 = 1000 / 9.80665;

/// 작성: 2026-10-10 11:54:43 · nada
/// 함수: _feed
/// 목적: 수직 가속도 시계열을 gravity · raw 이벤트 쌍으로 바꿔 넣고, 넣을
///       때마다 어림 속도를 모은다. raw 는 `GridResampler.motionOf()` 의 Z
///       부호를 거꾸로 풀어 만든다 — motion_z = -(raw_z - gravity_z).
/// 인자: estimator — 시험할 추정기
///       motionMg — 표본마다의 수직 가속도 (mg). `_rateHz` 간격
/// 반환: 표본마다의 어림 속도 크기 (m/s). 기준선 전이면 null
List<double?> _feed(LiveSpeedEstimator estimator, List<double> motionMg) {
  final speeds = <double?>[]; // 표본마다 모은 속도
  for (var i = 0; i < motionMg.length; i++) {
    final tsUs = 1000000 + i * 1000000 ~/ _rateHz; // 이 표본의 시각
    estimator
      ..onEvent(
        NativeEvent(
          type: NativeEventType.gravity,
          tsUs: tsUs,
          xMg: 0.0,
          yMg: 0.0,
          zMg: _gravityMg,
          dtUs: 0,
        ),
      )
      ..onEvent(
        NativeEvent(
          type: NativeEventType.accel,
          tsUs: tsUs,
          xMg: 1.0,
          yMg: 1.0,
          zMg: _gravityMg - motionMg[i],
          dtUs: 0,
        ),
      );
    speeds.add(estimator.speedMps);
  }
  return speeds;
}

/// 작성: 2026-10-10 11:54:43 · nada
/// 함수: _trapezoidRide
/// 목적: 사다리꼴 운행의 수직 가속도를 만든다. 정지 2초 → 가속 1초 →
///       정속 4초 → 감속 1초 → 정지 3초. 가속도 1.0 m/s² 를 1초 걸어
///       정속 1.0 m/s 가 된다.
/// 반환: 표본마다의 수직 가속도 (mg)
List<double> _trapezoidRide() {
  double accelAt(double t) {
    if (t >= 2 && t < 3) return 1.0;
    if (t >= 7 && t < 8) return -1.0;
    return 0.0;
  }

  return List<double>.generate(
    11 * _rateHz,
    (i) => accelAt(i / _rateHz) * _mgPerMps2,
  );
}

/// 작성: 2026-10-10 11:54:43 · nada
/// 함수: main
/// 목적: 측정 중 속도 어림을 시험한다. 기준선 전에는 값이 없는지,
///       사다리꼴 운행의 정속 속도를 맞히는지, 정지 중 작은 치우침이
///       쌓이지 않는지, 쓰지 못하는 이벤트를 건너뛰는지 본다.
void main() {
  group('LiveSpeedEstimator', () {
    test('기준선 1초가 지나기 전에는 속도가 없다', () {
      final speeds = _feed(
        LiveSpeedEstimator(),
        List<double>.filled(_rateHz, 0.0),
      ); // 정지 1초

      expect(speeds, everyElement(isNull));
    });

    test('기준선 1초가 지나면 정지 상태 속도는 0 이다', () {
      final speeds = _feed(
        LiveSpeedEstimator(),
        List<double>.filled(2 * _rateHz, 0.0),
      ); // 정지 2초

      expect(speeds.last, 0.0);
    });

    test('사다리꼴 운행의 정속 구간 속도를 0.05 m/s 안으로 맞힌다', () {
      final speeds = _feed(LiveSpeedEstimator(), _trapezoidRide());

      for (final second in <double>[4.0, 5.0, 6.0, 6.9]) {
        expect(
          speeds[(second * _rateHz).round()],
          closeTo(1.0, 0.05),
          reason: '$second 초',
        );
      }
    });

    test('운행이 끝나면 속도가 0 으로 돌아온다', () {
      final speeds = _feed(LiveSpeedEstimator(), _trapezoidRide());

      expect(speeds.last, 0.0);
    });

    test('기준선 뒤에 생긴 작은 치우침이 쌓이지 않는다', () {
      // 1.5 mg 치우침을 30초 적분하면 0.44 m/s 가 된다
      final motion = <double>[
        ...List<double>.filled(_rateHz, 0.0), // 기준선 1초
        ...List<double>.filled(30 * _rateHz, 1.5), // 치우친 정지 30초
      ];
      final speeds = _feed(LiveSpeedEstimator(), motion);
      final settled = speeds.whereType<double>(); // 기준선 뒤 값

      expect(settled.reduce((a, b) => a > b ? a : b), lessThan(0.02));
    });

    test('기준선은 첫 1초 평균을 뺀다', () {
      // 기기마다 정지 상태에도 몇 mg 떠 있다. 그대로 두면 정지가 운행처럼
      // 적분된다
      final speeds = _feed(
        LiveSpeedEstimator(),
        List<double>.filled(5 * _rateHz, -4.0),
      ); // 내내 -4 mg 에 떠 있는 정지 5초

      expect(speeds.last, 0.0);
    });

    test('gravity 를 받기 전 raw 와 linear 는 쓰지 않는다', () {
      final estimator = LiveSpeedEstimator(); // 시험할 추정기
      for (var i = 0; i < 2 * _rateHz; i++) {
        final tsUs = 1000000 + i * 1000000 ~/ _rateHz; // 이 표본의 시각
        estimator
          ..onEvent(
            NativeEvent(
              type: NativeEventType.accel,
              tsUs: tsUs,
              xMg: 1.0,
              yMg: 1.0,
              zMg: 500.0,
              dtUs: 0,
            ),
          )
          ..onEvent(
            NativeEvent(
              type: NativeEventType.linear,
              tsUs: tsUs,
              xMg: 1.0,
              yMg: 1.0,
              zMg: 500.0,
              dtUs: 0,
            ),
          );
      }

      expect(estimator.speedMps, isNull);
    });

    test('방향이 있는 속도는 운행 중 부호를 갖고 크기와 같다', () {
      final estimator = LiveSpeedEstimator(); // 시험할 추정기
      final ride = _trapezoidRide(); // 사다리꼴 운행
      _feed(estimator, ride.sublist(0, 5 * _rateHz)); // 정속 중간까지

      expect(estimator.velocityMps, greaterThan(0.9));
      expect(estimator.speedMps, estimator.velocityMps);
    });
  });
}
