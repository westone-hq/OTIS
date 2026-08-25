import 'dart:math' as math;

import 'package:vibration_checker/domain/capture/capture_config.dart';
import 'package:vibration_checker/domain/capture/native_event.dart';

/// 작성: 2026-08-19 08:04:05 · 박건준
/// 클래스: GridSample
/// 목적: 격자(일정한 시간 간격으로 줄 세운 표의 각 행) 한 행의 진동값을
///       담는다. 시각은 담지 않는다.
///       출력 파일에 시간 열이 없으므로 시각은 행 번호로만 결정된다
///       (t = t0Ns + 행번호 x gridIntervalNs). 시각을 행마다 들고 다니면
///       등간격이 아닌 값이 섞여 들어갈 여지가 생긴다.
class GridSample {
  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: GridSample
  /// 목적: 격자 한 행의 X/Y/Z 진동값을 그대로 담는 생성자.
  /// 인자: xMg — X축 진동값 (mg)
  ///       yMg — Y축 진동값 (mg)
  ///       zMg — Z축 진동값 (mg)
  const GridSample({required this.xMg, required this.yMg, required this.zMg});

  /// X축 motion (mg)
  final double xMg;

  /// Y축 motion (mg)
  final double yMg;

  /// Z축 motion (mg)
  final double zMg;
}

/// 작성: 2026-08-19 08:04:05 · 박건준
/// 클래스: GridResampleResult
/// 목적: 격자 환산 결과와 환산 과정에서 폐기·이상으로 집계된 수치를 함께 담는다.
///       실측되지 않은 값을 0 등으로 대신 채우면 실제 측정처럼 보여
///       구분할 수 없게 된다. 그래서 값을 채우는 대신 몇 개나
///       폐기됐는지만 집계해 결과에 함께 싣는다.
class GridResampleResult {
  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: GridResampleResult
  /// 목적: 격자 환산 결과와 폐기·이상 집계값을 그대로 담는 생성자.
  /// 인자: samples — 격자 행 목록
  ///       t0Ns — 격자 0번 행의 시각 (나노초)
  ///       gridIntervalNs — 격자 간격 (나노초)
  ///       rawUsedCount — 환산에 사용된 raw 유효 이벤트 수
  ///       gravityUsedCount — 환산에 사용된 gravity 유효 이벤트 수
  ///       droppedZeroCount — 전 축이 0이어서 폐기한 이벤트 수
  ///       droppedBackwardCount — 시각이 거꾸로 와서 폐기한 이벤트 수
  ///       droppedLinearCount — linear 종류라서 버린 이벤트 수
  ///       headTrimmedRows — 시작단에서 생성하지 않은 행 수
  ///       tailTrimmedRows — 끝단에서 생성하지 않은 행 수
  ///       rawMaxSpanNs — raw 이벤트 사이 최대 간격 (나노초)
  ///       gravityMaxSpanNs — gravity 이벤트 사이 최대 간격 (나노초)
  ///       degenerateSpanCount — 비례 계산이 불가능했던 횟수
  ///       failureReason — 환산 실패 사유. 성공 시 null
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

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: GridResampleResult.failure
  /// 목적: 환산이 불가능한 조건에서 빈 결과와 사유만 담아 반환한다.
  /// 인자: reason — 환산 실패 사유
  ///       gridIntervalNs — 격자 간격 (나노초)
  ///       rawUsedCount — 환산에 사용된 raw 유효 이벤트 수
  ///       gravityUsedCount — 환산에 사용된 gravity 유효 이벤트 수
  ///       droppedZeroCount — 전 축이 0이어서 폐기한 이벤트 수
  ///       droppedBackwardCount — 시각이 거꾸로 와서 폐기한 이벤트 수
  ///       droppedLinearCount — linear 종류라서 버린 이벤트 수
  /// 반환: 표 없이 사유와 집계값만 담긴 실패 결과
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

  /// linear(안드로이드가 raw에서 자체 계산한 중력값을 이미 빼서
  /// 내보내는 합성 센서) 종류라서 쓰지 않고 버린 이벤트 수. 이
  /// 프로젝트는 그 합성값을 믿는 대신 raw와 gravity를 직접 받아 뺀다
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

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: isSuccess
  /// 목적: 환산이 성공했는지 알려준다.
  bool get isSuccess => failureReason == null && samples.isNotEmpty;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: rowCount
  /// 목적: 격자 행 수를 반환한다.
  int get rowCount => samples.length;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: durationSec
  /// 목적: 격자가 덮는 총 시간을 초 단위로 반환한다.
  /// 식: (행 수 - 1) x 격자간격 / 1e9
  double get durationSec =>
      rowCount < 2 ? 0.0 : (rowCount - 1) * gridIntervalNs / 1000000000.0;
}

/// 작성: 2026-08-19 08:04:05 · 박건준
/// 클래스: GridResampler
/// 목적: 수신한 원본 이벤트를 모아두었다가, 측정 종료 시 등간격 격자로 환산한다.
///       raw 와 gravity 를 각각 따로 격자에 맞춘 뒤 빼서 motion 을 만든다.
///
///       용어
///         raw      가속도 원본. 중력과 승강기 가속과 진동이 모두 섞인 값
///         gravity  중력 방향 성분. 센서 허브가 계산해 내보내는 값이며 크기는 1000mg 고정
///         motion   raw - gravity. 중력을 뺀 뒤 남는 승강기 가속과 진동
///         격자      출력 파일의 등간격 행. 간격은 CaptureConfig.idealIntervalNs 로 정한다
///         단위는 전부 mg(밀리지, 1000mg = 중력가속도 1개분)
///
///       격자 시각은 센서 시각에서 유도하지 않고 t0 에서 일정량을 더해서만
///       정한다. 출력 파일에 시간 열이 없어 등간격이 필수이기 때문이다.
///       raw 와 gravity 를 각각 환산한 뒤 뺀다. 직전 gravity 값을 재사용하면
///       결과에 계단 성분이 남고 이후 환산으로 제거되지 않는다.
///       앞뒤를 감싸는 실측값이 없는 격자점은 만들지 않는다. 직전 값 복사는
///       파일에서 실측과 구분할 수 없게 만든다.
class GridResampler {
  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: GridResampler
  /// 목적: 격자 환산 설정을 받아 빈 수집기를 만든다.
  /// 인자: config — 격자 간격과 목표 주기를 담은 수집 설정
  GridResampler({required this.config});

  /// 격자 간격과 목표 주기를 담은 수집 설정
  final CaptureConfig config;

  /// 그동안 받은 raw(가속도 원본) 이벤트를 시각 순으로 쌓아 둔 목록
  final List<NativeEvent> _raw = <NativeEvent>[];

  /// 그동안 받은 gravity(중력 성분) 이벤트를 시각 순으로 쌓아 둔 목록
  final List<NativeEvent> _gravity = <NativeEvent>[];

  /// 전 축이 0이어서 폐기한 이벤트 수. `resample()`이 실패 결과를
  /// 만들 때도 이 값을 그대로 실어 보낸다
  int _droppedZeroCount = 0;

  /// 시각이 거꾸로 와서 폐기한 이벤트 수
  int _droppedBackwardCount = 0;

  /// linear 종류라서 쓰지 않고 버린 이벤트 수
  int _droppedLinearCount = 0;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: rawCount
  /// 목적: 누적된 raw 이벤트 수를 반환한다 (진행 표시용).
  int get rawCount => _raw.length;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: gravityCount
  /// 목적: 누적된 gravity 이벤트 수를 반환한다 (진행 표시용).
  int get gravityCount => _gravity.length;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: onEvent
  /// 목적: 네이티브에서 올라온 원본 이벤트 1건을 종류별로 누적한다.
  ///       가공은 하지 않고, 환산에 쓸 수 없는 것만 걸러 집계한다.
  /// 인자: event — 네이티브에서 도착한 원본 이벤트
  /// 반환: 없음. 폐기 시 해당 집계값만 증가한다
  void onEvent(NativeEvent event) {
    switch (event.type) {
      case NativeEventType.linear:
        // OS 가 자체 계산해 내보내는 linear 값은 쓰지 않는다.
        _droppedLinearCount++;
        return;
      case NativeEventType.accel:
        // → 로직 이동: _accept()
        _accept(_raw, event);
        return;
      case NativeEventType.gravity:
        // → 로직 이동: _accept()
        _accept(_gravity, event);
        return;
    }
  }

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: _accept
  /// 목적: 한 종류의 목록에 이벤트를 넣되, 환산에 쓸 수 없는 두 경우를 걸러낸다.
  /// 인자: target — 누적할 목록
  ///       event — 검사할 이벤트
  /// 근거: 측정 — 측정 시작 직후 센서 버퍼(값을 잠시 담아 두는 임시
  ///       저장 공간)가 채워지기 전 전 축 0 이 올라오는 사례 확인.
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

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: resample
  /// 목적: 센서에서 들어오는 raw(가속도 원본) · gravity(중력 성분) 값은
  ///       일정한 시간 간격으로 오지 않는다. 이 함수는 그 값들을 갖고,
  ///       정해진 시간 간격마다(예: 1초에 256번) 값이 하나씩 있는 표를
  ///       만든다. 시간 간격이 정확히 일정해야 출력 파일에 시각을
  ///       따로 적지 않고도 행 번호만으로 각 행의 시각을 알 수 있기
  ///       때문이다. raw와 gravity는 측정 화면이 센서로부터 데이터를
  ///       받을 때마다 `onEvent()`를 불러 이미 쌓아 둔 값이다. 표의
  ///       각 행 값은 그 시각의 raw 값에서 gravity 값을 뺀
  ///       것(motion, 중력을 뺀 순수 진동)이다. 결과 하나를 만들고
  ///       나면 다시 부르지 않는다. 누적된 `_raw`, `_gravity`를 쓴다.
  /// 반환: 표 행 목록과 집계값을 담은 결과. 표를 만들 수 없는 조건을
  ///       만나면 표 없이 사유만 담긴 실패 결과를 대신 반환한다
  /// 식: t(n) = t0Ns + n x gridIntervalNs
  ///     motion(n) = raw_행(n) - gravity_행(n)
  GridResampleResult resample() {
    final intervalNs = config.idealIntervalNs; // 표 한 행 사이의 시간 간격(나노초)

    // 표를 만들 수 없을 때 지금까지 모은 사용·폐기 집계값을 그대로
    // 실어 실패 결과를 만든다. 실패하더라도 몇 개가 폐기됐는지는 남긴다
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

    // raw와 gravity 둘 다 값이 있는 시간대에서만 표를 만든다. 표의
    // 시작 시각(t0Ns)은 두 센서 중 더 늦게 시작한 쪽에, 끝
    // 시각(tEndNs)은 더 먼저 끝난 쪽에 맞춘다.
    final rawFirstNs = _raw.first.tsUs * 1000; // raw 첫 값의 시각(나노초)
    final rawLastNs = _raw.last.tsUs * 1000; // raw 마지막 값의 시각(나노초)
    final gravityFirstNs = _gravity.first.tsUs * 1000; // gravity 첫 값의 시각
    final gravityLastNs = _gravity.last.tsUs * 1000; // gravity 마지막 값의 시각

    final t0Ns = math.max(rawFirstNs, gravityFirstNs); // 표 1행의 시각
    final tEndNs = math.min(rawLastNs, gravityLastNs); // 표 마지막 행의 시각

    if (tEndNs <= t0Ns) {
      return fail('raw 와 gravity 의 수신 구간이 겹치지 않는다');
    }

    final rowCount = (tEndNs - t0Ns) ~/ intervalNs + 1; // 만들 표 행 수
    // raw와 gravity 중 한쪽이 다른 쪽보다 늦게 시작했다면, 둘 다 값이
    // 있어야 하는 조건 때문에 그 차이만큼 앞부분은 표에 넣지 못한다.
    // 그렇게 못 넣은 앞쪽 행 수
    final headTrimmedRows =
        (t0Ns - math.min(rawFirstNs, gravityFirstNs)) ~/ intervalNs;
    // 마찬가지로 한쪽이 먼저 끝났다면 그 차이만큼 뒷부분을 표에 넣지
    // 못한다. 그렇게 못 넣은 뒤쪽 행 수
    final tailTrimmedRows =
        (math.max(rawLastNs, gravityLastNs) - tEndNs) ~/ intervalNs;

    final rawCursor = _ChannelCursor(_raw); // raw에서 임의 시각의 값을 구해주는 객체
    final gravityCursor = _ChannelCursor(
      _gravity,
    ); // gravity에서 임의 시각의 값을 구해주는 객체
    final samples = <GridSample>[]; // 완성된 표 행을 쌓을 목록

    for (var n = 0; n < rowCount; n++) {
      final tNs = t0Ns + n * intervalNs; // 표의 n번째 행이 나타내는 시각
      // → 로직 이동: _ChannelCursor.valueAt()
      final rawPoint = rawCursor.valueAt(tNs); // 그 시각의 raw 값(비례 계산)
      // → 로직 이동: _ChannelCursor.valueAt()
      final gravityPoint = gravityCursor.valueAt(tNs); // 그 시각의 gravity 값(비례 계산)
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

/// 작성: 2026-08-19 08:04:05 · 박건준
/// 클래스: _ChannelCursor
/// 목적: 한 센서(raw 또는 gravity)에서 들어온 값 목록을 갖고 있다가,
///       임의의 시각에 그 센서가 어떤 값을 냈을지를 앞뒤 실측값 사이
///       비례 계산으로 구해준다.
class _ChannelCursor {
  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: _ChannelCursor
  /// 목적: 시각 순 이벤트 목록을 받아 커서를 처음 위치에 둔다.
  /// 인자: events — 시각 순으로 정렬된 이벤트 목록
  _ChannelCursor(this.events);

  /// 시각 순으로 정렬된 이벤트 목록
  final List<NativeEvent> events;

  /// `valueAt()`이 마지막으로 멈춘 위치(events의 인덱스). 이 위치가
  /// 곧 가장 최근에 구한 tNs 직전 실측값이다
  int _index = 0;

  /// 앞뒤 이벤트 사이 최대 간격 (나노초)
  int maxSpanNs = 0;

  /// 앞뒤 시각이 같아 비례 계산이 불가능했던 횟수
  int degenerateSpanCount = 0;

  /// 작성: 2026-08-19 08:04:05 · 박건준
  /// 함수: valueAt
  /// 목적: 지정한 시각에 이 센서가 어떤 값을 냈을지 계산한다. 그
  ///       시각을 감싸는 앞뒤 두 실측값을 직선으로 잇고, 그 직선
  ///       위에서 지정한 시각에 해당하는 값을 구한다(선형 보간).
  /// 인자: tNs — 값을 구할 시각 (나노초)
  /// 반환: 계산된 X/Y/Z 값. 지정 시각을 감싸는 앞뒤 실측값이 없으면 null
  /// 식: alpha = (t - t_앞) / (t_뒤 - t_앞)
  ///     값 = 값_앞 + alpha x (값_뒤 - 값_앞)
  /// 근거: 인용 — 두 점 사이 선형 보간 공식
  ({double x, double y, double z})? valueAt(int tNs) {
    // 이 함수는 매번 이전 호출보다 나중 시각으로 불리므로, 커서를
    // 뒤로 되돌릴 필요 없이 앞으로만 옮기면 된다. events[_index]가
    // tNs 이전의 마지막 실측값이 될 때까지 옮긴다
    while (_index + 1 < events.length && events[_index + 1].tsUs * 1000 < tNs) {
      _index++;
    }
    if (_index + 1 >= events.length) return null; // 뒤를 감쌀 실측값이 없다

    final before = events[_index]; // tNs 직전 실측값
    final after = events[_index + 1]; // tNs 직후 실측값
    final beforeNs = before.tsUs * 1000; // before의 시각(나노초)
    final afterNs = after.tsUs * 1000; // after의 시각(나노초)
    final spanNs = afterNs - beforeNs; // 두 실측값 사이 시간 간격

    if (spanNs > maxSpanNs) maxSpanNs = spanNs;

    if (spanNs <= 0) {
      degenerateSpanCount++;
      return (x: before.xMg, y: before.yMg, z: before.zMg);
    }
    if (tNs < beforeNs || tNs > afterNs) return null;

    final alpha = (tNs - beforeNs) / spanNs; // tNs가 두 실측값 사이 몇 배 지점인지(0~1)
    return (
      x: before.xMg + alpha * (after.xMg - before.xMg),
      y: before.yMg + alpha * (after.yMg - before.yMg),
      z: before.zMg + alpha * (after.zMg - before.zMg),
    );
  }
}
