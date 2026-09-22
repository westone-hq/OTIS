/// 작성: 2026-09-15 20:13:49 · nada
/// 클래스: ReportVerdict
/// 목적: 지표 하나를 기준치와 견준 결과. 리포트에서 신호등 색으로 나온다.
///       - `green` — 기준 안에 들었다. 초록
///       - `red` — 기준을 넘었다. 빨강
///       - `unknown` — 기준은 있는데 값을 아직 재지 못했다. 회색.
///         재지 않은 것을 통과로 보고하지 않으려고 `green` 과 나눈다
///       - `none` — 기준 자체가 없는 항목이다. 신호등을 그리지 않는다.
///         원본 리포트도 운행 거리 · 최대 속도 행에는 원을 두지 않는다
enum ReportVerdict { green, red, unknown, none }

/// 작성: 2026-09-15 20:13:49 · nada
/// 클래스: ReportThresholds
/// 목적: 리포트 판정 기준치를 한곳에 모으고, 값을 견주는 일까지 맡는다.
///       저장소 안에서 기준 숫자가 적힌 곳은 여기뿐이다.
///
///       기준은 축별로 둔다. 요구사항이 축별로 정하고 있고, 측정 결과의
///       판정 게터도 축별이기 때문이다. 리포트 표는 수평을 X·Y 통합 한
///       행으로 내는데, 그 행을 위해 숫자를 따로 만들지 않는다. 대신
///       `judgeHorizontal()` 이 X 와 Y 를 각각 이 기준으로 보고 하나라도
///       넘으면 적색을 돌려준다. 숫자가 두 벌이 되면 한쪽만 고쳐져
///       어긋나기 때문이다.
///
///       황색 단계는 두지 않는다. 요구사항에 없다. 원본 H6N1AP65 리포트에
///       찍혀 있는 2단계 값(57/60, 72/75, 14/21 …)은 기존 iOS TuneApp 의
///       기준이라 이 프로젝트로 가져오지 않는다.
class ReportThresholds {
  /// 작성: 2026-09-15 20:13:49 · nada
  /// 변수: xPtpRedMg
  /// 목적: X축 진동 p2p 가 이 값을 넘으면 적색이다. (mg)
  /// 근거: 인용 — `pdf_report_dev/README.md` "판정 기준" 절이 정리한 값이며,
  ///       그 절은 요구사항서 `Vibration_Checking_App_Development_20260630.pdf`
  ///       6쪽을 정본으로 밝히고 있다. 요구사항서 자체는 저장소에 없다
  static const double xPtpRedMg = 10.0;

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 변수: yPtpRedMg
  /// 목적: Y축 진동 p2p 가 이 값을 넘으면 적색이다. (mg)
  /// 근거: 인용 — `xPtpRedMg` 와 같은 출처다
  static const double yPtpRedMg = 10.0;

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 변수: zPtpRedMg
  /// 목적: Z축(수직) 진동 p2p 가 이 값을 넘으면 적색이다. (mg)
  ///       수평 두 축보다 기준이 느슨하다.
  /// 근거: 인용 — `xPtpRedMg` 와 같은 출처다
  static const double zPtpRedMg = 15.0;

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 변수: noiseMaxRedDba
  /// 목적: 최대 소음이 이 값을 넘으면 적색이다. (dBA)
  /// 근거: 인용 — `xPtpRedMg` 와 같은 출처다
  static const double noiseMaxRedDba = 50.0;

  /// 작성: 2026-09-15 20:13:49 · nada
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

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 함수: judge
  /// 목적: 값 하나를 기준치와 견줘 신호등 색을 정한다.
  /// 인자: value — 견줄 값. 아직 재지 못했으면 null
  ///       redLimit — 적색 기준치. 기준이 없는 항목이면 null
  /// 반환: 기준이 없으면 `none`, 값이 없으면 `unknown`, 기준을 넘으면
  ///       `red`, 아니면 `green`
  static ReportVerdict judge(double? value, double? redLimit) {
    if (redLimit == null) return ReportVerdict.none;
    if (value == null) return ReportVerdict.unknown;
    return value > redLimit ? ReportVerdict.red : ReportVerdict.green;
  }

  /// 작성: 2026-09-15 20:13:49 · nada
  /// 함수: judgeHorizontal
  /// 목적: 리포트의 수평 진동 행 하나를 판정한다. 그 행은 X 와 Y 를 묶어
  ///       내보내지만 기준은 축마다 따로 있으므로, 두 축을 각각 보고
  ///       합친다.
  ///       - 하나라도 기준을 넘으면 적색이다
  ///       - 넘은 축이 없고 아직 재지 못한 축이 있으면 미확정이다.
  ///         한 축만 보고 "정상"이라고 할 수 없다
  ///       - 두 축 다 재서 둘 다 기준 안이면 녹색이다
  /// 인자: xPtp — X축 진동 p2p (mg). 아직 재지 못했으면 null
  ///       yPtp — Y축 진동 p2p (mg). 아직 재지 못했으면 null
  /// 반환: 두 축을 합친 신호등 색
  static ReportVerdict judgeHorizontal(double? xPtp, double? yPtp) {
    final x = judge(xPtp, xPtpRedMg); // X축만 본 결과
    final y = judge(yPtp, yPtpRedMg); // Y축만 본 결과
    if (x == ReportVerdict.red || y == ReportVerdict.red) {
      return ReportVerdict.red;
    }
    if (x == ReportVerdict.unknown || y == ReportVerdict.unknown) {
      return ReportVerdict.unknown;
    }
    return ReportVerdict.green;
  }
}
