import 'package:vibration_checker/domain/measurement/measurement_result.dart';

/// 작성: 2026-10-22 19:00:00 · 박건준
/// 수정: 2026-10-27 12:00:00 · 박건준
/// 함수: resultWarnings
/// 목적: 결과 화면 위쪽에 띄울 경고 문구를 고른다. 판정은 결과 모델 게터가
///       하고 여기서는 문구만 고른다.
///       - 정지 직후 끝낸 측정(`MeasurementResult.stoppedTooSoon`)
///       - 기준선 구간에 움직임(`MeasurementResult.baselineContaminated`)
///       거치 경고 · 미보정 기종 경고는 2026-10-27 사용자 지시로 없앴다 —
///       거치 방향 · 보정 여부는 결과 · 진단 기록에만 남는다. 메일 본문에도
///       경고 줄을 넣지 않는다.
/// 인자: result — 측정 결과
/// 반환: 경고 문구 목록. 없으면 빈 목록
/// 근거: 인용 — 2026-10-22 점검 지시 문구("정지 후 1초 이상 기다린 뒤
///       종료하세요 — 끝부분 값이 부정확할 수 있습니다", "시작 후 2초
///       기다린 뒤 출발")
List<String> resultWarnings(MeasurementResult result) => <String>[
  if (result.stoppedTooSoon) '정지 후 1초 이상 기다린 뒤 종료하세요 — 끝부분 값이 부정확할 수 있습니다',
  if (result.baselineContaminated) '시작 후 2초 기다린 뒤 출발하세요 — 측정 시작 직후에 움직임이 있었습니다',
];
