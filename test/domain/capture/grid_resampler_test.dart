import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/grid_resampler.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

/// 작성: 2026-10-05 10:03:35 · nada
/// 변수: _stepUs
/// 목적: 시험 이벤트 사이 간격 (마이크로초). 256Hz 한 칸에 가깝다.
const int _stepUs = 3906;

/// 작성: 2026-10-05 10:03:35 · nada
/// 변수: _gravityLagUs
/// 목적: 중력 이벤트를 가속도 이벤트보다 늦게 둔 거리 (마이크로초). 두
///       센서가 같은 시각에 오지 않는 실제 모습을 흉내 낸다.
const int _gravityLagUs = 100;

/// 작성: 2026-10-05 10:03:35 · nada
/// 함수: _resampler
/// 목적: 가속도 (1, 2, 1003) · 중력 (0, 0, 1000) 을 일정 간격으로 넣은
///       환산기를 만든다. 진동은 (1, 2, 3) mg 이 된다.
/// 인자: count — 센서마다 넣을 이벤트 수
/// 반환: 이벤트가 쌓인 환산기
GridResampler _resampler(int count) {
  final resampler = GridResampler(config: const CaptureConfig()); // 채울 환산기
  for (var i = 0; i < count; i++) {
    final tsUs = 1000000 + i * _stepUs; // 이 가속도 이벤트의 시각 (마이크로초)
    resampler.onEvent(
      NativeEvent(
        type: NativeEventType.accel,
        tsUs: tsUs,
        xMg: 1.0,
        yMg: 2.0,
        zMg: 1003.0,
        dtUs: _stepUs,
      ),
    );
    resampler.onEvent(
      NativeEvent(
        type: NativeEventType.gravity,
        tsUs: tsUs + _gravityLagUs,
        xMg: 0.0,
        yMg: 0.0,
        zMg: 1000.0,
        dtUs: _stepUs,
      ),
    );
  }
  return resampler;
}

/// 작성: 2026-10-05 10:03:35 · nada
/// 함수: main
/// 목적: 격자 환산이 시작 · 종료 입력 충격을 빼려고 앞뒤 0.5초씩 버리는지,
///       너무 짧은 측정은 사유와 함께 실패하는지, 뒤집어 놓은 거치에 맞춰
///       Y · Z 부호만 뒤집는지 시험한다.
void main() {
  test('두 센서가 겹친 구간의 앞뒤 0.5초씩을 버린다', () {
    final result = _resampler(1024).resample(); // 4초 남짓 측정의 환산 결과
    const config = CaptureConfig(); // 기본 설정
    final perSide = config.edgeTrimNs ~/ config.idealIntervalNs; // 한쪽 행 수

    expect(result.isSuccess, isTrue, reason: '${result.failureReason}');
    expect(result.edgeTrimmedRows, closeTo(2 * perSide, 1));
    // 겹친 구간은 늦게 시작한 중력 첫 값에서 시작한다
    const overlapStartNs = (1000000 + _gravityLagUs) * 1000; // 겹침 시작
    expect(result.t0Ns, overlapStartNs + config.edgeTrimNs);
  });

  test('앞뒤를 버리면 남는 구간이 없는 측정은 사유와 함께 실패한다', () {
    final result = _resampler(200).resample(); // 0.78초 측정의 환산 결과

    expect(result.isSuccess, isFalse);
    expect(result.failureReason, contains('너무 짧다'));
    expect(result.samples, isEmpty, reason: '0 으로 채운 행을 만들지 않는다');
  });

  test('뒤집어 놓은 거치에 맞춰 Y · Z 부호만 뒤집는다', () {
    final result = _resampler(1024).resample(); // 환산 결과
    final row = result.samples[result.samples.length ~/ 2]; // 가운데 행

    expect(row.xMg, closeTo(1.0, 1e-9));
    expect(row.yMg, closeTo(-2.0, 1e-9));
    expect(row.zMg, closeTo(-3.0, 1e-9));
  });
}
