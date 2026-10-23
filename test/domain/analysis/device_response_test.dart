import 'package:flutter_test/flutter_test.dart';
import 'package:vibration_checker/domain/analysis/device_response.dart';
import 'package:vibration_checker/domain/config/capture_config.dart';

/// 작성: 2026-10-22 19:00:00 · 박건준
/// 함수: main
/// 목적: 기종 응답 보정 표(`CaptureConfig.deviceResponseByModelPrefix`)와 그
///       찾기 · 표시(`DeviceResponse`)를 시험한다.
///       - 갤럭시 S22(SM-S901…)는 지역판 모두 2차 25Hz 저역이다
///       - S22+ · Ultra · 다른 기종 · 기종을 모르는 기록은 보정 없음이다
///       - 처리 방식 표시가 기종과 필터를 그대로 남긴다
void main() {
  test('갤럭시 S22 는 지역판 모두 2차 25Hz 저역 보정이다', () {
    for (final model in ['SM-S901N', 'SM-S901B', 'SM-S901U', 'SM-S901E']) {
      final filter = DeviceResponse.filterFor(model); // 고른 보정
      expect(filter, isNotNull, reason: model);
      expect(filter!.order, 2, reason: model);
      expect(filter.lowpassHz, 25.0, reason: model);
    }
    expect(CaptureConfig.deviceResponseByModelPrefix.keys, ['SM-S901']);
  });

  test('표에 없는 기종 · 기종을 모르는 기록은 보정하지 않는다', () {
    for (final model in <String?>['SM-S906N', 'SM-S908N', 'SM-F976N', null]) {
      expect(DeviceResponse.filterFor(model), isNull, reason: '$model');
      expect(DeviceResponse.compensationLabel(model), DeviceResponse.noneLabel);
    }
  });

  test('처리 방식 표시에 기종과 필터를 남긴다', () {
    expect(
      DeviceResponse.methodLabel('SM-S901N'),
      'devcomp(SM-S901N,lp25.0bw2zp)',
    );
    expect(DeviceResponse.methodLabel('SM-A536N'), 'devcomp(SM-A536N,none)');
    expect(DeviceResponse.methodLabel(null), 'devcomp(unknown,none)');
  });
}
