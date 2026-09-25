import 'package:intl/intl.dart';

import 'package:vibration_checker/domain/report/report_layout.dart';
import 'package:vibration_checker/domain/report/report_metrics.dart';
import 'package:vibration_checker/domain/report/report_thresholds.dart';
import 'package:vibration_checker/model/measurement_result.dart';

/// 작성: 2026-09-26 09:30:00 · nada
/// 클래스: ReportGenerator
/// 목적: 측정 결과를 바탕으로 이메일 본문에 들어갈 요약 텍스트를 만든다.
///       리포트 PDF 를 열지 않고도 받는 사람이 결과를 알 수 있게 하는 것이
///       목적이라, PDF 1쪽 표와 같은 여덟 지표를 같은 차례로 적는다.
///
///       지표를 여기서 계산하지 않는다. `ReportMetrics` 가 낸 값을 받아
///       글로 옮기기만 한다 — 같은 값을 두 곳에서 계산하면 표와 메일이
///       서로 다른 숫자를 말하게 된다.
class ReportGenerator {
  /// 작성: 2026-09-26 09:30:00 · nada
  /// 변수: rowLabels
  /// 목적: 지표 행 이름을 우리말 이름으로 옮긴 표. 서식에는 이 이름이
  ///       인쇄돼 있어 PDF 를 그릴 때는 필요 없지만, 메일 본문에는 직접
  ///       적어야 한다.
  /// 근거: 인용 — 원본 리포트 `docs/reference/sample_evimp.pdf` 1쪽
  ///       Performance Metrics 표에 인쇄된 이름을 그대로 옮겼다
  static const Map<String, String> rowLabels = <String, String>{
    'noise_avg': '소음, 평균',
    'noise_max': '소음, 최대',
    'vert_avg': '수직진동, 평균',
    'vert_max': '수직진동, 최대',
    'horiz_avg': '수평진동, 평균',
    'horiz_max': '수평진동, 최대',
    'max_speed': '최대 속도',
    'travel_distance': '운행 거리',
  };

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 변수: pendingFilterRows
  /// 목적: 진동 필터가 확정되지 않아 아직 값을 못 내는 행들.
  /// 근거: 미정 — 진동 필터 파라미터가 정해지면 이 네 행에 값이 들어오고
  ///       이 목록은 비워야 한다. `MeasurementResult` 의 P2P 네 값이 지금
  ///       null 인 것과 같은 이유다
  static const List<String> pendingFilterRows = <String>[
    'vert_avg',
    'vert_max',
    'horiz_avg',
    'horiz_max',
  ];

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 변수: noiseRows
  /// 목적: 소음에서 오는 행들. 값이 없을 때 진동과 다른 사유를 적으려고
  ///       따로 둔다.
  static const List<String> noiseRows = <String>['noise_avg', 'noise_max'];

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: generateSummaryText
  /// 목적: 측정 결과를 받아, 현장 엔지니어가 메일 본문에 그대로 쓸 수 있는
  ///       우리말 요약을 만든다. 머리말(제번 · 현장 · 일시 · 운행 구간)과
  ///       지표 여덟 줄, 그리고 값이 빠진 까닭을 적는다.
  /// 인자: result — 측정 결과 객체
  /// 반환: 이메일 본문용 요약 텍스트
  static String generateSummaryText(MeasurementResult result) {
    // → 로직 이동: ReportMetrics.from()
    final metrics = ReportMetrics.from(result); // 표에 올릴 지표 여덟 개
    final stamp = DateFormat(
      ReportLayout.datetimePattern,
    ).format(result.dateTime); // 머리말에 쓸 측정 일시

    final lines = <String>[
      'OTIS 승강기 진동·소음 측정 결과입니다.',
      '',
      '제번: ${result.jobNo}',
      '현장: ${result.siteName}',
      '측정 일시: $stamp',
      '운행: ${result.direction} '
          '(${result.bottomFloor}층 → ${result.topFloor}층)',
    ]; // 쌓아 갈 본문 줄

    final model = result.model; // 기종. 입력되지 않았으면 null
    if (model != null && model.isNotEmpty) {
      lines.add('기종: $model');
    }

    lines
      ..add('')
      ..add('[측정 결과]');
    for (final metric in metrics.rows) {
      // → 로직 이동: _formatRow()
      lines.add(_formatRow(metric));
    }

    // → 로직 이동: _notes()
    final notes = _notes(metrics); // 값이 빠진 까닭을 적은 줄들
    if (notes.isNotEmpty) {
      lines
        ..add('')
        ..addAll(notes);
    }
    return lines.join('\n');
  }

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: _formatRow
  /// 목적: 지표 한 줄을 만든다. 값이 있으면 표에 찍히는 것과 같은 문자열을
  ///       쓰고, 기준을 넘었으면 그 사실을 뒤에 붙인다. 값이 없으면 왜
  ///       없는지를 값 자리에 적는다 — `—` 만 적으면 못 잰 것인지 기준이
  ///       없는 것인지 읽는 사람이 구분하지 못한다.
  /// 인자: metric — 옮겨 적을 지표 한 행
  /// 반환: 본문에 넣을 한 줄
  static String _formatRow(ReportMetric metric) {
    final label = rowLabels[metric.key] ?? metric.key; // 우리말 행 이름
    if (metric.value == null) {
      // → 로직 이동: _missingReason()
      return '- $label: ${_missingReason(metric.key)}';
    }
    final buffer = StringBuffer('- $label: ${metric.display}'); // 쌓아 갈 한 줄
    if (metric.verdict == ReportVerdict.red) {
      buffer.write(' ← 기준 ${metric.redDisplay}${metric.unit} 초과');
    }
    return buffer.toString();
  }

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: _missingReason
  /// 목적: 값이 없는 행의 값 자리에 적을 사유를 고른다.
  /// 인자: key — 지표 행 이름
  /// 반환: 값 자리에 적을 문구
  static String _missingReason(String key) {
    if (pendingFilterRows.contains(key)) return '—(필터 확정 대기)';
    if (noiseRows.contains(key)) return '—(소음 미측정)';
    return '—(측정값 없음)';
  }

  /// 작성: 2026-09-26 09:30:00 · nada
  /// 함수: _notes
  /// 목적: 본문 끝에 붙일 안내 줄을 만든다. 값이 빠진 행이 있을 때만
  ///       그 까닭을 한 번씩 적는다 — 여덟 줄마다 되풀이하면 읽기 어렵다.
  /// 인자: metrics — 산출된 지표 여덟 개
  /// 반환: 안내 줄 목록. 빠진 행이 없으면 빈 목록
  static List<String> _notes(ReportMetrics metrics) {
    final missing = metrics.rows
        .where((metric) => metric.value == null)
        .map((metric) => metric.key)
        .toSet(); // 값이 빠진 행 이름들
    final notes = <String>[]; // 쌓아 갈 안내 줄

    if (missing.any(pendingFilterRows.contains)) {
      notes.add(
        '※ 진동 네 항목은 진동 필터가 확정되지 않아 아직 값을 내지 않습니다. '
        '값을 지어내지 않으려고 비워 둔 것입니다.',
      );
    }
    if (missing.any(noiseRows.contains)) {
      notes.add(
        '※ 소음은 측정된 값이 없습니다. 마이크 권한이 꺼져 있었는지 확인해 '
        '주세요.',
      );
    }
    return notes;
  }
}
