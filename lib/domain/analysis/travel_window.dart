import 'package:vibration_checker/domain/config/capture_config.dart';

/// 작성: 2026-10-15 16:50:04 · 박건준
/// 클래스: TravelWindow
/// 목적: 진동 · 소음 지표를 낼 운행 구간. 출발한 뒤 위치가
///       `CaptureConfig.travelEdgeExclusionM` 를 넘은 첫 표본부터, 도착
///       위치까지 그 거리보다 많이 남은 마지막 표본까지다. 출발 · 정지
///       순간의 가감속 충격과 문 여닫이를 지표에서 뺀다.
///       최대 속도 · 운행 거리는 이 구간이 아니라 측정 전체에서 낸다.
/// 근거: 표준 — ISO 18738-1 승차감 평가 구간(출발 · 정지 0.5 m 제외).
///       2026-10-15 점검 지시. 예전(2026-10-07 결정)에는 측정 전체 구간을
///       썼다
class TravelWindow {
  /// 구간 첫 표본의 첨자 (포함)
  final int startIndex;

  /// 구간 마지막 표본의 첨자 (포함)
  final int endIndex;

  /// 구간 시작 시각 (측정 시작부터 초)
  final double startSec;

  /// 구간 끝 시각 (측정 시작부터 초)
  final double endSec;

  /// 구간 시작의 위치 (출발점부터 m)
  final double startM;

  /// 구간 끝의 위치 (출발점부터 m)
  final double endM;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: TravelWindow
  /// 목적: 값을 담는다. 위치 시계열에서 정할 때는 `TravelWindow.of()` 를
  ///       쓴다.
  /// 인자: startIndex, endIndex, startSec, endSec, startM, endM — 위 필드
  const TravelWindow({
    required this.startIndex,
    required this.endIndex,
    required this.startSec,
    required this.endSec,
    required this.startM,
    required this.endM,
  });

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: of
  /// 목적: 위치 시계열에서 운행 구간을 정한다. 위치가 늘어나든(상승 ·
  ///       누적 이동량) 줄어들든(하강, 부호 있는 위치) 출발점에서 떨어진
  ///       거리로 본다.
  ///       1. 운행 거리(끝 위치 − 시작 위치의 크기)가
  ///          `CaptureConfig.minimumTravelM` 이하면 실패
  ///       2. 출발점에서 `travelEdgeExclusionM` 를 넘게 떨어진 첫 표본과,
  ///          도착점까지 그보다 많이 남은 마지막 표본을 찾는다
  ///       3. 둘 중 하나를 못 찾거나 끝이 시작보다 앞이면 실패
  /// 인자: position — 위치 시계열 (m). 측정 시작이 첫 표본이다
  ///       sampleRate — 표본 속도 (Hz). 0 보다 크다
  /// 반환: 성공이면 구간, 실패면 사유
  static TravelWindowResult of(List<double> position, double sampleRate) {
    if (position.length < 2) {
      return TravelWindowResult.failure('위치 표본이 2개보다 적다: ${position.length}개');
    }
    final origin = position.first; // 출발 위치 (m)
    final arrival = position.last; // 도착 위치 (m)
    final travel = (arrival - origin).abs(); // 운행 거리 (m)
    const edge = CaptureConfig.travelEdgeExclusionM; // 양 끝에서 뺄 거리 (m)
    if (travel <= CaptureConfig.minimumTravelM) {
      return TravelWindowResult.failure(
        '운행 거리가 ${CaptureConfig.minimumTravelM}m 이하다: '
        '${travel.toStringAsFixed(3)}m',
      );
    }

    var start = -1; // 구간 첫 첨자. 못 찾으면 -1
    for (var i = 0; i < position.length; i++) {
      if ((position[i] - origin).abs() > edge) {
        start = i;
        break;
      }
    }
    var end = -1; // 구간 마지막 첨자. 못 찾으면 -1
    for (var i = position.length - 1; i >= 0; i--) {
      if ((arrival - position[i]).abs() > edge) {
        end = i;
        break;
      }
    }
    if (start < 0 || end < 0 || end <= start) {
      return TravelWindowResult.failure(
        '출발 · 도착 ${edge}m 를 빼면 남는 구간이 없다 '
        '(시작 첨자 $start, 끝 첨자 $end)',
      );
    }
    return TravelWindowResult.success(
      TravelWindow(
        startIndex: start,
        endIndex: end,
        startSec: start / sampleRate,
        endSec: end / sampleRate,
        startM: (position[start] - origin).abs(),
        endM: (position[end] - origin).abs(),
      ),
    );
  }

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: toMap
  /// 목적: 결과 파일(result.json)에 저장할 표로 바꾼다.
  /// 반환: 항목 이름을 열쇠로 하는 표
  Map<String, Object> toMap() => <String, Object>{
    'startIndex': startIndex,
    'endIndex': endIndex,
    'startSec': startSec,
    'endSec': endSec,
    'startM': startM,
    'endM': endM,
  };

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: TravelWindow.fromMap
  /// 목적: `toMap()` 이 만든 표에서 되살린다.
  /// 인자: map — 저장된 표
  /// 반환: 되살린 구간. 항목이 빠졌거나 자료형이 틀리면 `FormatException`
  factory TravelWindow.fromMap(Map<String, dynamic> map) {
    // 저장된 값을 정수로 읽는다. 숫자가 아니면 사유를 담아 던진다
    int intOf(String key) {
      final value = map[key]; // 저장된 값
      if (value is! num) throw FormatException('travelWindow.$key 가 숫자가 아니다');
      return value.toInt();
    }

    // 저장된 값을 실수로 읽는다. 숫자가 아니면 사유를 담아 던진다
    double doubleOf(String key) {
      final value = map[key]; // 저장된 값
      if (value is! num) throw FormatException('travelWindow.$key 가 숫자가 아니다');
      return value.toDouble();
    }

    return TravelWindow(
      startIndex: intOf('startIndex'),
      endIndex: intOf('endIndex'),
      startSec: doubleOf('startSec'),
      endSec: doubleOf('endSec'),
      startM: doubleOf('startM'),
      endM: doubleOf('endM'),
    );
  }
}

/// 작성: 2026-10-15 16:50:04 · 박건준
/// 클래스: TravelWindowResult
/// 목적: 운행 구간을 정한 결과. 성공이면 `window`, 실패면 `failureReason`
///       하나만 채운다. 구간을 못 정한 측정을 "구간 없음 = 전체 구간" 으로
///       조용히 바꾸지 않고 사유를 올린다(관통 원칙 4).
class TravelWindowResult {
  /// 정한 운행 구간. 실패면 null
  final TravelWindow? window;

  /// 정하지 못한 사유. 성공이면 null
  final String? failureReason;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: TravelWindowResult.success
  /// 목적: 성공 결과를 만든다.
  /// 인자: window — 정한 운행 구간
  const TravelWindowResult.success(TravelWindow this.window)
    : failureReason = null;

  /// 작성: 2026-10-15 16:50:04 · 박건준
  /// 함수: TravelWindowResult.failure
  /// 목적: 실패 결과를 만든다.
  /// 인자: failureReason — 정하지 못한 사유
  const TravelWindowResult.failure(String this.failureReason) : window = null;
}
