import 'dart:io';

/// 목적: 스마트폰 하드웨어 센서에서 직접 올라오는 원시(Raw) 데이터의 3가지 종류를 정의한다.
///       - accel: 중력이 포함된 가속도계 원본 데이터
///       - gravity: 스마트폰이 추정한 중력 방향 데이터
///       - linear: OS가 자체적으로 중력을 제거한 선형 가속도 (당사에서는 부정확하여 미사용)
enum NativeEventType { accel, gravity, linear }

/// 목적: 안드로이드 센서 콜백에서 도착한 가공되지 않은 1건의 센서 이벤트를 담는다.
///       값에 대한 어떠한 가공(보간, 필터, 보정)도 이 단계에서는 수행하지 않는다.
class NativeEvent {
  const NativeEvent({
    required this.type,
    required this.tsUs,
    required this.xMg,
    required this.yMg,
    required this.zMg,
    required this.dtUs,
  });

  /// 이벤트 종류
  final NativeEventType type;

  /// 목적: 센서가 데이터를 측정한 시점의 타임스탬프 (단위: 마이크로초)
  /// 근거: 인용 — 안드로이드 SensorEvent.timestamp 기준 단조증가(Monotonically increasing) 시간
  final int tsUs;

  /// X축 가속도 (밀리지)
  final double xMg;

  /// Y축 가속도 (밀리지)
  final double yMg;

  /// Z축 가속도 (밀리지)
  final double zMg;

  /// 목적: 바로 이전 데이터와 현재 데이터 사이의 시간 간격 (단위: 마이크로초)
  ///       안드로이드(Native) 단에서 넘겨준 값을 그대로 들고 와서 지연/유실 검증에 쓴다.
  final int dtUs;

  /// 목적: 텍스트 파일에 기록된 데이터 한 줄을 다시 NativeEvent 객체로 복원(역직렬화)한다.
  /// 인자: line — 파싱할 문자열 한 줄 (type, tsUs, xMg, yMg, zMg, dtUs 값이 공백으로 구분됨)
  /// 반환: 파싱된 NativeEvent 객체. 형식이 하나라도 어긋나면 null을 반환하여 잘못된 데이터(유령 샘플) 섞임을 막는다.
  static NativeEvent? fromRecordLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length != 6) return null;
    final type = NativeEventType.values.asNameMap()[parts[0]];
    final tsUs = int.tryParse(parts[1]);
    final xMg = double.tryParse(parts[2]);
    final yMg = double.tryParse(parts[3]);
    final zMg = double.tryParse(parts[4]);
    final dtUs = int.tryParse(parts[5]);
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

  /// 목적: NativeEvent 객체를 텍스트 파일에 기록하기 좋게 공백으로 구분된 한 줄의 문자열로 변환(직렬화)한다.
  String toRecordLine() {
    return '${type.name} $tsUs $xMg $yMg $zMg $dtUs';
  }

  /// 목적: 안드로이드 네이티브(EventChannel)에서 쏘아준 딕셔너리(Map) 형태의 데이터를 NativeEvent 객체로 조립한다.
  /// 인자: map — 안드로이드에서 전달받은 Map 데이터
  /// 반환: 파싱된 NativeEvent 객체. 데이터 타입이 안 맞거나 누락되면 null을 반환하여 유령 샘플을 차단한다.
  /// 근거: 인용 — 네이티브 채널 데이터 통신 규약
  static NativeEvent? fromChannelMap(Map<dynamic, dynamic> map) {
    final type = NativeEventType.values.asNameMap()[map['type']];
    final tsUs = map['tsUs'];
    final xMg = map['xMg'];
    final yMg = map['yMg'];
    final zMg = map['zMg'];
    final dtUs = map['dtUs'];
    if (type == null ||
        tsUs is! int ||
        xMg is! num ||
        yMg is! num ||
        zMg is! num ||
        dtUs is! int) {
      return null;
    }
    return NativeEvent(
      type: type,
      tsUs: tsUs,
      xMg: xMg.toDouble(),
      yMg: yMg.toDouble(),
      zMg: zMg.toDouble(),
      dtUs: dtUs,
    );
  }
}

/// 목적: 스마트폰에서 수집한 순수 원본 센서 이벤트를 `.txt` 파일로 저장하고,
///       나중에 다시 이 파일을 읽어서 앱 화면에 띄우거나 테스트할 수 있게 도와준다.
class NativeEventRecord {
  /// 목적: 여러 개의 NativeEvent 객체들이 들어있는 리스트를 통째로 텍스트 파일 형태의 긴 문자열로 변환한다.
  /// 인자: events — 저장할 센서 이벤트 리스트
  ///       targetSampleRateHz — 측정 시 설정했던 목표 주파수(Hz) (파일 머리말 기록용)
  /// 반환: 머리말(주석)과 센서 기록들이 줄바꿈(\n)으로 이어진 최종 텍스트 문자열
  static String encode(
    List<NativeEvent> events, {
    required int targetSampleRateHz,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# OTIS raw_native.txt · 보간 전 센서 이벤트');
    buffer.writeln('# columns: type tsUs x_mg y_mg z_mg dtUs');
    buffer.writeln('# type: accel | gravity | linear');
    buffer.writeln('# targetSampleRateHz: $targetSampleRateHz');
    for (final e in events) {
      buffer.writeln(e.toRecordLine());
    }
    return buffer.toString();
  }

  /// 목적: 통짜 텍스트 파일 문자열을 줄 단위로 쪼개어 읽으면서 다시 NativeEvent 리스트로 복원한다.
  /// 인자: text — 텍스트 파일 전체 문자열 (주석 `#`은 무시)
  /// 반환: 복원된 이벤트 리스트(events)와 파싱에 실패하여 버려진 줄 수(skippedLineCount)를 담은 레코드
  static ({List<NativeEvent> events, int skippedLineCount}) decode(
    String text,
  ) {
    final events = <NativeEvent>[];
    var skipped = 0;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final event = NativeEvent.fromRecordLine(trimmed);
      if (event == null) {
        skipped++;
      } else {
        events.add(event);
      }
    }
    return (events: events, skippedLineCount: skipped);
  }

  /// 목적: 이벤트 리스트를 실제 디바이스 저장소의 .txt 파일로 기록한다.
  static Future<void> writeFile(
    String path,
    List<NativeEvent> events, {
    required int targetSampleRateHz,
  }) async {
    await File(path).writeAsString(
      encode(events, targetSampleRateHz: targetSampleRateHz),
    );
  }

  /// 목적: 디바이스 저장소에 있는 .txt 파일을 읽어와 이벤트 리스트로 복원한다.
  static Future<({List<NativeEvent> events, int skippedLineCount})> readFile(
    String path,
  ) async {
    return decode(await File(path).readAsString());
  }
}
