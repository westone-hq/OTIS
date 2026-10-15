import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/report/travel_window.dart';

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: _ramp
/// 목적: 0 에서 `distance` 까지 고르게 움직이는 위치 시계열을 만든다.
/// 인자: distance — 끝 위치 (m). 음수면 하강
///       count — 표본 수
/// 반환: 위치 시계열 (m)
List<double> _ramp(double distance, int count) =>
    List<double>.generate(count, (i) => distance * i / (count - 1));

/// 작성: 2026-10-15 16:50:04 · nada
/// 함수: main
/// 목적: 운행 구간(`TravelWindow.of()`)을 시험한다. 정상 / 운행 1 m 이하 /
///       끝까지 0.5 m 를 못 넘음 / 하강 운행(위치 음수)과, 결과 파일 왕복.
void main() {
  test('출발 뒤 0.5 m 를 넘은 첫 표본부터 도착 0.5 m 전 마지막 표본까지다', () {
    // 0 → 10 m 를 1001표본(0.01 m 간격)으로. 0.5 m 를 넘는 첫 표본은 51번,
    // 9.5 m 보다 앞인 마지막 표본은 949번
    final result = TravelWindow.of(_ramp(10, 1001), 100); // 구간 결과
    final window = result.window!; // 정한 구간
    expect(result.failureReason, isNull);
    expect(window.startIndex, 51);
    expect(window.endIndex, 949);
    expect(window.startSec, closeTo(0.51, 1e-12));
    expect(window.endSec, closeTo(9.49, 1e-12));
    expect(window.startM, closeTo(0.51, 1e-12));
    expect(window.endM, closeTo(9.49, 1e-12));
  });

  test('운행 거리가 1 m 이하면 사유를 담아 실패한다', () {
    final result = TravelWindow.of(_ramp(1.0, 200), 100); // 1 m 운행
    expect(result.window, isNull);
    expect(result.failureReason, contains('1.0m 이하'));
  });

  test('위치가 끝 무렵에야 0.5 m 를 넘으면 남는 구간이 없어 실패한다', () {
    // 거의 끝까지 서 있다가 마지막 표본에서 1.2 m 로 뛴다
    final position = <double>[...List<double>.filled(500, 0.0), 1.2]; // 위치
    final result = TravelWindow.of(position, 100); // 구간 결과
    expect(result.window, isNull);
    expect(result.failureReason, contains('남는 구간이 없다'));
  });

  test('하강 운행(위치가 음수로 줄어듦)도 떨어진 거리로 본다', () {
    final result = TravelWindow.of(_ramp(-10, 1001), 100); // 하강 구간
    expect(result.window!.startIndex, 51);
    expect(result.window!.endIndex, 949);
    expect(result.window!.startM, closeTo(0.51, 1e-12));
  });

  test('결과 파일 표로 바꿨다 되살리면 같다', () {
    final window = TravelWindow.of(_ramp(10, 1001), 100).window!; // 구간
    final back = TravelWindow.fromMap(window.toMap()); // 되살린 구간
    expect(back.startIndex, window.startIndex);
    expect(back.endIndex, window.endIndex);
    expect(back.startSec, window.startSec);
    expect(back.endM, window.endM);
    expect(
      () => TravelWindow.fromMap(<String, dynamic>{'startIndex': 1}),
      throwsFormatException,
    );
  });
}
