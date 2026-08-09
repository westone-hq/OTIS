import 'dart:math' as math;

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

/// 목적: 격자 한 행의 진동값을 담는다. 시각은 담지 않는다.
///       출력 파일에 시간 열이 없으므로 시각은 행 번호로만 결정된다
///       (t = t0Ns + 행번호 x gridIntervalNs). 시각을 행마다 들고 다니면
///       등간격이 아닌 값이 섞여 들어갈 여지가 생긴다.
class GridSample {
  const GridSample({required this.xMg, required this.yMg, required this.zMg});

  /// X축 motion (mg)
  final double xMg;

  /// Y축 motion (mg)
  final double yMg;

  /// Z축 motion (mg)
  final double zMg;
}

/// 목적: 격자 환산 결과와 환산 과정에서 폐기·이상으로 집계된 수치를 함께 담는다.
///       폐기 건수를 결과에 실어 보내는 것은 "폐기하고 집계, 0값 대체 금지"(RD-4) 때문이다.
class GridResampleResult {
  const GridResampleResult({
    required this.samples,
    required this.t0Ns,
    required this.gridIntervalNs,
    required this.rawUsedCount,
    required this.gravityUsedCount,
    required this.droppedZeroCount,
    required this.droppedBackwardCount,
    required this.droppedLinearCount,
    required this.headTrimmedRows,
    required this.tailTrimmedRows,
    required this.rawMaxSpanNs,
    required this.gravityMaxSpanNs,
    required this.degenerateSpanCount,
    this.failureReason,
  });

  /// 목적: 환산이 불가능한 조건에서 빈 결과와 사유만 담아 반환한다.
  factory GridResampleResult.failure(
    String reason, {
    required int gridIntervalNs,
    required int rawUsedCount,
    required int gravityUsedCount,
    required int droppedZeroCount,
    required int droppedBackwardCount,
    required int droppedLinearCount,
  }) {
    return GridResampleResult(
      samples: const <GridSample>[],
      t0Ns: 0,
      gridIntervalNs: gridIntervalNs,
      rawUsedCount: rawUsedCount,
      gravityUsedCount: gravityUsedCount,
      droppedZeroCount: droppedZeroCount,
      droppedBackwardCount: droppedBackwardCount,
      droppedLinearCount: droppedLinearCount,
      headTrimmedRows: 0,
      tailTrimmedRows: 0,
      rawMaxSpanNs: 0,
      gravityMaxSpanNs: 0,
      degenerateSpanCount: 0,
      failureReason: reason,
    );
  }

  /// 격자 행 목록 (등간격 보장)
  final List<GridSample> samples;

  /// 격자 0번 행의 시각 (나노초). raw·gravity 가 둘 다 확보된 첫 시각
  final int t0Ns;

  /// 격자 간격 (나노초)
  final int gridIntervalNs;

  /// 환산에 사용된 raw 유효 이벤트 수
  final int rawUsedCount;

  /// 환산에 사용된 gravity 유효 이벤트 수
  final int gravityUsedCount;

  /// 전 축이 정확히 0이어서 폐기한 이벤트 수 (센서 초기화 직후 발생)
  final int droppedZeroCount;

  /// 타임스탬프가 앞으로 가지 않아 폐기한 이벤트 수
  final int droppedBackwardCount;

  /// linear 종류여서 버린 이벤트 수 (RD-6)
  final int droppedLinearCount;

  /// 시작단에서 생성하지 않은 행 수 (두 센서 중 늦게 시작한 쪽 때문에 잘린 분량)
  final int headTrimmedRows;

  /// 끝단에서 생성하지 않은 행 수 (두 센서 중 먼저 끝난 쪽 때문에 잘린 분량)
  final int tailTrimmedRows;

  /// raw 이벤트 사이 최대 간격 (나노초). 결손 판단용 참고값
  final int rawMaxSpanNs;

  /// gravity 이벤트 사이 최대 간격 (나노초). 결손 판단용 참고값
  final int gravityMaxSpanNs;

  /// 앞뒤 이벤트 시각이 같아 비례 계산이 불가능했던 횟수
  final int degenerateSpanCount;

  /// 환산 실패 사유. 성공 시 null
  final String? failureReason;

  /// 목적: 환산이 성공했는지 알려준다.
  bool get isSuccess => failureReason == null && samples.isNotEmpty;

  /// 목적: 격자 행 수를 반환한다.
  int get rowCount => samples.length;

  /// 목적: 지정 행의 시각을 계산한다. 저장하지 않고 매번 계산한다.
  /// 인자: index — 행 번호 (0부터)
  /// 반환: 해당 행의 시각 (나노초)
  /// 식: t(n) = t0Ns + n x gridIntervalNs
  int tsNsAt(int index) => t0Ns + index * gridIntervalNs;

  /// 목적: 격자가 덮는 총 시간을 초 단위로 반환한다.
  /// 식: (행 수 - 1) x 격자간격 / 1e9
  double get durationSec =>
      rowCount < 2 ? 0.0 : (rowCount - 1) * gridIntervalNs / 1000000000.0;
}

/// 목적: 수신한 원본 이벤트를 모아두었다가, 측정 종료 시 등간격 격자로 환산한다.
///       raw 와 gravity 를 각각 따로 격자에 맞춘 뒤 빼서 motion 을 만든다.
///
///       설계 근거가 되는 세 결정:
///       - 격자 시각은 센서 시각에서 유도하지 않고 t0 에서 일정량을 더해서만 정한다.
///         출력 파일에 시간 열이 없어 등간격이 필수이기 때문이다.
///       - raw 와 gravity 를 각각 환산한 뒤 뺀다. 직전 gravity 값을 재사용하면
///         결과에 계단 성분이 남고 이후 환산으로 제거되지 않는다.
///       - 앞뒤를 감싸는 실측값이 없는 격자점은 만들지 않는다. 직전 값 복사는
///         파일에서 실측과 구분할 수 없게 만든다.
class GridResampler {
  GridResampler({required this.config});

  /// 격자 간격과 목표 주기를 담은 수집 설정
  final CaptureConfig config;

  final List<NativeEvent> _raw = <NativeEvent>[];
  final List<NativeEvent> _gravity = <NativeEvent>[];

  int _droppedZeroCount = 0;
  int _droppedBackwardCount = 0;
  int _droppedLinearCount = 0;

  /// 목적: 누적된 raw 이벤트 수를 반환한다 (진행 표시용).
  int get rawCount => _raw.length;

  /// 목적: 누적된 gravity 이벤트 수를 반환한다 (진행 표시용).
  int get gravityCount => _gravity.length;

  /// 목적: 네이티브에서 올라온 원본 이벤트 1건을 종류별로 누적한다.
  ///       가공은 하지 않고, 환산에 쓸 수 없는 것만 걸러 집계한다.
  /// 인자: event — 네이티브에서 도착한 원본 이벤트
  /// 반환: 없음. 폐기 시 해당 집계값만 증가한다
  void onEvent(NativeEvent event) {
    switch (event.type) {
      case NativeEventType.linear:
        // OS 가 계산한 linear 는 사용하지 않는다 (RD-6).
        _droppedLinearCount++;
        return;
      case NativeEventType.accel:
        _accept(_raw, event);
        return;
      case NativeEventType.gravity:
        _accept(_gravity, event);
        return;
    }
  }

  /// 목적: 다음 측정을 위해 누적분과 집계값을 모두 비운다.
  void reset() {
    _raw.clear();
    _gravity.clear();
    _droppedZeroCount = 0;
    _droppedBackwardCount = 0;
    _droppedLinearCount = 0;
  }

  /// 목적: 한 종류의 목록에 이벤트를 넣되, 환산에 쓸 수 없는 두 경우를 걸러낸다.
  /// 인자: target — 누적할 목록
  ///       event — 검사할 이벤트
  /// 반환: 없음
  /// 근거: 측정 — 측정 시작 직후 센서 버퍼가 채워지기 전 전 축 0 이 올라오는 사례 확인.
  ///       이 값을 그대로 쓰면 motion = 0 - 1000 = -1000 mg 의 없는 진동이 만들어진다
  void _accept(List<NativeEvent> target, NativeEvent event) {
    if (event.xMg == 0.0 && event.yMg == 0.0 && event.zMg == 0.0) {
      _droppedZeroCount++;
      return;
    }
    if (target.isNotEmpty && event.tsUs <= target.last.tsUs) {
      _droppedBackwardCount++;
      return;
    }
    target.add(event);
  }

  /// 목적: 누적된 raw·gravity 를 등간격 격자로 환산하고 motion 을 계산한다.
  /// 인자: 없음 (누적분을 사용)
  /// 반환: 격자 행 목록과 집계값을 담은 결과. 환산 불가 시 사유가 담긴 실패 결과
  /// 식: t(n) = t0Ns + n x gridIntervalNs
  ///     motion(n) = raw_격자(n) - gravity_격자(n)
  GridResampleResult resample() {
    final intervalNs = config.idealIntervalNs;

    GridResampleResult fail(String reason) => GridResampleResult.failure(
      reason,
      gridIntervalNs: intervalNs,
      rawUsedCount: _raw.length,
      gravityUsedCount: _gravity.length,
      droppedZeroCount: _droppedZeroCount,
      droppedBackwardCount: _droppedBackwardCount,
      droppedLinearCount: _droppedLinearCount,
    );

    if (!config.isGridExact) {
      return fail(
        '목표 주기 ${config.targetSampleRateHz} Hz 는 나노초 정수 간격으로 '
        '나뉘지 않아 등간격 격자를 만들 수 없다',
      );
    }
    if (_raw.length < 2) {
      return fail('raw 유효 샘플이 ${_raw.length}개로 2개 미만이다');
    }
    if (_gravity.length < 2) {
      return fail('gravity 유효 샘플이 ${_gravity.length}개로 2개 미만이다');
    }

    // 격자 범위: 두 채널이 모두 값을 갖는 구간으로만 제한한다.
    // 이 두 줄이 시작단·끝단 예외를 동시에 없앤다.
    final rawFirstNs = _raw.first.tsUs * 1000;
    final rawLastNs = _raw.last.tsUs * 1000;
    final gravityFirstNs = _gravity.first.tsUs * 1000;
    final gravityLastNs = _gravity.last.tsUs * 1000;

    final t0Ns = math.max(rawFirstNs, gravityFirstNs);
    final tEndNs = math.min(rawLastNs, gravityLastNs);

    if (tEndNs <= t0Ns) {
      return fail('raw 와 gravity 의 수신 구간이 겹치지 않는다');
    }

    final rowCount = (tEndNs - t0Ns) ~/ intervalNs + 1;
    final headTrimmedRows =
        (t0Ns - math.min(rawFirstNs, gravityFirstNs)) ~/ intervalNs;
    final tailTrimmedRows =
        (math.max(rawLastNs, gravityLastNs) - tEndNs) ~/ intervalNs;

    final rawCursor = _ChannelCursor(_raw);
    final gravityCursor = _ChannelCursor(_gravity);
    final samples = <GridSample>[];

    for (var n = 0; n < rowCount; n++) {
      final tNs = t0Ns + n * intervalNs;
      final rawPoint = rawCursor.valueAt(tNs);
      final gravityPoint = gravityCursor.valueAt(tNs);
      if (rawPoint == null || gravityPoint == null) {
        // 범위 계산이 맞다면 도달하지 않는다. 도달했다면 직전 값으로 메우지 않고
        // 사유를 남기고 멈춘다 — 복사한 행이 실측처럼 섞이는 것을 막는다.
        return fail(
          '격자 $n 행($tNs ns)을 감싸는 실측값이 없다. '
          'raw=${rawPoint != null}, gravity=${gravityPoint != null}',
        );
      }
      samples.add(
        GridSample(
          xMg: rawPoint.x - gravityPoint.x,
          yMg: rawPoint.y - gravityPoint.y,
          zMg: rawPoint.z - gravityPoint.z,
        ),
      );
    }

    return GridResampleResult(
      samples: samples,
      t0Ns: t0Ns,
      gridIntervalNs: intervalNs,
      rawUsedCount: _raw.length,
      gravityUsedCount: _gravity.length,
      droppedZeroCount: _droppedZeroCount,
      droppedBackwardCount: _droppedBackwardCount,
      droppedLinearCount: _droppedLinearCount,
      headTrimmedRows: headTrimmedRows,
      tailTrimmedRows: tailTrimmedRows,
      rawMaxSpanNs: rawCursor.maxSpanNs,
      gravityMaxSpanNs: gravityCursor.maxSpanNs,
      degenerateSpanCount:
          rawCursor.degenerateSpanCount + gravityCursor.degenerateSpanCount,
    );
  }
}

/// 목적: 한 종류의 이벤트 목록을 앞에서부터 한 번만 훑으면서
///       임의 시각의 값을 비례 계산으로 구한다.
///       격자 시각이 순증가하므로 커서를 되돌릴 필요가 없다.
class _ChannelCursor {
  _ChannelCursor(this.events);

  /// 시각 순으로 정렬된 이벤트 목록
  final List<NativeEvent> events;

  int _index = 0;

  /// 앞뒤 이벤트 사이 최대 간격 (나노초)
  int maxSpanNs = 0;

  /// 앞뒤 시각이 같아 비례 계산이 불가능했던 횟수
  int degenerateSpanCount = 0;

  /// 목적: 지정 시각의 값을 앞뒤 실측값 사이 비례로 계산한다.
  /// 인자: tNs — 값을 구할 시각 (나노초)
  /// 반환: 계산된 X/Y/Z 값. 지정 시각을 감싸는 앞뒤 실측값이 없으면 null
  /// 식: alpha = (t - t_앞) / (t_뒤 - t_앞)
  ///     값 = 값_앞 + alpha x (값_뒤 - 값_앞)
  /// 근거: 인용 — 두 점 사이 선형 보간(linear interpolation) 공식
  ({double x, double y, double z})? valueAt(int tNs) {
    while (_index + 1 < events.length &&
        events[_index + 1].tsUs * 1000 < tNs) {
      _index++;
    }
    if (_index + 1 >= events.length) return null;

    final before = events[_index];
    final after = events[_index + 1];
    final beforeNs = before.tsUs * 1000;
    final afterNs = after.tsUs * 1000;
    final spanNs = afterNs - beforeNs;

    if (spanNs > maxSpanNs) maxSpanNs = spanNs;

    if (spanNs <= 0) {
      degenerateSpanCount++;
      return (x: before.xMg, y: before.yMg, z: before.zMg);
    }
    if (tNs < beforeNs || tNs > afterNs) return null;

    final alpha = (tNs - beforeNs) / spanNs;
    return (
      x: before.xMg + alpha * (after.xMg - before.xMg),
      y: before.yMg + alpha * (after.yMg - before.yMg),
      z: before.zMg + alpha * (after.zMg - before.zMg),
    );
  }
}
