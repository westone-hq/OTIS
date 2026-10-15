import 'dart:math' as math;

import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-15 21:14:33 · nada
/// 수정: 2026-10-15 15:53:26 · nada
/// 클래스: ReportMetric
/// 목적: Performance Metrics 표의 한 행에 들어갈 지표 하나를 담는다. 값과
///       단위뿐 아니라, 그 값을 표에 어떻게 찍을지(`display`)와 신호등을
///       무슨 색으로 그릴지(`verdict`)까지 여기서 정해 둔다. 그리는 쪽은
///       판단하지 않고 받아 적기만 한다.
///
///       값이 없는 지표도 행 자체는 그려야 하므로 `value` 를 비운 채로
///       만든다. 그때 `display` 는 `—` 이고 `verdict` 는 미확정이다.
///       재지 못한 자리를 0 이나 빈 문자열로 메우지 않는다.
class ReportMetric {
  /// 작성: 2026-10-15 15:53:26 · nada
  /// 변수: vibrationUnit
  /// 목적: 리포트가 진동 값(mg) 뒤에 붙이는 단위 표기. 1쪽 표와 차트
  ///       값 글자가 함께 쓴다. 저장 값 · 앱 화면의 단위는 그대로 mg 다.
  /// 근거: 인용 — 2026-10-15 사용자 지시 "mg 값 milli-G 로 단위 표기
  ///       변경". 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제 현장
  ///       리포트) 1쪽 표기 "3.6milli-G A95"
  static const String vibrationUnit = 'milli-G';

  /// 서식에서 이 행을 부르는 이름. `ReportPage1.metricRows` 의 `key` 와 같다
  final String key;

  /// 지표 값. 아직 낼 수 없으면 null
  final double? value;

  /// 값 뒤에 붙는 단위 (`dBA`, `vibrationUnit`, `m/s`, `m`)
  final String unit;

  /// 단위 뒤에 한 칸 띄고 붙는 꼬리표. 지금은 평균 진동의 `A95` 뿐이고,
  /// 없으면 빈 문자열
  final String suffix;

  /// 황색 칸에 찍는 기준치. 칸을 비우는 행이면 null
  final double? yellowLimit;

  /// 적색 칸에 찍는 기준치. 칸을 비우는 행이면 null
  final double? redLimit;

  /// 신호등 색. `ReportThresholds` 가 정한다
  final ReportVerdict verdict;

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 수정: 2026-10-15 15:53:26 · nada
  /// 함수: ReportMetric
  /// 목적: 지표 한 행의 값과 표시 정보를 그대로 담는 생성자.
  /// 인자: key — 서식 행 이름
  ///       value — 지표 값. 없으면 null
  ///       unit — 단위
  ///       verdict — 신호등 색
  ///       suffix — 꼬리표. 기본 빈 문자열
  ///       yellowLimit, redLimit — 황색 · 적색 칸 기준치. 칸을 비우면
  ///       null
  const ReportMetric({
    required this.key,
    required this.value,
    required this.unit,
    required this.verdict,
    this.suffix = '',
    this.yellowLimit,
    this.redLimit,
  });

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: _decimalsByUnit
  /// 목적: 단위마다 값 칸에 남길 소수 자리 수. 여기 없는 단위는
  ///       `_defaultDecimals` 자리다. 값이 100 이상이면 단위와 상관없이
  ///       소수점을 뗀다.
  /// 근거: 인용 — 원본 TUNE 리포트 H6N1AP65.pdf(저장소 밖 보관, 실제 현장
  ///       리포트) 1쪽 "1.75m/s"(둘째 자리) · "57.3m" · "45.5dBA" ·
  ///       "6.1milli-G"(첫째 자리). 2026-10-15 점검 지시
  static const Map<String, int> _decimalsByUnit = <String, int>{'m/s': 2};

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 변수: _defaultDecimals
  /// 목적: `_decimalsByUnit` 에 없는 단위의 소수 자리 수.
  static const int _defaultDecimals = 1;

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 수정: 2026-10-15 16:50:04 · nada
  /// 함수: display
  /// 목적: 표의 값 칸에 그대로 찍을 문자열을 만든다. 값이 100 이상이면
  ///       소수점을 떼고, 그보다 작으면 단위별 자리(`_decimalsByUnit`,
  ///       최대 속도 둘째 자리 · 나머지 첫째 자리)만 남긴다. 꼬리표가
  ///       있으면 뒤에 붙인다. 수평 행에 X · Y 내역을 덧붙이지 않는다
  ///       (2026-10-15 사용자 지시) — 원본 리포트도 큰 쪽 값 하나만 적는다.
  /// 반환: 값 칸 문자열. 값이 없으면 `—`
  String get display {
    final amount = value; // 지역으로 옮겨야 null 검사가 이어진다
    if (amount == null) return '—';
    final decimals = // 이 단위의 소수 자리 수
        _decimalsByUnit[unit] ?? _defaultDecimals;
    final digits = amount.abs() >= 100
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(decimals); // 자릿수를 맞춘 숫자 부분
    return suffix.isEmpty ? '$digits$unit' : '$digits$unit $suffix';
  }

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 함수: yellowDisplay
  /// 목적: 표의 황색 기준 칸에 찍을 문자열을 만든다.
  /// 반환: 기준치 문자열. 칸을 비우는 행이면 빈 문자열
  String get yellowDisplay => _limitText(yellowLimit);

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 수정: 2026-10-15 15:53:26 · nada
  /// 함수: redDisplay
  /// 목적: 표의 적색 기준 칸에 찍을 문자열을 만든다.
  /// 반환: 기준치 문자열. 칸을 비우는 행이면 빈 문자열
  String get redDisplay => _limitText(redLimit);

  /// 작성: 2026-10-15 15:53:26 · nada
  /// 함수: _limitText
  /// 목적: 기준치 하나를 칸에 찍을 문자열로 바꾼다. 정수면 소수점을 떼고
  ///       ("60"), 아니면 그대로("13.5") 적는다.
  /// 인자: limit — 기준치. 없으면 null
  /// 반환: 기준치 문자열. 없으면 빈 문자열
  static String _limitText(double? limit) {
    if (limit == null) return '';
    return limit == limit.roundToDouble()
        ? limit.toStringAsFixed(0)
        : limit.toString();
  }
}

/// 작성: 2026-09-15 21:14:33 · nada
/// 수정: 2026-10-15 15:53:26 · nada
/// 클래스: ReportMetrics
/// 목적: 측정 결과 하나에서 Performance Metrics 표 여덟 행을 만든다.
///       임계값은 여기 적지 않고 `ReportThresholds` 에서 가져온다.
///
///       지금 값이 나오는 것
///         - 최대 속도 · 운행 거리
///         - 소음 평균 · 최대
///         - 수직 · 수평 진동 최대: 신호 처리 후 100Hz 시계열의 P2P
///         - 수직 · 수평 진동 평균: 같은 시계열의 A95
///           (둘 다 `MeasurementAssembler` 참고. 처리 전 예전 측정은 원시
///           256Hz 시계열에서 낸 값이다)
///
///       값이 비는 것은 그 값을 계산하지 않은 예전 측정뿐이다
///
///       임시값을 만들어 채우지 않는다. 재지 못한 자리는 표에 `—` 로
///       나오고 신호등은 회색이 된다.
///
///       소음 두 값을 서로 다른 데서 가져오는 까닭
///         소음 0 은 값이 아니라 미측정 표시라, 두 값 모두 0 인 표본을
///         빼고 센다. 다만 빼는 자리가 다르다.
///         - 최대는 `MeasurementResult.noiseMax` 를 그대로 읽는다. 그 값이
///           소음 최대 지표의 정본이고, 여기서 다시 계산하지 않는다.
///           다시 세면 0 을 빼는 규칙이 어셈블러와 갈라져 두 값이 어긋난다
///         - 평균은 시계열에서 낸다. 모든 표본이 있어야 나오는 값이라
///           어셈블러가 미리 줄여 둘 수 없다
class ReportMetrics {
  /// 평균 소음 (dBA)
  final ReportMetric noiseAvg;

  /// 최대 소음 (dBA)
  final ReportMetric noiseMax;

  /// 평균 수직 진동 (mg, A95)
  final ReportMetric vertAvg;

  /// 최대 수직 진동 (mg)
  final ReportMetric vertMax;

  /// 평균 수평 진동 (mg, A95)
  final ReportMetric horizAvg;

  /// 최대 수평 진동 (mg). X·Y 중 큰 값
  final ReportMetric horizMax;

  /// 최대 속도 (m/s)
  final ReportMetric maxSpeed;

  /// 운행 거리 (m)
  final ReportMetric travelDistance;

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: ReportMetrics
  /// 목적: 표 여덟 행을 그대로 담는 생성자.
  /// 인자: noiseAvg, noiseMax — 소음 평균 · 최대
  ///       vertAvg, vertMax — 수직 진동 평균 · 최대
  ///       horizAvg, horizMax — 수평 진동 평균 · 최대
  ///       maxSpeed, travelDistance — 최대 속도 · 운행 거리
  const ReportMetrics({
    required this.noiseAvg,
    required this.noiseMax,
    required this.vertAvg,
    required this.vertMax,
    required this.horizAvg,
    required this.horizMax,
    required this.maxSpeed,
    required this.travelDistance,
  });

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: rows
  /// 목적: 여덟 행을 서식에 놓인 차례대로 돌려준다. `ReportPage1.metricRows`
  ///       와 같은 순서라, 그리는 쪽이 둘을 나란히 짝지어 쓸 수 있다.
  /// 반환: 서식 순서대로 늘어놓은 지표 목록
  List<ReportMetric> get rows => <ReportMetric>[
    noiseAvg,
    noiseMax,
    vertAvg,
    vertMax,
    horizAvg,
    horizMax,
    maxSpeed,
    travelDistance,
  ];

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: byKey
  /// 목적: 서식 행 이름으로 지표 하나를 찾는다.
  /// 인자: key — 찾을 행 이름 (`noise_avg` 등)
  /// 반환: 찾은 지표. 그런 이름이 없으면 null
  ReportMetric? byKey(String key) {
    for (final metric in rows) {
      if (metric.key == key) return metric;
    }
    return null;
  }

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 수정: 2026-10-15 16:50:04 · nada
  /// 함수: from
  /// 목적: 측정 결과 하나에서 표 여덟 행을 만든다. 값을 낼 수 있는 항목만
  ///       채우고 나머지는 비운 채로 둔다. 소음 평균은 진동 · 소음 최대와
  ///       같은 운행 구간(`MeasurementResult.travelWindow`)에서 낸다.
  ///       구간을 정하지 못한 결과는 비우고, 구간이 들어가기 전 예전 결과는
  ///       예전처럼 측정 전체에서 낸다.
  /// 인자: result — 변환이 끝난 측정 결과
  /// 반환: 채울 수 있는 만큼 채운 지표 여덟 개
  static ReportMetrics from(MeasurementResult result) {
    // → 로직 이동: _noiseInTravel()
    final noiseRange = _noiseInTravel(result); // 평균 낼 소음, 못 내면 null
    final noiseAverage = noiseRange == null
        ? null
        // → 로직 이동: _withoutWarmupZeros()
        : _average(_withoutWarmupZeros(noiseRange)); // 소음 평균 (dBA)
    final noisePeak = result.noiseMax; // 소음 최대 (dBA). 시계열에서 다시 세지 않는다

    // 수평 최대 행의 적색 칸은 하나뿐이다. X 와 Y 기준이 갈라지면 그 칸으로
    // 둘을 다 보여줄 수 없고, 조용히 X 기준만 나가 틀린 표가 된다. 방어
    // 분기로 받아내는 대신 가정을 여기 박아 둔다 — 갈라지는 날 디버그
    // 실행에서 곧바로 터지고, 릴리스 빌드에서는 지워져 비용이 없다
    assert(
      ReportThresholds.xPtpRedMg == ReportThresholds.yPtpRedMg,
      '수평 행의 적색 기준 칸은 하나뿐이라 X 와 Y 기준이 같아야 한다: '
      'X ${ReportThresholds.xPtpRedMg}, Y ${ReportThresholds.yPtpRedMg}',
    );
    final horizontal = _larger(result.xPtp, result.yPtp); // 수평 중 큰 값 (mg)
    final horizontalA95 = _larger(
      result.xA95,
      result.yA95,
    ); // 수평 A95 중 큰 값 (mg)
    const vibration = ReportMetric.vibrationUnit; // 진동 단위 표기
    const unjudged = ReportThresholds.unjudgedLimit; // 판정 없는 행의 칸 값

    return ReportMetrics(
      noiseAvg: ReportMetric(
        key: 'noise_avg',
        value: noiseAverage,
        unit: 'dBA',
        yellowLimit: ReportThresholds.noiseAvgYellowDba,
        redLimit: ReportThresholds.noiseAvgRedDba,
        // → 로직 이동: ReportThresholds.judge()
        verdict: ReportThresholds.judge(
          noiseAverage,
          ReportThresholds.noiseAvgYellowDba,
          ReportThresholds.noiseAvgRedDba,
        ),
      ),
      noiseMax: ReportMetric(
        key: 'noise_max',
        value: noisePeak,
        unit: 'dBA',
        yellowLimit: ReportThresholds.noiseMaxYellowDba,
        redLimit: ReportThresholds.noiseMaxRedDba,
        // → 로직 이동: ReportThresholds.judge()
        verdict: ReportThresholds.judge(
          noisePeak,
          ReportThresholds.noiseMaxYellowDba,
          ReportThresholds.noiseMaxRedDba,
        ),
      ),
      vertAvg: ReportMetric(
        key: 'vert_avg',
        value: result.zA95,
        unit: vibration,
        suffix: 'A95',
        yellowLimit: ReportThresholds.zA95YellowMg,
        redLimit: ReportThresholds.zA95RedMg,
        // → 로직 이동: ReportThresholds.judge()
        verdict: ReportThresholds.judge(
          result.zA95,
          ReportThresholds.zA95YellowMg,
          ReportThresholds.zA95RedMg,
        ),
      ),
      vertMax: ReportMetric(
        key: 'vert_max',
        value: result.zPtp,
        unit: vibration,
        yellowLimit: ReportThresholds.zPtpYellowMg,
        redLimit: ReportThresholds.zPtpRedMg,
        // → 로직 이동: ReportThresholds.judge()
        verdict: ReportThresholds.judge(
          result.zPtp,
          ReportThresholds.zPtpYellowMg,
          ReportThresholds.zPtpRedMg,
        ),
      ),
      horizAvg: ReportMetric(
        key: 'horiz_avg',
        value: horizontalA95,
        unit: vibration,
        suffix: 'A95',
        yellowLimit: ReportThresholds.horizA95YellowMg,
        redLimit: ReportThresholds.horizA95RedMg,
        // → 로직 이동: ReportThresholds.judgeHorizontal()
        verdict: ReportThresholds.judgeHorizontal(
          result.xA95,
          result.yA95,
          ReportThresholds.horizA95YellowMg,
          ReportThresholds.horizA95RedMg,
        ),
      ),
      horizMax: ReportMetric(
        key: 'horiz_max',
        value: horizontal,
        unit: vibration,
        yellowLimit: ReportThresholds.horizPtpYellowMg,
        redLimit: ReportThresholds.xPtpRedMg,
        // → 로직 이동: ReportThresholds.judgeHorizontal()
        verdict: ReportThresholds.judgeHorizontal(
          result.xPtp,
          result.yPtp,
          ReportThresholds.horizPtpYellowMg,
          ReportThresholds.xPtpRedMg,
        ),
      ),
      maxSpeed: ReportMetric(
        key: 'max_speed',
        value: result.maxSpeed,
        unit: 'm/s',
        yellowLimit: unjudged,
        redLimit: unjudged,
        verdict: ReportVerdict.none,
      ),
      travelDistance: ReportMetric(
        key: 'travel_distance',
        value: result.distance,
        unit: 'm',
        yellowLimit: unjudged,
        redLimit: unjudged,
        verdict: ReportVerdict.none,
      ),
    );
  }

  /// 작성: 2026-10-15 16:50:04 · nada
  /// 함수: _noiseInTravel
  /// 목적: 소음 평균을 낼 표본 범위를 고른다.
  ///       - 운행 구간이 있으면 그 구간
  ///       - 구간을 정하지 못한 결과(`travelWindowFailure`)면 null — 진동 ·
  ///         소음 최대가 비어 있는데 평균만 다른 범위로 내지 않는다
  ///       - 둘 다 없는 예전 결과면 측정 전체
  /// 인자: result — 측정 결과
  /// 반환: 소음 표본 목록 (dBA). 낼 수 없으면 null
  static List<double>? _noiseInTravel(MeasurementResult result) {
    final window = result.travelWindow; // 운행 구간, 없으면 null
    if (window != null) {
      final noise = result.noiseSeries; // 소음 시계열 (dBA)
      // 마이크 권한이 없던 결과는 소음이 비어 있을 수 있어 길이 안으로 자른다
      final from = math.min(window.startIndex, noise.length); // 구간 시작
      final to = math.min(window.endIndex + 1, noise.length); // 구간 끝 (제외)
      return noise.sublist(from, to);
    }
    if (result.travelWindowFailure != null) return null;
    return result.noiseSeries;
  }

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: _withoutWarmupZeros
  /// 목적: 소음 시계열에서 0 인 표본을 걸러낸다. 수집 계층은 소음 창이
  ///       가득 차기 전에 0 을 내보내므로, 측정을 시작한 직후 구간이 0 으로
  ///       온다. 그 구간을 그대로 평균에 넣으면 값이 실제보다 낮게 끌려
  ///       내려간다.
  ///       0 인 표본은 앞쪽에만 몰려 있지만 위치를 세어 잘라내지 않고 값이
  ///       0 인 것을 전부 걸러낸다. 몇 개가 0 으로 오는지는 기기와 측정마다
  ///       다를 수 있어, 개수를 코드에 박으면 그 수와 다를 때 조용히
  ///       어긋나기 때문이다.
  /// 인자: series — 소음 시계열 (dBA)
  /// 반환: 0 을 뺀 표본 목록. 쓸 표본이 없으면 빈 목록
  /// 근거: 표준 — 0 을 거르는 것만으로 충분한 까닭은 수집
  ///       계층(`NoiseCaptureHandler.start()`)이 창이 가득 차기 전에는 값을
  ///       내지 않고 0 을 내보내기 때문이다. 0 다음 표본부터 곧바로 실제
  ///       크기가 오므로 사이에 걸러야 할 중간 구간이 없다.
  static List<double> _withoutWarmupZeros(List<double> series) {
    final kept = <double>[]; // 0 이 아닌 표본만 모을 목록
    for (final value in series) {
      if (value != 0.0) kept.add(value);
    }
    return kept;
  }

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: _average
  /// 목적: 표본의 평균을 낸다.
  /// 인자: series — 평균 낼 표본 목록
  /// 반환: 평균. 표본이 없으면 null — 잴 것이 없는데 0 을 돌려주면 실제로
  ///       0 이 나온 측정과 구분할 수 없다
  static double? _average(List<double> series) {
    if (series.isEmpty) return null;
    var sum = 0.0; // 표본을 더해 나갈 합
    for (final value in series) {
      sum += value;
    }
    return sum / series.length;
  }

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: _larger
  /// 목적: 두 축 값 중 큰 쪽을 고른다. 리포트의 수평 진동 행이 X 와 Y 를
  ///       한 행으로 내보내기 때문이다.
  /// 인자: xPtp — X축 진동 P2P (mg). 없으면 null
  ///       yPtp — Y축 진동 P2P (mg). 없으면 null
  /// 반환: 큰 쪽 값. 한쪽만 있으면 그 값, 둘 다 없으면 null
  static double? _larger(double? xPtp, double? yPtp) {
    if (xPtp == null) return yPtp;
    if (yPtp == null) return xPtp;
    return xPtp > yPtp ? xPtp : yPtp;
  }
}
