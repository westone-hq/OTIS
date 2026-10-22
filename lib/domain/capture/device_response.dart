import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/signal_conditioner.dart';

/// 작성: 2026-10-22 19:00:00 · nada
/// 클래스: DeviceResponse
/// 목적: 기종 응답 보정. 휴대폰 기종마다 몸체 · 케이스 · 센서 특성이 달라
///       같은 진동을 다른 크기로 받는다. 기준 폰(오티스폰)보다 높은
///       주파수를 크게 받는 기종은 가중한 수직(Z) 진동에 저역을 양방향으로
///       걸어 맞춘다. 표는 `CaptureConfig.deviceResponseByModelPrefix` 에
///       있고, 표에 없는 기종 · 기종을 모르는 기록은 보정하지 않는다.
///       진동 필터가 아니라 기종 보정이라 오티스폰 기록에는 걸지 않는다.
abstract final class DeviceResponse {
  /// 작성: 2026-10-22 19:00:00 · nada
  /// 변수: noneLabel
  /// 목적: 보정하지 않았음을 결과 파일에 남기는 표시. 결과 화면 · 메일은 이
  ///       값을 보고 "미보정 기종" 을 알린다.
  static const String noneLabel = 'none';

  /// 작성: 2026-10-22 19:00:00 · nada
  /// 함수: filterFor
  /// 목적: 기종 이름에 맞는 보정 필터를 찾는다. 열쇠 글자로 시작하는
  ///       기종이면 그 필터다 — 같은 모델의 지역판(SM-S901N · SM-S901B 등)은
  ///       몸체가 같아 한 줄로 묶는다.
  /// 인자: model — 기종 이름(`Build.MODEL`). 모르면 null
  /// 반환: 보정 필터. 표에 없거나 기종을 모르면 null
  static DeviceResponseFilter? filterFor(String? model) {
    if (model == null) return null;
    for (final entry in CaptureConfig.deviceResponseByModelPrefix.entries) {
      if (model.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  /// 작성: 2026-10-22 19:00:00 · nada
  /// 함수: compensationLabel
  /// 목적: 결과 파일(`deviceCompensation`)에 남길 보정 표시.
  /// 인자: model — 기종 이름. 모르면 null
  /// 반환: 필터 표시(예: "lp25.0bw2zp"), 보정하지 않으면 `noneLabel`
  static String compensationLabel(String? model) =>
      // → 로직 이동: filterFor()
      filterFor(model)?.label ?? noneLabel;

  /// 작성: 2026-10-22 19:00:00 · nada
  /// 함수: methodLabel
  /// 목적: 처리 방식(result.json `signalConditioning`)에 남길 문자열. 가중
  ///       표시 뒤에 붙인다. 2026-10-21 2차 ~ 10-22 결과는 이 자리에
  ///       `zlp(20.0bw4zp)`(모든 기록에 건 수직 20Hz 저역)가 있다.
  ///       - `devcomp(기종,필터)` — 그 기종 보정을 걸었다
  ///       - `devcomp(기종,none)` — 표에 없는 기종이라 걸지 않았다
  ///       - `devcomp(unknown,none)` — 기종을 몰라 걸지 않았다
  /// 인자: model — 기종 이름. 모르면 null
  /// 반환: 처리 방식 문자열
  static String methodLabel(String? model) =>
      // → 로직 이동: compensationLabel()
      'devcomp(${model ?? 'unknown'},${compensationLabel(model)})';

  /// 작성: 2026-10-22 19:00:00 · nada
  /// 함수: apply
  /// 목적: 가중한 수직 진동에 보정 필터를 양방향(영위상)으로 건다. 표의
  ///       수직 최대 · Jptp · A95 와 2쪽 수직 차트 · 표시점이 모두 이
  ///       시계열에서 나온다.
  /// 인자: filter — 보정 필터
  ///       series — 가중한 Z (mg)
  ///       sampleRate — 표본 속도 (Hz). 차단의 두 배보다 크다
  ///       (`MeasurementAssembler.assemble()` 이 먼저 본다)
  /// 반환: 보정한 Z (mg, 같은 길이)
  static List<double> apply(
    DeviceResponseFilter filter,
    List<double> series,
    double sampleRate,
  ) =>
      // → 로직 이동: Butterworth.filtfilt()
      Butterworth.filtfilt(
        // → 로직 이동: Butterworth.lowpass()
        Butterworth.lowpass(
          order: filter.order,
          cutoffHz: filter.lowpassHz,
          sampleRateHz: sampleRate,
        ),
        series,
      );
}
