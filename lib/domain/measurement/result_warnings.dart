import 'package:vibration_checker/domain/capture/placement.dart';
import 'package:vibration_checker/domain/measurement/measurement_result.dart';

/// 작성: 2026-10-22 09:30:00 · 박건준
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

/// 작성: 2026-10-22 19:00:00 · 박건준
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

/// 작성: 2026-10-23 00:20:00 · 박건준
/// 함수: placementMailLine
/// 목적: 메일 본문에 적을 거치 방향 줄을 만든다(2026-10-22). 결과 화면
///       경고와 달리 화면 아래로 잰 결과도 적는다 — 받는 쪽이 거치를 알게
///       하려는 것이다.
/// 인자: result — 보낼 측정 결과
/// 반환: 예 "거치: 화면 아래". 판정 전 예전 결과면 null
String? placementMailLine(MeasurementResult result) {
  final placement = result.placementKind; // 거치 방향, 예전 결과면 null
  return placement == null ? null : '거치: ${placement.label}';
}

/// 작성: 2026-10-23 00:20:00 · 박건준
/// 함수: uncompensatedDeviceMailLine
/// 목적: 기종 응답 보정 표에 없는 기종으로 잰 결과면 메일 본문에 적을 줄을
///       만든다(2026-10-22). 결과 화면 경고(`resultWarnings()`)와 같은
///       판정(`MeasurementResult.uncompensatedDevice`)이다.
/// 인자: result — 보낼 측정 결과
/// 반환: 예 "미보정 기종: samsung SM-A536N", 기종을 모르면 "미보정 기종:
///       기종 미확인". 보정한 기종이거나 예전 결과면 null
String? uncompensatedDeviceMailLine(MeasurementResult result) {
  if (!result.uncompensatedDevice) return null;
  final device = <String?>[
    result.deviceManufacturer,
    result.deviceModel,
  ].nonNulls.join(' '); // 측정한 휴대폰 "제조사 기종", 모르면 빈 문자열
  return '미보정 기종: ${device.isEmpty ? '기종 미확인' : device}';
}
