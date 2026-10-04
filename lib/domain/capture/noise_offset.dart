/// 작성: 2026-09-28 15:00:36 · 박희정
/// 수정: 2026-10-04 13:44:32 · nada
/// 변수: kDefaultMicDbfsToDbaOffset
/// 목적: 마이크 신호 크기(dBFS, 디지털로 담을 수 있는 최대 크기를 0 으로
///       잡은 데시벨)를 소음 크기(dBA)로 옮길 때 더하는 기본 오프셋.
///       측정을 시작할 때 Dart 가 이 값을 안드로이드로 넘긴다. 안드로이드
///       쪽 기본값(`NoiseCaptureHandler.DEFAULT_MIC_DBFS_TO_DBA_OFFSET`)은
///       값이 넘어오지 않을 때만 쓰이며, 이 값과 같게 맞춰 둔다. 현장 ·
///       기기별 보정은 따로 `calibrationOffsetDba` 로 더한다.
/// 근거: 측정 — OTIS 소음계와 동시에 잰 비교에서 우리 값이 약 2.3dB 낮게
///       나와, 처음 임시로 둔 85.0 에서 올렸다. 아직 임시값이다
///       (`docs/noise_otis_offset_notes.md`)
const double kDefaultMicDbfsToDbaOffset = 87.3;
