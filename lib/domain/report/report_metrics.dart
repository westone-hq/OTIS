import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-15 21:14:33 · nada
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
  /// 서식에서 이 행을 부르는 이름. `ReportPage1.metricRows` 의 `key` 와 같다
  final String key;

  /// 지표 값. 아직 낼 수 없으면 null
  final double? value;

  /// 값 뒤에 붙는 단위 (`dBA`, `mg`, `m/s`, `m`)
  final String unit;

  /// 단위 뒤에 한 칸 띄고 붙는 꼬리표. 지금은 평균 진동의 `A95` 뿐이고,
  /// 없으면 빈 문자열
  final String suffix;

  /// 값 뒤 괄호 안에 붙는 내역. 수평 진동 행의 `X 8.2 / Y 12.9` 처럼 한
  /// 행에 두 축을 함께 보고할 때 쓴다. 없으면 빈 문자열
  final String detail;

  /// 적색 기준치. 기준이 없는 항목이면 null
  final double? redLimit;

  /// 신호등 색. `ReportThresholds` 가 정한다
  final ReportVerdict verdict;

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: ReportMetric
  /// 목적: 지표 한 행의 값과 표시 정보를 그대로 담는 생성자.
  /// 인자: key — 서식 행 이름
  ///       value — 지표 값. 없으면 null
  ///       unit — 단위
  ///       verdict — 신호등 색
  ///       suffix — 꼬리표. 기본 빈 문자열
  ///       detail — 괄호 안 내역. 기본 빈 문자열
  ///       redLimit — 적색 기준치. 기준이 없으면 null
  const ReportMetric({
    required this.key,
    required this.value,
    required this.unit,
    required this.verdict,
    this.suffix = '',
    this.detail = '',
    this.redLimit,
  });

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: display
  /// 목적: 표의 값 칸에 그대로 찍을 문자열을 만든다. 값이 100 이상이면
  ///       소수점을 떼고, 그보다 작으면 한 자리만 남긴다. 꼬리표와 내역이
  ///       있으면 뒤에 붙인다.
  /// 반환: 값 칸 문자열. 값이 없으면 `—`
  String get display {
    final amount = value; // 지역으로 옮겨야 null 검사가 이어진다
    if (amount == null) return '—';
    final digits = amount.abs() >= 100
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(1); // 자릿수를 맞춘 숫자 부분
    final buffer = StringBuffer('$digits$unit'); // 쌓아 갈 문자열
    if (suffix.isNotEmpty) buffer.write(' $suffix');
    if (detail.isNotEmpty) buffer.write('  ($detail)');
    return buffer.toString();
  }

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: redDisplay
  /// 목적: 표의 적색 기준 칸에 찍을 문자열을 만든다. 기준이 없는 행은
  ///       칸을 비운다.
  /// 반환: 기준치 문자열. 기준이 없으면 빈 문자열
  String get redDisplay {
    final limit = redLimit; // 지역으로 옮겨야 null 검사가 이어진다
    if (limit == null) return '';
    return limit == limit.roundToDouble()
        ? limit.toStringAsFixed(0)
        : limit.toString();
  }
}

/// 작성: 2026-09-15 21:14:33 · nada
/// 클래스: ReportMetrics
/// 목적: 측정 결과 하나에서 Performance Metrics 표 여덟 행을 만든다.
///       임계값은 여기 적지 않고 `ReportThresholds` 에서 가져온다.
///
///       지금 값이 나오는 것
///         - 최대 속도 · 운행 거리
///
///       지금 비는 것과 그 이유는 서로 다르다
///         - 소음 평균 · 최대: 앱에 소음 수집 경로가 없어 `noiseSeries` 와
///           `noiseMax` 가 둘 다 비어 있다. 수집이 붙어 그 둘이 채워지면
///           이 파일을 고치지 않고도 값이 나온다. 통로를 열어 둔 것이지
///           값을 지어내는 것이 아니다
///         - 수직 · 수평 진동 네 개: 진동 필터 파라미터가 확정되지 않아
///           `MeasurementResult` 의 P2P 네 값이 아직 null 이다. 필터가
///           정해져 그 값이 채워지면 역시 이 파일을 고치지 않고 나온다
///
///       어느 쪽이든 임시값을 만들어 채우지 않는다. 재지 못한 자리는 표에
///       `—` 로 나오고 신호등은 회색이 된다.
///
///       소음 두 값을 서로 다른 데서 가져오는 까닭
///         소음 갱신율이 약 8Hz 로 진동 256Hz 보다 훨씬 느려, 격자에 맞춘
///         시계열은 표본 사이에서 올라갔다 내려온 봉우리를 잃는다. 센서가
///         실제로 본 최대는 `max(noiseSeries)` 보다 클 수 있다.
///         - 최대는 `MeasurementResult.noiseMax` 를 그대로 읽는다. 그 값이
///           소음 최대 지표의 정본이고, 시계열에서 다시 계산하지 않는다
///         - 평균은 시계열에서 낸다. 평균은 모든 표본이 있어야 나오고,
///           봉우리 손실이 평균을 크게 흔들지 않는다
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
  /// 함수: from
  /// 목적: 측정 결과 하나에서 표 여덟 행을 만든다. 값을 낼 수 있는 항목만
  ///       채우고 나머지는 비운 채로 둔다.
  /// 인자: result — 변환이 끝난 측정 결과
  /// 반환: 채울 수 있는 만큼 채운 지표 여덟 개
  static ReportMetrics from(MeasurementResult result) {
    // → 로직 이동: _withoutWarmupZeros()
    final noise = _withoutWarmupZeros(result.noiseSeries); // 쓸 수 있는 소음 표본
    final noiseAverage = _average(noise); // 소음 평균 (dBA). 표본이 없으면 null
    final noisePeak = result.noiseMax; // 소음 최대 (dBA). 시계열에서 다시 세지 않는다

    // 수평 행은 적색 기준을 칸 하나에만 찍는다. X 와 Y 기준이 갈라지면
    // 그 칸으로는 둘을 다 보여줄 수 없고, 조용히 X 기준만 나가 틀린 표가
    // 된다. 방어 분기로 받아내는 대신 가정을 여기 박아 둔다 — 갈라지는
    // 날 디버그 실행에서 곧바로 터지고, 릴리스 빌드에서는 지워져 비용이
    // 없다
    assert(
      ReportThresholds.xPtpRedMg == ReportThresholds.yPtpRedMg,
      '수평 행의 적색 기준 칸은 하나뿐이라 X 와 Y 기준이 같아야 한다: '
      'X ${ReportThresholds.xPtpRedMg}, Y ${ReportThresholds.yPtpRedMg}',
    );
    final horizontal = _larger(result.xPtp, result.yPtp); // 수평 중 큰 값 (mg)

    return ReportMetrics(
      noiseAvg: ReportMetric(
        key: 'noise_avg',
        value: noiseAverage,
        unit: 'dBA',
        verdict: ReportThresholds.judge(noiseAverage, null),
      ),
      noiseMax: ReportMetric(
        key: 'noise_max',
        value: noisePeak,
        unit: 'dBA',
        redLimit: ReportThresholds.noiseMaxRedDba,
        verdict: ReportThresholds.judge(
          noisePeak,
          ReportThresholds.noiseMaxRedDba,
        ),
      ),
      vertAvg: ReportMetric(
        key: 'vert_avg',
        value: null,
        unit: 'mg',
        suffix: 'A95',
        verdict: ReportThresholds.judge(null, null),
      ),
      vertMax: ReportMetric(
        key: 'vert_max',
        value: result.zPtp,
        unit: 'mg',
        redLimit: ReportThresholds.zPtpRedMg,
        verdict: ReportThresholds.judge(
          result.zPtp,
          ReportThresholds.zPtpRedMg,
        ),
      ),
      horizAvg: ReportMetric(
        key: 'horiz_avg',
        value: null,
        unit: 'mg',
        suffix: 'A95',
        verdict: ReportThresholds.judge(null, null),
      ),
      horizMax: ReportMetric(
        key: 'horiz_max',
        value: horizontal,
        unit: 'mg',
        detail: _horizontalDetail(result.xPtp, result.yPtp),
        redLimit: ReportThresholds.xPtpRedMg,
        // → 로직 이동: ReportThresholds.judgeHorizontal()
        verdict: ReportThresholds.judgeHorizontal(result.xPtp, result.yPtp),
      ),
      maxSpeed: ReportMetric(
        key: 'max_speed',
        value: result.maxSpeed,
        unit: 'm/s',
        verdict: ReportThresholds.judge(result.maxSpeed, null),
      ),
      travelDistance: ReportMetric(
        key: 'travel_distance',
        value: result.distance,
        unit: 'm',
        verdict: ReportThresholds.judge(result.distance, null),
      ),
    );
  }

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: _withoutWarmupZeros
  /// 목적: 소음 시계열에서 0 인 표본을 걸러낸다. 소음 센서는 측정을 시작한
  ///       직후 잠깐 0 을 내보내고, 그 구간을 그대로 평균에 넣으면 값이
  ///       실제보다 낮게 끌려 내려간다.
  ///       0 인 표본은 앞쪽에만 몰려 있지만 위치를 세어 잘라내지 않고 값이
  ///       0 인 것을 전부 걸러낸다. 몇 개가 0 으로 오는지는 기기와 측정마다
  ///       다를 수 있어, 개수를 코드에 박으면 그 수와 다를 때 조용히
  ///       어긋나기 때문이다.
  /// 인자: series — 소음 시계열 (dBA)
  /// 반환: 0 을 뺀 표본 목록. 쓸 표본이 없으면 빈 목록
  /// 근거: 측정 — `test/fixtures/app_measurement.xlsx` 의 `2_분석데이터`
  ///       시트에서 소음 열 앞 38개 표본이 0 이고, 39번째부터 44.8dBA 로
  ///       올라온다
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

  /// 작성: 2026-09-15 21:14:33 · nada
  /// 함수: _horizontalDetail
  /// 목적: 수평 진동 행의 값 뒤에 붙일 축별 내역을 만든다. 행에는 큰 쪽
  ///       값만 싣지만, 요구사항이 X 와 Y 를 각각 보고하도록 정하고 있어
  ///       어느 축이 얼마였는지를 함께 적는다. 한쪽만 싣고 끝내면 안 된다.
  /// 인자: xPtp — X축 진동 P2P (mg). 없으면 null
  ///       yPtp — Y축 진동 P2P (mg). 없으면 null
  /// 반환: `X 8.2 / Y 12.9` 형태의 문자열. 못 잰 축은 `—` 로 적는다
  static String _horizontalDetail(double? xPtp, double? yPtp) {
    final x = xPtp == null ? '—' : xPtp.toStringAsFixed(1); // X축 표기
    final y = yPtp == null ? '—' : yPtp.toStringAsFixed(1); // Y축 표기
    return 'X $x / Y $y';
  }
}
