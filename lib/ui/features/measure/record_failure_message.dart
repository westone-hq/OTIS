import 'package:vibration_checker/adapter/measurement_recorder.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';

/// 작성: 2026-10-04 13:33:18 · nada
/// 함수: recordFailureMessage
/// 목적: 저장 실패 종류를 사용자에게 보여줄 안내 문구로 바꾼다. 측정
///       화면(measuring_screen.dart)이 실패 대화상자에 넣는다. 화면 상태에
///       기대지 않는 순수 함수라 화면을 띄우지 않고 시험한다.
///       신호 처리 실패 중 측정 시간이 모자란 경우는 사유 대신 몇 초 이상
///       재야 하는지 알려 준다. 그 길이는 부르는 쪽이 수집 설정
///       (`CaptureConfig.minimumRecordMs`)에서 넘겨, 화면에 숫자를 따로
///       두지 않는다.
/// 인자: outcome — 실패한 저장 결과
///       minimumRecordMs — 지표를 낼 수 있는 가장 짧은 측정 길이 (밀리초)
/// 반환: 대화상자에 넣을 문구
String recordFailureMessage(
  RecordOutcome outcome, {
  required int minimumRecordMs,
}) {
  // 성공 결과로는 부르지 않는다 — 측정 화면이 실패일 때만 부른다
  assert(!outcome.isSuccess, '성공한 저장 결과에는 실패 문구가 없다');
  final detail = outcome.detail; // 덧붙일 원인 문구, 없으면 null
  final minimumSec = minimumRecordMs % 1000 == 0
      ? '${minimumRecordMs ~/ 1000}'
      : (minimumRecordMs / 1000).toStringAsFixed(1); // 문구에 넣을 초
  return switch (outcome.failure!) {
    RecordFailure.siteMissing => '현장 정보가 없습니다. 홈에서 다시 시작해 주세요.',
    RecordFailure.noSamples =>
      '센서 데이터가 수집되지 않았습니다.\n기기 지원 여부를 확인한 뒤 다시 측정해 주세요.',
    RecordFailure.gridFailed => '측정 파일 생성에 실패했습니다.\n사유: $detail',
    RecordFailure.conditioningFailed =>
      outcome.conditioningCause == ConditioningFailure.gridTooShort
          ? '측정 시간이 너무 짧습니다.\n$minimumSec초 이상 측정해 주세요.'
          : '측정값 처리에 실패했습니다.\n사유: $detail',
    RecordFailure.assembleFailed => '측정 결과 변환에 실패했습니다.\n사유: $detail',
    RecordFailure.ioError => '측정 저장 중 오류가 발생했습니다.\n$detail',
  };
}
