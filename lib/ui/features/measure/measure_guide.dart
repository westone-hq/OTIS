/// 작성: 2026-10-28 10:00:00 · 박건준
/// 변수: measureBeepGuide
/// 목적: 시작 · 종료 알림음 안내 문구. 시작 화면 · 거치 안내 3단계가 쓴다.
/// 근거: 인용 — 2026-10-28 사용자 지시 문구(2026-10-27 "카운트 다운 후 삐
///       소리와 함께 측정이 시작됩니다" 를 바꿈)
const String measureBeepGuide = '측정 시작과 종료시 삐 소리가 납니다.';

/// 작성: 2026-10-27 12:00:00 · 박건준
/// 수정: 2026-10-28 10:00:00 · 박건준
/// 변수: measureEndGuide
/// 목적: 측정 종료 안내 문구. 시작 화면 · 측정 중 화면 · 거치 안내 4단계가
///       쓴다.
/// 근거: 인용 — 2026-10-28 사용자 지시 문구
const String measureEndGuide = '볼륨키를 누르면 측정이 종료됩니다.';

/// 작성: 2026-10-28 10:00:00 · 박건준
/// 변수: measureIdleGuide
/// 목적: 운행 중에 시작 · 종료하지 말라는 안내. 정지 직후 · 출발 직후에
///       끊으면 끝부분 값이 부정확해진다(`MeasurementResult.stoppedTooSoon` ·
///       `baselineContaminated`). 2026-10-27 의 "운행이 멈춘 뒤 1초
///       기다렸다가 누르세요." 를 대신한다.
/// 근거: 인용 — 2026-10-28 사용자 지시 문구 그대로("아닐때" 띄어쓰기 포함)
const String measureIdleGuide = '운행 중이 아닐때 측정을 시작/종료 해주세요.';

/// 작성: 2026-10-27 12:00:00 · 박건준
/// 수정: 2026-10-28 10:00:00 · 박건준
/// 변수: measureGuideLines
/// 목적: 시작 화면에 보여 줄 안내 세 줄과 그 차례(알림음 → 종료 → 운행 중
///       아닐 때).
const List<String> measureGuideLines = <String>[
  measureBeepGuide,
  measureEndGuide,
  measureIdleGuide,
];
