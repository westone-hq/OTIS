/// 작성: 2026-08-06 14:47:52 · 박건준
/// 수정: 2026-10-04 14:30:00 · nada
/// 클래스: NativeEventType
/// 목적: 안드로이드 센서가 올려 보내는 가공 전 값의 종류.
///       - `accel` — 중력이 섞인 가속도 원본
///       - `gravity` — 기기가 추정한 중력 방향
///       - `linear` — 안드로이드가 중력을 빼서 내 준 가속도. 쓰지 않는다
///         (`GridResampler.onEvent()` 가 받는 즉시 버린다)
/// 근거: 미확인 — `linear` 를 쓰지 않는 이유를 "부정확해서"라고 적어
///       두었으나, 잰 기록이 코드 · 문서에 없다
enum NativeEventType { accel, gravity, linear }

/// 작성: 2026-08-06 14:47:52 · 박건준
/// 수정: 2026-10-04 14:30:00 · nada
/// 클래스: NativeEvent
/// 목적: 안드로이드 센서 콜백(callback, 값이 준비되면 시스템이 대신
///       불러주는 함수)에서 도착한 가공되지 않은 1건의 센서 이벤트를
///       담는다. 값에 대한 어떠한 가공(보간(양옆 실측값 사이를 비례로
///       채워 넣는 계산), 필터, 보정)도 이 단계에서는 수행하지 않는다.
class NativeEvent {
  /// 작성: 2026-08-06 14:47:52 · 박건준
  /// 수정: 2026-09-15 13:30:00 · 박희정
  /// 함수: NativeEvent
  /// 목적: 네이티브에서 도착한 원본 이벤트 값들을 그대로 담는 생성자.
  /// 인자: type — 이벤트 종류 (accel/gravity/linear)
  ///       tsUs — 측정 시각 (마이크로초)
  ///       xMg, yMg, zMg — 세 축 가속도 값 (mg)
  ///       dtUs — 같은 종류 직전 값과의 시간 간격 (마이크로초)
  ///       noiseDba — 같은 시각에 붙인 소음(dBA). 채널에 없으면 null
  const NativeEvent({
    required this.type,
    required this.tsUs,
    required this.xMg,
    required this.yMg,
    required this.zMg,
    required this.dtUs,
    this.noiseDba,
  });

  /// 이벤트 종류
  final NativeEventType type;

  /// 센서가 값을 잰 시각 (마이크로초). 안드로이드 `SensorEvent.timestamp`
  /// 를 옮긴 값이라 기기를 켠 뒤부터 줄지 않고 늘기만 하는 시계 기준이다.
  /// 벽시계 시각과는 다르다
  final int tsUs;

  /// X축 가속도 (mg)
  final double xMg;

  /// Y축 가속도 (mg)
  final double yMg;

  /// Z축 가속도 (mg)
  final double zMg;

  /// 같은 종류 바로 앞 값과의 시간 간격 (마이크로초). 안드로이드가 계산해
  /// 넘긴 값을 그대로 담아, 수신이 늦거나 빠진 구간을 찾는 데 쓴다.
  /// 첫 값이면 0
  final int dtUs;

  /// 이 이벤트와 함께 실려 온 가장 최근 소음 크기 (dBA). 안드로이드가 값을
  /// 보내지 않았으면 null, 마이크 권한이 없거나 소음 창이 아직 덜 찼으면 0
  final double? noiseDba;

  /// 작성: 2026-08-06 14:47:52 · 박건준
  /// 수정: 2026-09-15 13:30:00 · 박희정
  /// 함수: fromChannelMap
  /// 목적: 안드로이드가 `EventChannel`(네이티브가 데이터를 계속 흘려
  ///       보내는 통로)로 보낸 표 하나를 이벤트로 바꾼다.
  /// 인자: map — 안드로이드가 보낸 표. 열쇠는 type · tsUs · xMg · yMg ·
  ///       zMg · dtUs · noiseDba(없어도 됨)
  /// 반환: 바꾼 이벤트. 열쇠가 빠졌거나 값의 형이 맞지 않으면 null —
  ///       잘못된 값이 이벤트로 섞이지 않게 한다
  /// 근거: 인용 — 열쇠 이름과 형은 `SensorStreamHandler.kt` 가 보내는
  ///       표와 맞춘 것이다
  static NativeEvent? fromChannelMap(Map<dynamic, dynamic> map) {
    final type = NativeEventType.values
        .asNameMap()[map['type']]; // 이름이 안 맞으면 null
    final tsUs = map['tsUs']; // 타입 검사는 아래에서 한다
    final xMg = map['xMg']; // 타입 검사는 아래에서 한다
    final yMg = map['yMg']; // 타입 검사는 아래에서 한다
    final zMg = map['zMg']; // 타입 검사는 아래에서 한다
    final dtUs = map['dtUs']; // 타입 검사는 아래에서 한다
    final noiseRaw = map['noiseDba']; // 없어도 됨. 있으면 num
    if (type == null ||
        tsUs is! int ||
        xMg is! num ||
        yMg is! num ||
        zMg is! num ||
        dtUs is! int) {
      return null;
    }
    if (noiseRaw != null && noiseRaw is! num) return null;
    return NativeEvent(
      type: type,
      tsUs: tsUs,
      xMg: xMg.toDouble(),
      yMg: yMg.toDouble(),
      zMg: zMg.toDouble(),
      dtUs: dtUs,
      noiseDba: noiseRaw is num ? noiseRaw.toDouble() : null,
    );
  }
}
