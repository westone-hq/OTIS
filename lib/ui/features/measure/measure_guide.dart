/// 작성: 2026-10-27 12:00:00 · 박건준
/// 변수: measureStartGuide
/// 목적: 측정 시작 안내 문구. 시작 화면 · 카운트다운 화면 · 거치 안내가 같은
///       문구를 쓴다(`measureGuideLines`).
/// 근거: 인용 — 2026-10-27 사용자 지시 문구
const String measureStartGuide = '카운트 다운 후 삐 소리와 함께 측정이 시작됩니다';

/// 작성: 2026-10-27 12:00:00 · 박건준
/// 변수: measureEndGuide
/// 목적: 측정 종료 안내 문구. "볼륨키로 끝냅니다" 를 바꾼다.
/// 근거: 인용 — 2026-10-27 사용자 지시 문구
const String measureEndGuide = '볼륨키를 누르면 삐 소리와 함께 측정이 종료됩니다.';

/// 작성: 2026-10-27 12:00:00 · 박건준
/// 변수: measureWaitGuide
/// 목적: 종료 전 1초 기다림 안내. 정지 직후에 끝내면 끝부분 값이
///       부정확해진다(`MeasurementResult.stoppedTooSoon`).
/// 근거: 인용 — 2026-10-27 사용자 지시 "운행 1초 대기 안내는 함께 넣도록",
///       2026-10-22 "운행이 멈춘 뒤 1초 기다렸다가" 문구를 잇는다
const String measureWaitGuide = '운행이 멈춘 뒤 1초 기다렸다가 누르세요.';

/// 작성: 2026-10-27 12:00:00 · 박건준
/// 변수: measureGuideLines
/// 목적: 측정 전에 보여 줄 안내 세 줄과 그 차례(시작 → 종료 → 기다림).
const List<String> measureGuideLines = <String>[
  measureStartGuide,
  measureEndGuide,
  measureWaitGuide,
];
