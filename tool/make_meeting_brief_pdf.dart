import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 금요일 줌 회의용 설명 자료 PDF
/// - 개발 용어(Hz 등)만 쉬운 말로 병기
/// - 적분, Aptp 등 공학/측정 용어는 그대로 유지
Future<void> main() async {
  final reg = File('assets/fonts/Pretendard-Regular.ttf');
  final bold = File('assets/fonts/Pretendard-Bold.ttf');
  if (!await reg.exists() || !await bold.exists()) {
    stderr.writeln('Pretendard fonts not found under assets/fonts/');
    exit(1);
  }

  final fontReg =
      pw.Font.ttf(await reg.readAsBytes().then((b) => b.buffer.asByteData()));
  final fontBold =
      pw.Font.ttf(await bold.readAsBytes().then((b) => b.buffer.asByteData()));

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
  );

  pw.Widget h1(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2, bottom: 8),
        child: pw.Text(
          t,
          style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
        ),
      );
  pw.Widget h2(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
        child: pw.Text(
          t,
          style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold),
        ),
      );
  pw.Widget p(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(
          t,
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.25),
        ),
      );
  pw.Widget bullet(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 6, bottom: 2),
        child: pw.Text(
          '• $t',
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.2),
        ),
      );

  pw.Widget codeBlock(String title, String note, String code) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            note,
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              code,
              style: const pw.TextStyle(
                fontSize: 7.8,
                lineSpacing: 1.15,
                color: PdfColors.grey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      build: (context) => [
        h1('OTIS 승강기 측정 앱 — 원시 센서 데이터 설명 자료'),
        p('회의: 금요일 11:00 Zoom  |  측정 기기: Galaxy S22'),
        p('목적: 원시(raw) 센서 데이터와 핵심 코드 구조 공유'),

        h2('1. 한 줄 요약'),
        p('화면의 8.2mg / 32.5mg = 필터·Aptp 적용 후 결과값'),
        p('raw.txt = S22 센서로 수집한 원본 기록'),
        p('원본을 남기면 필터/공식을 바꿔도 재탑승 없이 재분석 가능'),

        h2('2. 데이터 3종류'),
        bullet('① 앱 결과값: 필터 + 정속 구간 + Aptp(A95)'),
        bullet('② raw.txt: 센서 샘플 전체 (원본)'),
        bullet('③ raw_summary.txt: ②의 min/max/mean/P-P 정리본'),
        p('UI는 ①만 표시, 메일 첨부로는 ②·③ 전송'),

        h2('3. 전체 흐름'),
        p('S22 센서 수집 (256Hz = 초당 256번)'),
        p('→ raw.txt 저장'),
        p('→ 진동: linear → 필터 → 정속 구간 → Aptp'),
        p('→ 속도·거리: (raw − gravity) → 적분 → 속도 → 적분 → 거리'),

        h2('4. 핵심 코드'),

        codeBlock(
          '① 센서 수집 — SensorStreamHandler.kt',
          '개발 용어: 256Hz = 초당 256번 샘플링. TYPE_* = Android 센서 종류.',
          '''when (event.sensor.type) {
  Sensor.TYPE_ACCELEROMETER ->        // rawX/Y/Z (중력 포함)
  Sensor.TYPE_GRAVITY ->              // gravityX/Y/Z
  Sensor.TYPE_LINEAR_ACCELERATION ->  // linearX/Y/Z (진동용)
}
// 256Hz로 리샘플 (초당 256샘플), 단위 mg''',
        ),

        codeBlock(
          '② 모션 성분 — sensor_sample.dart',
          '거리/속도용: motion = raw − gravity (없으면 linear 사용)',
          '''double get motionZ =>
    rawZ != null && gravityZ != null ? rawZ! - gravityZ! : z;''',
        ),

        codeBlock(
          '③ raw.txt 저장 — parse_raw.dart writeEvimp1()',
          'EVIMP1 포맷으로 전체 샘플 직렬화 (오프라인 재분석용)',
          '''EVIMP1
256
# columns: tsUs linearX linearY linearZ noiseDba
#          rawX rawY rawZ gravityX gravityY gravityZ
(tsUs) (linear) (noise) (raw) (gravity)
...''',
        ),

        codeBlock(
          '④ 파이프라인 분리 — measurement_engine.dart',
          '진동 경로와 거리/속도 경로를 분리',
          '''// 거리/속도
motion = raw - gravity
integ = MotionIntegrator.integrate(motion)

// 진동
vibration = filter(linear)
→ 정속 구간에서 Aptp 산출''',
        ),

        codeBlock(
          '⑤ 속도·거리 적분 — motion_integrator.dart',
          '가속도를 적분하여 속도, 속도를 적분하여 거리',
          '''accel[i] = motionZ[i] * mgToMetersPerSecondSquared;  // m/s²

// 속도 적분
signedSpeed[i] = signedSpeed[i-1] + accel[i] * dt;

// 거리 적분
signedPos[i] = signedPos[i-1] + signedSpeed[i] * dt;

maxSpeed = max(|v|),  distance = |s_end|''',
        ),

        h2('5. 개발 용어만 풀어 쓰기'),
        bullet('256Hz → 초당 256번 샘플링'),
        bullet('TYPE_ACCELEROMETER → 가속도계 원값 센서'),
        bullet('TYPE_GRAVITY → 중력 추정 센서'),
        bullet('TYPE_LINEAR_ACCELERATION → 중력 제외 가속도 센서'),
        bullet('EventChannel / 리샘플 → Flutter로 넘기기 전 시간 간격 맞춤'),
        p('※ 적분, Aptp, P-P, baseline 등은 측정/신호처리 용어 그대로 사용'),

        h2('6. 코드 파일 위치'),
        bullet('android/.../SensorStreamHandler.kt — 센서 수집'),
        bullet('lib/domain/measure/sensor_sample.dart — 샘플 모델 / motion'),
        bullet('lib/domain/parse_raw.dart — raw.txt I/O'),
        bullet('lib/domain/measure/measurement_engine.dart — 분석 오케스트레이션'),
        bullet('lib/domain/measure/motion_integrator.dart — 적분'),
        bullet('lib/domain/measure/signal_filters.dart — 진동 필터'),
        bullet('lib/domain/measure/vibration_metrics.dart — Aptp'),

        h2('7. 왜 이렇게 했나'),
        bullet('결과만 남기면 수치 검증·재분석이 불가능'),
        bullet('원본(raw)을 남기면 사무실에서 리플레이 가능'),
        bullet('Lift Check 비교는 A95끼리 같은 지표로'),
        bullet('값을 깎아 맞추지 않고 계산 근거를 남김'),

        h2('8. 금요일 논의 포인트'),
        bullet('원본 / 결과값 분리 구조 유지'),
        bullet('다음: 동일 엘베 Lift Check 동시 측정 (A95 비율)'),
        bullet('폰 거치 방향 통일 (X/Y 매핑)'),
        bullet('Z축 Aptp가 Lift Check보다 높은 원인 계속 분해'),

        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Text(
            '핵심: raw = 센서 원본 기록 / 화면 숫자 = 필터·Aptp 적용 결과. '
            '원본을 남기고 검증하는 단계.',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 1.25,
            ),
          ),
        ),
      ],
    ),
  );

  final outDir = Directory('docs');
  if (!await outDir.exists()) await outDir.create(recursive: true);
  final out = File('docs/회의자료_원시센서데이터_설명.pdf');
  await out.writeAsBytes(await doc.save());
  stdout.writeln('Wrote ${out.path}');
}
