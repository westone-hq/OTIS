/// 작성: 2026-09-15 20:13:49 · 박건준
/// 수정: 2026-10-15 15:53:26 · 박건준
/// 클래스: ReportVerdict
/// 목적: 지표 하나를 기준치와 견준 결과. 리포트에서 신호등 색으로 나온다.
///       - `green` — 황색 기준 이하. 초록
///       - `yellow` — 황색 기준은 넘었고 적색 기준 이하. 노랑
///       - `red` — 적색 기준을 넘었다. 빨강
///       - `unknown` — 기준은 있는데 값을 아직 재지 못했다. 회색.
///         재지 않은 것을 통과로 보고하지 않으려고 `green` 과 나눈다
///       - `none` — 판정하지 않는 항목이다. 신호등을 그리지 않는다.
///         원본 리포트도 운행 거리 · 최대 속도 행에는 원을 두지 않는다
enum ReportVerdict { green, yellow, red, unknown, none }

/// 작성: 2026-09-15 20:13:49 · 박건준
/// 수정: 2026-10-15 16:50:04 · 박건준
/// 클래스: ReportThresholds
/// 목적: 리포트 판정 기준치를 한곳에 모으고, 값을 견주는 일까지 맡는다.
///       저장소 안에서 기준 숫자가 적힌 곳은 여기뿐이다.
///
///       Performance Metrics 여섯 행마다 황색 · 적색 두 단계를 둔다. 값이
///       황색 기준을 넘으면 황색, 적색 기준을 넘으면 적색이다.
///
///       수평 두 행은 X 와 Y 를 한 행으로 내지만 기준은 축마다 같은 값을
///       쓴다. `judgeHorizontal()` 이 X 와 Y 를 각각 이 기준으로 보고 더
///       나쁜 쪽을 돌려준다. 측정 결과의 축별 판정 게터(`xExceeded` 등)도
///       같은 적색 기준을 쓴다.
///
///       이 기준은 원본 리포트처럼 가중 · 운행 구간으로 낸 지표
///       (`MeasurementAssembler`, 2026-10-15)와 견주는 값이다. 그 전 결과
///       (가중 없이 측정 전체의 최대 − 최소)는 Z 에 운행 가감속이 섞여 이
///       기준과 견주면 늘 적색이다.
/// 근거: 인용 — 2026-10-15 사용자 지시 "황색 57,72,14,20,9,17,0,0 · 적색
///       60,75,21,30,13.5,25.5,0,0"(표 위에서부터). 원본 TUNE 리포트
///       H6N1AP65.pdf(저장소 밖 보관, 실제 현장 리포트) 1쪽 Performance
///       Metrics 의 황색 · 적색 칸과 같은 값이다. 2026-10-04 "요구사항서
///       값(Z 15, X·Y 10, 소음 50)을 쓰고 황색은 두지 않는다" 결정을
///       바꾼다
class ReportThresholds {
  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: noiseAvgYellowDba
  /// 목적: 평균 소음이 이 값을 넘으면 황색이다. (dBA)
  static const double noiseAvgYellowDba = 57.0;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: noiseAvgRedDba
  /// 목적: 평균 소음이 이 값을 넘으면 적색이다. (dBA)
  static const double noiseAvgRedDba = 60.0;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: noiseMaxYellowDba
  /// 목적: 최대 소음이 이 값을 넘으면 황색이다. (dBA)
  static const double noiseMaxYellowDba = 72.0;

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 변수: noiseMaxRedDba
  /// 목적: 최대 소음이 이 값을 넘으면 적색이다. (dBA)
  static const double noiseMaxRedDba = 75.0;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: zA95YellowMg
  /// 목적: 수직(Z) 진동 평균(A95)이 이 값을 넘으면 황색이다. (mg)
  static const double zA95YellowMg = 14.0;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: zA95RedMg
  /// 목적: 수직(Z) 진동 평균(A95)이 이 값을 넘으면 적색이다. (mg)
  static const double zA95RedMg = 21.0;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: zPtpYellowMg
  /// 목적: 수직(Z) 진동 최대(P2P)가 이 값을 넘으면 황색이다. (mg)
  static const double zPtpYellowMg = 20.0;

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 변수: zPtpRedMg
  /// 목적: 수직(Z) 진동 최대(P2P)가 이 값을 넘으면 적색이다. (mg)
  static const double zPtpRedMg = 30.0;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: horizA95YellowMg
  /// 목적: 수평(X · Y 각각) 진동 평균(A95)이 이 값을 넘으면 황색이다. (mg)
  static const double horizA95YellowMg = 9.0;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: horizA95RedMg
  /// 목적: 수평(X · Y 각각) 진동 평균(A95)이 이 값을 넘으면 적색이다. (mg)
  static const double horizA95RedMg = 13.5;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: horizPtpYellowMg
  /// 목적: 수평(X · Y 각각) 진동 최대(P2P)가 이 값을 넘으면 황색이다. (mg)
  static const double horizPtpYellowMg = 17.0;

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 변수: xPtpRedMg
  /// 목적: X축 진동 최대(P2P)가 이 값을 넘으면 적색이다. (mg) 수평 행의
  ///       적색 기준과 같다.
  static const double xPtpRedMg = 25.5;

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 변수: yPtpRedMg
  /// 목적: Y축 진동 최대(P2P)가 이 값을 넘으면 적색이다. (mg) 수평 행의
  ///       적색 기준과 같다.
  static const double yPtpRedMg = 25.5;

  /// 작성: 2026-10-15 15:53:26 · 박건준
  /// 변수: unjudgedLimit
  /// 목적: 판정하지 않는 행(최대 속도 · 운행 거리)의 황색 · 적색 칸에 찍는
  ///       값. 이 값으로 견주지 않는다 — 두 행의 신호등은 `none` 이다.
  /// 근거: 인용 — 2026-10-15 사용자 지시(두 행 모두 0, 0). 원본 리포트도
  ///       두 행 칸에 0 을 찍고 원은 두지 않는다
  static const double unjudgedLimit = 0.0;

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 함수: exceeds
  /// 목적: 값 하나가 기준치를 넘었는지 알려준다. 측정 결과의 판정 게터가
  ///       쓴다.
  /// 인자: value — 견줄 값. 아직 재지 못했으면 null
  ///       redLimit — 적색 기준치
  /// 반환: 넘었으면 true, 안 넘었으면 false. 값이 없으면 null — 재지 않은
  ///       것을 "정상"으로 보고하지 않기 위해서다
  static bool? exceeds(double? value, double redLimit) {
    if (value == null) return null;
    return value > redLimit;
  }

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: judge
  /// 목적: 값 하나를 황색 · 적색 기준과 견줘 신호등 색을 정한다. 기준과
  ///       같은 값은 넘지 않은 것으로 본다.
  /// 인자: value — 견줄 값. 아직 재지 못했으면 null
  ///       yellowLimit — 황색 기준치
  ///       redLimit — 적색 기준치. `yellowLimit` 이상이다
  /// 반환: 값이 없으면 `unknown`, 적색 기준을 넘으면 `red`, 황색 기준을
  ///       넘으면 `yellow`, 아니면 `green`
  static ReportVerdict judge(
    double? value,
    double yellowLimit,
    double redLimit,
  ) {
    assert(
      yellowLimit <= redLimit,
      '황색 기준이 적색 기준보다 크면 황색 단계가 생기지 않는다: '
      '$yellowLimit > $redLimit',
    );
    if (value == null) return ReportVerdict.unknown;
    if (value > redLimit) return ReportVerdict.red;
    if (value > yellowLimit) return ReportVerdict.yellow;
    return ReportVerdict.green;
  }

  /// 작성: 2026-09-15 20:13:49 · 박건준
  /// 수정: 2026-10-15 15:53:26 · 박건준
  /// 함수: judgeHorizontal
  /// 목적: 리포트의 수평 진동 행 하나를 판정한다. 그 행은 X 와 Y 를 묶어
  ///       내보내지만 두 축을 각각 같은 기준으로 보고 합친다.
  ///       - 하나라도 적색이면 적색이다
  ///       - 적색이 없고 아직 재지 못한 축이 있으면 미확정이다. 한 축만
  ///         보고 "정상" · "황색" 이라고 할 수 없다
  ///       - 두 축 다 쟀으면 더 나쁜 쪽(황색 > 녹색)이다
  /// 인자: x — X축 값 (mg). 아직 재지 못했으면 null
  ///       y — Y축 값 (mg). 아직 재지 못했으면 null
  ///       yellowLimit, redLimit — 그 행의 황색 · 적색 기준치 (mg)
  /// 반환: 두 축을 합친 신호등 색
  static ReportVerdict judgeHorizontal(
    double? x,
    double? y,
    double yellowLimit,
    double redLimit,
  ) {
    final both = <ReportVerdict>[
      judge(x, yellowLimit, redLimit),
      judge(y, yellowLimit, redLimit),
    ]; // 축마다 본 결과
    if (both.contains(ReportVerdict.red)) return ReportVerdict.red;
    if (both.contains(ReportVerdict.unknown)) return ReportVerdict.unknown;
    if (both.contains(ReportVerdict.yellow)) return ReportVerdict.yellow;
    return ReportVerdict.green;
  }
}
