/// 작성: 2026-09-28 · 박희정
/// 목적: dBFS→dBA 기본 오프셋 한곳. Android·Dart 시작 인자가 같이 본다.
/// 근거: OI-4 임시값 85.0 대신, OTIS 동시측정과 맞춘 임시값 87.3
///       (우리 쪽이 약 2.3 dB 낮게 나와서 올렸다). 현장·기기 보정은
///       별도 `calibrationOffsetDba` 로 더한다.
const double kDefaultMicDbfsToDbaOffset = 87.3;
