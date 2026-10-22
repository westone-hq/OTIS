import 'package:vibration_checker/domain/capture/native_event.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';

/// 작성: 2026-10-22 09:30:00 · nada
/// 클래스: Placement
/// 목적: 측정할 때 휴대폰을 어떻게 놓았는지. 거치 안내는 화면을 아래로
///       놓는 것이다(`PlacementSheet`). 화면을 위로 놓거나 기울이면 수직
///       값은 중력 방향 투영(`GridResampler.motionOf()`)이라 맞지만, 마이크가
///       위를 향해 소음 값이 달라질 수 있고 수평 축 방향이 OTIS 장비와
///       어긋난다.
///       - `faceDown` — 화면 아래 (권장)
///       - `faceUp` — 화면 위
///       - `tilted` — 그 밖(기울어짐)
enum Placement {
  faceDown,
  faceUp,
  tilted;

  /// 작성: 2026-10-22 09:30:00 · nada
  /// 함수: label
  /// 목적: 사람이 읽는 이름. 결과 화면 경고와 메일 본문이 쓴다.
  String get label => switch (this) {
    Placement.faceDown => '화면 아래',
    Placement.faceUp => '화면 위',
    Placement.tilted => '기울어짐',
  };

  /// 작성: 2026-10-22 09:30:00 · nada
  /// 함수: fromName
  /// 목적: 결과 파일에 적은 이름(`name`)에서 되살린다.
  /// 인자: name — 저장된 이름. 없으면 null
  /// 반환: 거치 방향. 이름이 없거나 모르는 이름이면 null — 판정하지 않은
  ///       예전 결과를 "화면 아래" 로 채우지 않는다
  static Placement? fromName(String? name) {
    for (final value in Placement.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// 작성: 2026-10-22 09:30:00 · nada
  /// 함수: of
  /// 목적: 중력 Z 평균으로 거치 방향을 판정한다. 안드로이드 가속도계는
  ///       가만히 있을 때 위쪽으로 1g 를 읽어, 화면(Z 축)이 바닥을 보면 중력
  ///       Z 가 약 −1000 mg, 하늘을 보면 약 +1000 mg 다.
  /// 인자: meanGravityZMg — 중력 Z 평균 (mg)
  /// 반환: `CaptureConfig.placementFaceDownMaxMg` 이하면 화면 아래,
  ///       `CaptureConfig.placementFaceUpMinMg` 이상이면 화면 위, 그 밖은
  ///       기울어짐
  static Placement of(double meanGravityZMg) {
    if (meanGravityZMg <= CaptureConfig.placementFaceDownMaxMg) {
      return Placement.faceDown;
    }
    if (meanGravityZMg >= CaptureConfig.placementFaceUpMinMg) {
      return Placement.faceUp;
    }
    return Placement.tilted;
  }
}

/// 작성: 2026-10-22 09:30:00 · nada
/// 클래스: PlacementReading
/// 목적: 거치 방향 판정 한 건 — 방향과 판정에 쓴 중력 Z 평균.
class PlacementReading {
  /// 작성: 2026-10-22 09:30:00 · nada
  /// 함수: PlacementReading
  /// 목적: 판정 결과를 그대로 담는다.
  /// 인자: placement — 거치 방향
  ///       gravityZMg — 판정에 쓴 중력 Z 평균 (mg)
  const PlacementReading(this.placement, this.gravityZMg);

  /// 거치 방향
  final Placement placement;

  /// 판정에 쓴 중력 Z 평균 (mg)
  final double gravityZMg;
}

/// 작성: 2026-10-22 09:30:00 · nada
/// 클래스: PlacementMonitor
/// 목적: 수집 시작 후 처음 `CaptureConfig.placementWindowMs` 동안의 중력
///       이벤트로 거치 방향을 한 번 판정한다. 측정 중 경고(`CaptureSession`)와
///       저장 기록이 같은 판정을 쓴다.
class PlacementMonitor {
  /// 첫 중력 이벤트 시각 (마이크로초). 아직 없으면 null
  int? _startUs;

  /// 창 안 중력 Z 합 (mg)
  double _sum = 0.0;

  /// 창 안 중력 이벤트 수
  int _count = 0;

  /// 판정 결과. 창이 다 차기 전이면 null
  PlacementReading? _reading;

  /// 작성: 2026-10-22 09:30:00 · nada
  /// 함수: reading
  /// 목적: 판정 결과. 창이 다 차기 전(측정이 1초보다 짧음)이면 null.
  PlacementReading? get reading => _reading;

  /// 작성: 2026-10-22 17:10:00 · nada
  /// 함수: startUs
  /// 목적: 판정 창을 시작한 첫 중력 이벤트 시각 (마이크로초). 거치 경고 시각
  ///       (`CaptureConfig.placementAlertDelayMs`)을 여기서 잰다. 아직 중력
  ///       이벤트가 없으면 null.
  int? get startUs => _startUs;

  /// 작성: 2026-10-22 09:30:00 · nada
  /// 함수: onEvent
  /// 목적: 이벤트 한 건을 받는다. 중력 이벤트만 모으고, 세 축이 모두 0 인
  ///       것(센서 버퍼가 차기 전 값, `GridResampler._accept()` 와 같은
  ///       규칙)은 버린다. 첫 중력 이벤트부터 창 길이가 지난 첫 이벤트에서
  ///       그때까지 모은 평균으로 판정한다. 한 번 판정하면 더 모으지 않는다.
  /// 인자: event — 안드로이드에서 도착한 원본 이벤트
  /// 반환: 이번 이벤트로 판정했으면 그 결과, 아니면 null — 부르는 쪽이 판정
  ///       순간을 한 번만 알 수 있게 한다
  PlacementReading? onEvent(NativeEvent event) {
    if (_reading != null || event.type != NativeEventType.gravity) return null;
    if (event.xMg == 0.0 && event.yMg == 0.0 && event.zMg == 0.0) return null;
    final start = _startUs ??= event.tsUs; // 창 시작 시각
    if (event.tsUs - start < CaptureConfig.placementWindowMs * 1000) {
      _sum += event.zMg;
      _count++;
      return null;
    }
    // 첫 이벤트는 경과 0 이라 반드시 위 갈래에서 모이므로 여기서 개수가
    // 0 일 수 없다. 나누기 전에 확인만 한다
    assert(_count > 0, '거치 판정 창에 모인 중력 이벤트가 없다');
    final mean = _sum / _count; // 중력 Z 평균 (mg)
    // → 로직 이동: Placement.of()
    return _reading = PlacementReading(Placement.of(mean), mean);
  }
}
