/// 작성: 2026-09-28 15:00:36 · 박희정
/// 수정: 2026-10-20 17:10:22 · nada
/// 변수: kDefaultMicDbfsToDbaOffset
/// 목적: A 가중한 마이크 신호 크기(dBFS, 디지털로 담을 수 있는 최대 크기를
///       0 으로 잡은 데시벨)를 소음 크기(dBA)로 옮길 때 더하는 기본 오프셋.
///       A 가중은 안드로이드(`NoiseCaptureHandler.A_WEIGHTING_SOS`)가 건다.
///       측정을 시작할 때 Dart 가 이 값을 안드로이드로 넘긴다. 안드로이드
///       쪽 기본값(`NoiseCaptureHandler.DEFAULT_MIC_DBFS_TO_DBA_OFFSET`)은
///       값이 넘어오지 않을 때만 쓰이며, 이 값과 같게 맞춰 둔다. 현장 ·
///       기기별 보정은 따로 `calibrationOffsetDba` 로 더한다.
/// 근거: 측정 — 2026-10-20 오티스폰 · 테스트폰 동시 기록 3건(1분 정지 ·
///       정면 · 배꼽, 원본은 분석 뒤 삭제)에서 A 가중한 우리 dBFS 와 오티스
///       값의 차 중앙값이 100.2 · 104.9 · 110.5 dB 라 그 평균을 썼다. 정면
///       기록은 평균 · 최대가 0.2 dB 안으로 맞고, 나머지 둘은 조용한 구간이
///       ±5 dB 갈린다(두 폰이 놓인 자리 차이로 보인다). 예전 값 87.3 은 A
///       가중 없이 개발폰에 맞춘 값이다.
///       미정 — 두 폰을 같은 자리 · 같은 방향에 두고 다시 재 확정한다.
///       폰마다 마이크 감도가 달라(개발폰은 예전에 2 ~ 3 dB, 테스트폰은
///       7.5 ~ 11.6 dB 낮았다) 기기별 보정(`calibrationOffsetDba`)이 필요할
///       수 있다 (`docs/noise_otis_offset_notes.md`)
const double kDefaultMicDbfsToDbaOffset = 105.2;

/// 작성: 2026-10-20 17:10:22 · nada
/// 변수: kNoiseMethodLabel
/// 목적: 소음 계산 방식을 결과 파일(result.json `signalConditioning`)에 남길
///       문자열. 진동 처리 표시 뒤에 이어 붙인다. 이 표시가 없는 2026-10-20
///       전 결과의 소음은 A 가중 없이 오프셋 87.3 을 더한 값이다.
///       - `noise(A,fast,+오프셋)` — A 가중 · Fast 평활 뒤 오프셋을 더했다
const String kNoiseMethodLabel = 'noise(A,fast,+$kDefaultMicDbfsToDbaOffset)';
