/// 작성: 2026-08-06 14:47:52 · 박건준
/// 수정: 2026-10-04 13:44:32 · nada
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
/// 수정: 2026-10-04 13:44:32 · nada
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
  /// 수정: 2026-10-04 13:44:32 · nada
  /// 함수: fromRecordLine
  /// 목적: 기록 파일의 한 줄을 이벤트로 되살린다. `toRecordLine()` 의
  ///       반대다.
  /// 인자: line — 공백으로 나뉜 여섯 칸(종류 시각 x y z 간격) 한 줄
  /// 반환: 되살린 이벤트. 칸 수나 값 형식이 하나라도 어긋나면 null —
  ///       잘못된 줄이 이벤트로 섞이지 않게 한다
  static NativeEvent? fromRecordLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+')); // 공백으로 나눈 필드 조각들
    if (parts.length != 6) return null;
    final type = NativeEventType.values.asNameMap()[parts[0]]; // 형식 안 맞으면 null
    final tsUs = int.tryParse(parts[1]); // 형식 안 맞으면 null
    final xMg = double.tryParse(parts[2]); // 형식 안 맞으면 null
    final yMg = double.tryParse(parts[3]); // 형식 안 맞으면 null
    final zMg = double.tryParse(parts[4]); // 형식 안 맞으면 null
    final dtUs = int.tryParse(parts[5]); // 형식 안 맞으면 null
    if (type == null ||
        tsUs == null ||
        xMg == null ||
        yMg == null ||
        zMg == null ||
        dtUs == null) {
      return null;
    }
    return NativeEvent(
      type: type,
      tsUs: tsUs,
      xMg: xMg,
      yMg: yMg,
      zMg: zMg,
      dtUs: dtUs,
    );
  }

  /// 작성: 2026-08-06 14:47:52 · 박건준
  /// 수정: 2026-10-04 13:44:32 · nada
  /// 함수: toRecordLine
  /// 목적: 이벤트 하나를 기록 파일의 한 줄로 바꾼다. 소음은 싣지 않는다.
  /// 반환: "종류 tsUs xMg yMg zMg dtUs" 를 공백으로 이은 한 줄
  String toRecordLine() {
    return '${type.name} $tsUs $xMg $yMg $zMg $dtUs';
  }

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

/// 작성: 2026-08-06 14:47:52 · 박건준
/// 수정: 2026-10-04 13:44:32 · nada
/// 클래스: NativeEventRecord
/// 목적: 가공 전 센서 이벤트 목록과 기록 텍스트(`raw_native.txt` 형식)
///       사이를 오간다. 지금은 시험(native_event_test.dart)만 부른다 —
///       앱은 안드로이드가 직접 쓴 기록 파일을 복사만 하고 읽지 않는다.
class NativeEventRecord {
  /// 작성: 2026-08-06 14:47:52 · 박건준
  /// 수정: 2026-10-04 13:44:32 · nada
  /// 함수: encode
  /// 목적: 이벤트 목록을 머리말 몇 줄과 이벤트 한 줄씩으로 된 기록
  ///       텍스트로 만든다.
  /// 인자: events — 기록할 이벤트 목록
  ///       targetSampleRateHz — 측정 때 요청한 목표 주기 (Hz). 머리말에
  ///       적는다
  /// 반환: `#` 로 시작하는 머리말 뒤에 이벤트가 한 줄씩 이어진 텍스트
  static String encode(
    List<NativeEvent> events, {
    required int targetSampleRateHz,
  }) {
    final buffer = StringBuffer(); // 기록 텍스트를 쌓을 자리
    buffer.writeln('# OTIS raw_native.txt · 보간 전 센서 이벤트');
    buffer.writeln('# columns: type tsUs x_mg y_mg z_mg dtUs');
    buffer.writeln('# type: accel | gravity');
    buffer.writeln('# targetSampleRateHz: $targetSampleRateHz');
    for (final e in events) {
      buffer.writeln(e.toRecordLine());
    }
    return buffer.toString();
  }

  /// 작성: 2026-08-06 14:47:52 · 박건준
  /// 수정: 2026-10-04 13:44:32 · nada
  /// 함수: decode
  /// 목적: 기록 텍스트를 줄 단위로 읽어 이벤트 목록으로 되살린다. 빈 줄과
  ///       `#` 로 시작하는 머리말 줄은 건너뛴다.
  /// 인자: text — 기록 텍스트 전체
  /// 반환: 되살린 이벤트 목록(`events`)과, 형식이 맞지 않아 버린 줄
  ///       수(`skippedLineCount`)
  static ({List<NativeEvent> events, int skippedLineCount}) decode(
    String text,
  ) {
    final events = <NativeEvent>[]; // 복원에 성공한 이벤트를 쌓을 목록
    var skipped = 0; // 형식이 맞지 않아 버린 줄 수
    for (final line in text.split('\n')) {
      final trimmed = line.trim(); // 앞뒤 공백을 지운 한 줄
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final event = NativeEvent.fromRecordLine(trimmed); // 복원 실패 시 null
      if (event == null) {
        skipped++;
      } else {
        events.add(event);
      }
    }
    return (events: events, skippedLineCount: skipped);
  }
}
