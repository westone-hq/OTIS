import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/adapter/measurement_recorder.dart';
import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';
import 'package:vibration_checker/ui/features/measure/record_failure_message.dart';

/// 작성: 2026-10-07 02:33:18 · nada
/// 함수: main
/// 목적: 신호 처리 실패의 원인 종류에 따라 측정 화면 실패 문구가 갈리는지
///       시험한다. 최소 측정 길이는 앱과 같은 기본 설정에서 가져온다.
void main() {
  final minimumRecordMs = // 기본 설정의 최소 측정 길이 (밀리초)
      const CaptureConfig().minimumRecordMs;

  test('측정 시간이 모자란 실패는 사유 대신 2초 이상 측정하라고 안내한다', () {
    final message = recordFailureMessage(
      const RecordOutcome.conditioningFailed(
        ConditioningFailure.gridTooShort,
        '격자가 255행으로 기준선 구간 256행(1000ms)보다 짧다',
      ),
      minimumRecordMs: minimumRecordMs,
    ); // 대화상자 문구

    expect(message, '측정 시간이 너무 짧습니다.\n2초 이상 측정해 주세요.');
    expect(message, isNot(contains('255행')));
  });

  test('설정 오류로 인한 처리 실패는 기존 문구에 사유를 붙인다', () {
    final message = recordFailureMessage(
      const RecordOutcome.conditioningFailed(
        ConditioningFailure.invalidConfig,
        'Invalid argument (lowpassCutoffHz)',
      ),
      minimumRecordMs: minimumRecordMs,
    ); // 대화상자 문구

    expect(message, '측정값 처리에 실패했습니다.\n사유: Invalid argument (lowpassCutoffHz)');
  });
}
