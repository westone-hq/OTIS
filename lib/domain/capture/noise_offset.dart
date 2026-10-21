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

/// 작성: 2026-10-22 12:00:00 · nada
/// 변수: kNoiseTimeWeightSec
/// 목적: 소음 지수평활(시간가중) 시정수 (초). 안드로이드
///       (`NoiseCaptureHandler.TIME_WEIGHT_SEC`)가 쓰는 값과 같게 둔다 — Dart
///       와 코틀린은 상수를 함께 쓸 수 없어 두 곳에 있고, 시험
///       (`noise_weighting_test.dart`)이 둘이 같은지 본다. 처리 방식 표시
///       (`noiseMethodLabel()`)와 집계 파일에 쓴다.
/// 근거: 표준 — IEC 61672-1 "Slow" 1초(2026-10-22, 그 전 "Fast" 0.125초).
///       측정 — 2026-10-21 동시 측정 3회에서 최대가 OTIS PDF 와 ±1 dB 안.
///       dB 평균은 0.7 ~ 2.6 dB 오른다(docs/noise_otis_offset_notes.md)
const double kNoiseTimeWeightSec = 1.0;

/// 작성: 2026-10-20 17:10:22 · nada
/// 수정: 2026-10-22 12:00:00 · nada
/// 함수: noiseMethodLabel
/// 목적: 소음 계산 방식을 결과 파일(result.json `signalConditioning`)에 남길
///       문자열. 진동 처리 표시 뒤에 이어 붙인다.
///       - `noise(A,slow,+오프셋,표본속도Hz)` — A 가중 · Slow(1초) 평활 뒤
///         오프셋을 더했다. 표본 속도는 이 측정에서 실제로 연 마이크 속도
///         (48000, 못 열면 44100). 마이크를 못 연 측정은 표본 속도를 뺀다
///       - 2026-10-22 전 결과는 `noise(A,fast,+105.2)`(44100Hz, Fast 0.125초),
///         2026-10-20 전 결과는 표시가 없고 A 가중 없이 오프셋 87.3 이다
/// 인자: sampleRateHz — 소음 마이크를 연 표본 속도(Hz). 못 열었으면 null
/// 반환: 처리 방식 문자열
String noiseMethodLabel(int? sampleRateHz) =>
    'noise(A,slow,+$kDefaultMicDbfsToDbaOffset'
    '${sampleRateHz == null ? '' : ',${sampleRateHz}Hz'})';
