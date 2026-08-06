import 'dart:io';

/// 보간 전 원본 센서 이벤트의 종류.
///
/// accel   = 가속도계 원값 (중력 포함)
/// gravity = 중력 추정값
/// linear  = 선형가속도 (중력 제거)
enum NativeEventType { accel, gravity, linear }

/// 보간 전 원본 센서 이벤트 1건.
///
/// 안드로이드 센서 콜백이 도착한 그대로를 담는다.
/// 값 가공(보간·필터·보정)은 이 계층에서 하지 않는다.
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

  /// 센서가 찍은 시각 (마이크로초). 부팅 기준 단조증가.
  /// 근거: 인용 — Android SensorEvent.timestamp(나노초)를 마이크로초로 환산한 값
  final int tsUs;

  /// X축 가속도 (밀리지)
  final double xMg;

  /// Y축 가속도 (밀리지)
  final double yMg;

  /// Z축 가속도 (밀리지)
  final double zMg;

  /// 직전 동일 종류 이벤트와의 간격 (마이크로초). 첫 이벤트는 0.
  /// 기록 당시 네이티브가 계산한 값을 그대로 보존한다.
  /// 판독 후 tsUs 차이로 재계산해 이 값과 대조하면 기록 무결성을 검증할 수 있다.
  final int dtUs;

  /// 목적: 파일 한 줄을 이벤트로 판독한다.
  /// 인자: line — 공백 구분 6항목 (type tsUs xMg yMg zMg dtUs)
  /// 반환: 이벤트. 형식이 맞지 않으면 null (0값 대체 금지 — 유령 샘플 차단)
  /// 근거: 인용 — develop 브랜치 08ef27a raw_native.txt 형식
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

  /// 목적: 이벤트를 파일 한 줄로 만든다.
  /// 인자: 없음
  /// 반환: 공백 구분 6항목 문자열. fromRecordLine 과 왕복 시 값이 보존된다
  /// 근거: 인용 — develop 브랜치 08ef27a raw_native.txt 형식
  String toRecordLine() {
    return '${type.name} $tsUs $xMg $yMg $zMg $dtUs';
  }
}

/// raw_native 형식 기록·판독.
///
/// develop 브랜치가 생성하는 otis_raw_native_*.txt 와 상호 호환된다.
/// # 로 시작하는 줄은 주석으로 취급한다.
class NativeEventRecord {
  /// 목적: 이벤트 목록을 파일 내용 전체로 만든다.
  /// 인자: events — 이벤트 목록 (수신 순서 유지)
  ///       targetSampleRateHz — 측정 당시 목표 주기 (헤르츠). 머리말에 기록
  /// 반환: 머리말 4줄 + 이벤트 줄들. 반올림·가공 없음
  /// 근거: 인용 — develop 브랜치 08ef27a raw_native.txt 형식
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

  /// 목적: 파일 내용 전체를 이벤트 목록으로 판독한다.
  /// 인자: text — 파일 내용. 주석(#)과 빈 줄은 건너뛴다
  /// 반환: events — 판독된 이벤트 (파일 순서 유지)
  ///       skippedLineCount — 형식 불일치로 폐기한 줄 수 (주석·빈 줄 제외).
  ///       폐기 줄을 0값으로 채우지 않는다 — 유령 샘플 차단
  /// 근거: 인용 — develop 브랜치 08ef27a raw_native.txt 형식
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

  /// 목적: 이벤트 목록을 파일로 저장한다.
  static Future<void> writeFile(
    String path,
    List<NativeEvent> events, {
    required int targetSampleRateHz,
  }) async {
    await File(path).writeAsString(
      encode(events, targetSampleRateHz: targetSampleRateHz),
    );
  }

  /// 목적: 파일을 읽어 이벤트 목록으로 판독한다.
  static Future<({List<NativeEvent> events, int skippedLineCount})> readFile(
    String path,
  ) async {
    return decode(await File(path).readAsString());
  }
}
