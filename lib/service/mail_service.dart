import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:vibration_checker/adapter/storage/measurement_repository.dart';
import 'package:vibration_checker/adapter/storage/prefs_store.dart';
import 'package:vibration_checker/domain/mail/mail_composer.dart';
import 'package:vibration_checker/domain/measurement/measurement_naming.dart';

/// 작성: 2026-10-23 00:20:00 · 박건준
/// 클래스: MailService
/// 목적: 리포트 메일 한 통을 준비해 기기의 메일 앱에 넘기는 절차. 저장소
///       (`MeasurementRepository`)에서 측정 결과와 파일을 찾고, 문구는
///       `MailComposer` 에 맡기고, 메일 앱 작성창(`FlutterEmailSender`)을
///       연다. 메일 시트는 받는 사람 · 보낼 항목 · 버튼만 다룬다.
abstract final class MailService {
  /// 작성: 2026-08-19 10:33:43 · 박건준
  /// 수정: 2026-10-27 13:00:00 · 박건준
  /// 함수: buildJobEmail
  /// 목적: jobId 로 저장소를 조회해 리포트 메일을 조립한다. 보내기로 한
  ///       자료 중 실제로 없는 것이 있으면 본문 끝에 "누락:" 줄로 밝힌다 —
  ///       빠진 채로 조용히 나가면 받는 쪽이 한참 뒤에야 안다. 메일 앱
  ///       작성창에 본문이 그대로 뜨므로 보내는 사람도 누르기 전에 본다.
  ///       파일이 어디에 어떤 이름으로 있는지는 저장소에 묻는다. 화면이
  ///       경로를 짜 맞추면 저장 배치가 바뀔 때 여기가 조용히 어긋난다.
  ///       첨부는 방향 · 제번 · 측정 ID 가 들어간 이름(기기 측정 폴더 안
  ///       이름과 같다, `MeasurementNaming`)의 사본으로 붙인다 — 받는 쪽에서
  ///       여러 현장 메일을 구분하게 하려는 것이다. 자료 차례는 리포트 →
  ///       로우 데이터 → 현장 소음(`MeasurementFile` 차례)이다.
  ///       - PDF 리포트 — 없으면 그 자리에서 만든다
  ///       - 로우 데이터(EVIMP1) — 나중에 다시 만들 수 없어, 없으면
  ///         (이 파일을 쓰기 전 측정, 저장 도중 실패) 누락으로 밝힌다
  ///       - 현장 소음 녹음(M4A) — 측정 중 마이크 녹음. 없으면
  ///         (녹음 기능 전 측정, 마이크 권한 없음, 녹음 실패) 누락으로
  ///         밝힌다
  ///       안드로이드 원본(`native_raw.txt`, 2026-10-08 결정)과 소음 진단
  ///       산출물(2026-10-15 결정)은 찾지도 붙이지도 않는다. 본문 차례는
  ///       `MailComposer.body()` 를 본다.
  /// 인자: jobId — 첨부할 측정 결과의 식별자
  ///       items — 보내기로 고른 자료
  ///       recipients — 받을 주소 목록
  /// 반환: 수신자·제목·본문·첨부까지 채운 메일 객체. 측정 결과가 없으면
  ///       `StateError`
  static Future<Email> buildJobEmail({
    required String jobId,
    required Set<MeasurementFile> items,
    required List<String> recipients,
  }) async {
    // → 로직 이동: MeasurementRepository.load()
    final result = await MeasurementRepository.instance.load(
      jobId,
    ); // 조회된 측정 결과, 없으면 null
    if (result == null) {
      throw StateError('측정 결과를 찾을 수 없다: $jobId');
    }

    final repo = MeasurementRepository.instance; // 저장소 인스턴스
    final List<String> attachments = []; // 실제로 첨부할 파일 경로
    final List<String> attachmentLines = []; // 본문에 나열할 첨부 설명 줄
    final List<String> missing = []; // 보내기로 했는데 없는 자료

    for (final file in MeasurementFile.values) {
      if (!items.contains(file)) continue;
      final found = file == MeasurementFile.report
          // → 로직 이동: MeasurementRepository.ensureReportPdf()
          ? await repo.ensureReportPdf(jobId)
          // → 로직 이동: MeasurementRepository.findFile()
          : await repo.findFile(result, file); // 그 측정의 파일, 없으면 null
      // → 로직 이동: MailComposer.attachmentName()
      final name = MailComposer.attachmentName(result, file); // 첨부 이름
      if (found != null && await found.exists()) {
        // → 로직 이동: MeasurementRepository.mailAttachmentCopy()
        final copy = await repo.mailAttachmentCopy(found, name); // 사본
        attachments.add(copy.path);
        // → 로직 이동: MailComposer.attachmentLine()
        attachmentLines.add(MailComposer.attachmentLine(name, file));
      } else {
        // → 로직 이동: MailComposer.missingLine()
        missing.add(MailComposer.missingLine(file, name));
      }
    }

    return Email(
      // → 로직 이동: MailComposer.body()
      body: MailComposer.body(
        result: result,
        attachmentLines: attachmentLines,
        attachmentCount: attachments.length,
        missing: missing,
      ),
      subject: MailComposer.subject(result), // → 로직 이동: MailComposer.subject()
      recipients: recipients,
      attachmentPaths: attachments,
    );
  }

  /// 작성: 2026-10-23 00:20:00 · 박건준
  /// 함수: send
  /// 목적: 기기에 이미 설치된 메일 앱(Gmail 등)의 작성 화면을 메일 내용으로
  ///       미리 채워서 띄우고, 고른 주소를 기억해 다음에 미리 골라 둔다.
  ///       실제 발송 버튼은 사용자가 그 메일 앱에서 직접 눌러야 한다.
  /// 인자: email — `buildJobEmail()` 이 조립한 메일
  /// 반환: 작성창을 연 뒤 완료되는 비동기 작업. 메일 앱을 못 열면 예외
  static Future<void> send(Email email) async {
    // → 로직 이동: FlutterEmailSender.send()
    await FlutterEmailSender.send(email);
    // → 로직 이동: PrefsStore.saveLastRecipients()
    await PrefsStore.instance.saveLastRecipients(email.recipients);
  }
}
