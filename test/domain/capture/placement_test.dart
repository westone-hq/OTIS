import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/capture/placement.dart';

/// 작성: 2026-10-22 09:30:00 · nada
/// 함수: _gravity
/// 목적: 중력 이벤트 한 건을 만든다.
/// 인자: ms — 시각 (밀리초)
///       z — 중력 Z (mg)
/// 반환: 중력 이벤트
NativeEvent _gravity(int ms, double z) => NativeEvent(
  type: NativeEventType.gravity,
  tsUs: ms * 1000,
  xMg: 0,
  yMg: 30,
  zMg: z,
  dtUs: 4000,
);

/// 작성: 2026-10-22 09:30:00 · nada
/// 함수: main
/// 목적: 거치 방향 판정(`Placement.of()`)의 세 갈래와 경계, 수집 처음 1초를
///       모으는 감시기(`PlacementMonitor`)를 시험한다.
void main() {
  group('Placement.of — 중력 Z 평균으로 판정', () {
    test('세 갈래', () {
      expect(Placement.of(-1000), Placement.faceDown);
      expect(Placement.of(1000), Placement.faceUp);
      expect(Placement.of(0), Placement.tilted);
      expect(Placement.of(-700), Placement.tilted);
    });

    test('경계값: −940 이하 화면 아래, +940 이상 화면 위', () {
      expect(Placement.of(-940), Placement.faceDown);
      expect(Placement.of(-939.99), Placement.tilted);
      expect(Placement.of(940), Placement.faceUp);
      expect(Placement.of(939.99), Placement.tilted);
      expect(CaptureConfig.placementFaceDownMaxMg, -940.0);
      expect(CaptureConfig.placementFaceUpMinMg, 940.0);
    });

    test('이름 · 표시 글자', () {
      expect(Placement.fromName('faceUp'), Placement.faceUp);
      expect(Placement.fromName(null), isNull);
      expect(Placement.fromName('모름'), isNull);
      expect(Placement.faceDown.label, '화면 아래');
      expect(Placement.faceUp.label, '화면 위');
      expect(Placement.tilted.label, '기울어짐');
    });
  });

  group('PlacementMonitor — 처음 1초', () {
    test('1초가 지난 첫 중력 이벤트에서 그때까지의 평균으로 한 번만 판정한다', () {
      final monitor = PlacementMonitor(); // 시험할 감시기
      expect(monitor.onEvent(_gravity(100, 1000)), isNull);
      expect(monitor.onEvent(_gravity(600, 990)), isNull);
      // 1초 뒤 값(−1000)은 평균에 넣지 않는다
      final judged = monitor.onEvent(_gravity(1100, -1000));
      expect(judged!.placement, Placement.faceUp);
      expect(judged.gravityZMg, closeTo(995, 1e-9));
      expect(monitor.onEvent(_gravity(1200, -1000)), isNull, reason: '한 번만');
      expect(monitor.reading!.placement, Placement.faceUp);
    });

    test('세 축 0 인 중력과 가속도 이벤트는 모으지 않는다', () {
      final monitor = PlacementMonitor(); // 시험할 감시기
      monitor.onEvent(
        const NativeEvent(
          type: NativeEventType.gravity,
          tsUs: 0,
          xMg: 0,
          yMg: 0,
          zMg: 0,
          dtUs: 0,
        ),
      );
      monitor.onEvent(
        const NativeEvent(
          type: NativeEventType.accel,
          tsUs: 10000,
          xMg: 0,
          yMg: 0,
          zMg: 1000,
          dtUs: 0,
        ),
      );
      monitor.onEvent(_gravity(50, -995));
      final judged = monitor.onEvent(_gravity(1050, -995)); // 첫 중력 + 1초
      expect(judged!.placement, Placement.faceDown);
      expect(judged.gravityZMg, closeTo(-995, 1e-9));
    });

    test('1초가 차기 전에 끝난 측정은 판정이 없다', () {
      final monitor = PlacementMonitor(); // 시험할 감시기
      monitor.onEvent(_gravity(0, -1000));
      monitor.onEvent(_gravity(900, -1000));
      expect(monitor.reading, isNull);
    });
  });
}
