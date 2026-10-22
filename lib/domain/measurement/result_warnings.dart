import 'package:vibration_checker/domain/capture/placement.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';

/// 작성: 2026-10-22 09:30:00 · nada
/// 함수: placementWarning
/// 목적: 결과 화면에 띄울 거치 경고 문구를 고른다. 화면 아래가 아니게
///       놓고 잰 결과에만 띄운다. 재측정은 아래 "테스트 재실행" 버튼을 쓴다.
/// 인자: result — 측정 결과
/// 반환: 경고 문구. 화면 아래로 잰 결과이거나 판정하지 않은 예전 결과면 null
/// 근거: 인용 — 2026-10-22 사용자 지시 문구
String? placementWarning(MeasurementResult result) {
  final kind = switch (result.placementKind) {
    Placement.faceUp => '화면 위',
    Placement.tilted => '기울어진',
    Placement.faceDown || null => null,
  }; // 경고에 넣을 거치 이름, 경고하지 않으면 null
  if (kind == null) return null;
  return '$kind 거치로 측정됨 — 소음 · 수평 값이 달라질 수 있습니다. '
      '재측정을 권합니다';
}

/// 작성: 2026-10-22 19:00:00 · nada
/// 함수: resultWarnings
/// 목적: 결과 화면 위쪽에 띄울 경고 문구를 고른다. 판정은 결과 모델 게터가
///       하고 여기서는 문구만 고른다.
///       - 거치 경고(`placementWarning()`)
///       - 정지 직후 끝낸 측정(`MeasurementResult.stoppedTooSoon`)
///       - 기준선 구간에 움직임(`MeasurementResult.baselineContaminated`)
///       - 보정 표에 없는 기종(`MeasurementResult.uncompensatedDevice`)
/// 인자: result — 측정 결과
/// 반환: 경고 문구 목록. 없으면 빈 목록
/// 근거: 인용 — 2026-10-22 점검 지시 문구("정지 후 1초 이상 기다린 뒤
///       종료하세요 — 끝부분 값이 부정확할 수 있습니다", "시작 후 2초
///       기다린 뒤 출발", "미보정 기종")
List<String> resultWarnings(MeasurementResult result) => <String>[
  // → 로직 이동: placementWarning()
  ?placementWarning(result),
  if (result.stoppedTooSoon) '정지 후 1초 이상 기다린 뒤 종료하세요 — 끝부분 값이 부정확할 수 있습니다',
  if (result.baselineContaminated) '시작 후 2초 기다린 뒤 출발하세요 — 측정 시작 직후에 움직임이 있었습니다',
  if (result.uncompensatedDevice)
    '미보정 기종(${result.deviceModel ?? '기종 미확인'}) — 진동 값이 기준 폰과 '
        '다를 수 있습니다',
];
