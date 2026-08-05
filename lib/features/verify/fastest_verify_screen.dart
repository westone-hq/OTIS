import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../../core/theme.dart';
import '../../domain/auth_repository.dart';
import '../../domain/measure/sample_rate.dart';
import '../../domain/prefs_store.dart';
import '../../domain/repository/verify_export_repository.dart';
import '../../domain/verify_sensor_channel.dart';

/// FASTEST·HandlerThread·1ms·3ms를 한 번에 실행하고 txt 8개를 출력한다.
class FastestVerifyScreen extends StatefulWidget {
  const FastestVerifyScreen({super.key});

  @override
  State<FastestVerifyScreen> createState() => _FastestVerifyScreenState();
}

class _FastestVerifyScreenState extends State<FastestVerifyScreen> {
  final _fastestChannel = VerifySensorChannel(VerifyMode.fastest);
  final _fixedChannel = VerifySensorChannel(VerifyMode.fixed);
  final _repository = VerifyExportRepository();
  StreamSubscription<dynamic>? _fastestSubscription;
  StreamSubscription<dynamic>? _fixedSubscription;

  bool _running = false;
  bool _saving = false;
  bool _emailSending = false;
  String? _savedPaths;
  List<String> _savedFilePaths = const [];
  String? _error;
  final Map<String, Map<String, dynamic>> _statsByLane = {};

  Future<void> _start() async {
    if (_running || _saving) return;
    setState(() {
      _running = true;
      _savedPaths = null;
      _savedFilePaths = const [];
      _error = null;
      _statsByLane.clear();
    });

    try {
      _fastestSubscription = _fastestChannel.events.listen(_onEvent);
      _fixedSubscription = _fixedChannel.events.listen(_onEvent);
      // 네 방식 모두 같은 측정 구간에 시작한다.
      await Future.wait([_fastestChannel.start(), _fixedChannel.start()]);
    } catch (error) {
      await _stopChannelsWithoutExport();
      if (mounted) {
        setState(() {
          _running = false;
          _error = '센서를 시작하지 못했습니다: $error';
        });
      }
    }
  }

  Future<void> _stopAndExport() async {
    if (!_running || _saving) return;
    setState(() => _saving = true);
    try {
      // 두 네이티브 핸들러를 먼저 멈춰 4+4 경로를 모두 회수한다.
      final stopped = await Future.wait([
        _fastestChannel.stop(),
        _fixedChannel.stop(),
      ]);
      final nativePaths = <String, String>{...stopped[0], ...stopped[1]};
      await _cancelSubscriptions();

      // 8개가 모두 있을 때만 같은 세션 폴더의 최종 이름으로 확정한다.
      final exported = await _repository.exportAll(nativePaths);
      if (!mounted) return;
      setState(() {
        _running = false;
        _saving = false;
        _savedFilePaths = exported.files.map((file) => file.path).toList();
        _savedPaths = _savedFilePaths.join('\n');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검증 파일 8개 저장 완료\n${exported.directory.path}')),
      );
    } catch (error) {
      await _cancelSubscriptions();
      if (!mounted) return;
      setState(() {
        _running = false;
        _saving = false;
        _error = '8개 파일 출력 실패: $error';
      });
    }
  }

  Future<void> _sendEmail() async {
    if (_savedFilePaths.length != 8 || _emailSending) return;
    final userId = AuthRepository.instance.currentUserId;
    final recipient = userId == null
        ? null
        : await PrefsStore.instance.loadEmail(userId);
    if (recipient == null || recipient.trim().isEmpty) {
      if (mounted) {
        setState(() => _error = '설정 화면에서 결과 수신 이메일을 먼저 등록해 주세요.');
      }
      return;
    }

    setState(() => _emailSending = true);
    try {
      await FlutterEmailSender.send(
        Email(
          subject: 'OTIS 센서 수신 비교 결과 (8개 txt)',
          body:
              'FASTEST, HandlerThread, 1ms, 3ms의 '
              '원본 및 256Hz 보간 결과입니다.\n\n첨부 8개',
          recipients: [recipient.trim()],
          attachmentPaths: _savedFilePaths,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 작성창을 열었습니다. 파일 8개가 첨부되었습니다.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '메일 작성창 호출 실패: $error');
    } finally {
      if (mounted) setState(() => _emailSending = false);
    }
  }

  void _onEvent(dynamic event) {
    if (!mounted || event is! Map) return;
    final lane = event['lane']?.toString();
    if (lane == null) return;
    setState(() {
      _statsByLane[lane] = Map<String, dynamic>.from(event);
    });
  }

  Future<void> _stopChannelsWithoutExport() async {
    try {
      await Future.wait([_fastestChannel.stop(), _fixedChannel.stop()]);
    } catch (_) {}
    await _cancelSubscriptions();
  }

  Future<void> _cancelSubscriptions() async {
    await _fastestSubscription?.cancel();
    await _fixedSubscription?.cancel();
    _fastestSubscription = null;
    _fixedSubscription = null;
  }

  @override
  void dispose() {
    _fastestSubscription?.cancel();
    _fixedSubscription?.cancel();
    if (_running) {
      _fastestChannel.stop();
      _fixedChannel.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('전체 센서 수신 비교')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDims.screenPad),
          children: [
            Text(
              'FASTEST, FASTEST+HandlerThread, 1ms, 3ms를 동시에 받고 '
              '각각 ${SampleRate.hz}Hz로 보간합니다.',
              style: AppText.body,
            ),
            const SizedBox(height: AppDims.gap2),
            _statusCard('FASTEST', 'fastest'),
            const SizedBox(height: AppDims.gap),
            _statusCard('FASTEST + HandlerThread', 'handlerThread'),
            const SizedBox(height: AppDims.gap),
            _statusCard('1ms 요청', 'oneMs'),
            const SizedBox(height: AppDims.gap),
            _statusCard('3ms 요청', 'threeMs'),
            if (_savedPaths != null) ...[
              const SizedBox(height: AppDims.gap2),
              _messageBox('파일 8개 저장됨', _savedPaths!, AppColors.green),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppDims.gap2),
              _messageBox('오류', _error!, AppColors.red),
            ],
            const SizedBox(height: AppDims.gap3),
            SizedBox(
              height: AppDims.buttonH,
              child: ElevatedButton(
                onPressed: _running ? null : _start,
                child: Text(_running ? '네 방식 동시 수신 중' : '전체 검증 시작'),
              ),
            ),
            const SizedBox(height: AppDims.gap),
            SizedBox(
              height: AppDims.buttonH,
              child: OutlinedButton(
                onPressed: _running && !_saving ? _stopAndExport : null,
                child: Text(_saving ? '파일 8개 만드는 중…' : '중지 및 파일 8개 출력'),
              ),
            ),
            const SizedBox(height: AppDims.gap),
            SizedBox(
              height: AppDims.buttonH,
              child: ElevatedButton.icon(
                onPressed: _savedFilePaths.length == 8 && !_emailSending
                    ? _sendEmail
                    : null,
                icon: const Icon(Icons.email_outlined),
                label: Text(_emailSending ? '메일 준비 중…' : '파일 8개 이메일 보내기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String title, String lane) {
    final stats = _statsByLane[lane] ?? const <String, dynamic>{};
    String integer(String key) =>
        ((stats[key] as num?) ?? 0).toInt().toString();
    String decimal(String key) =>
        ((stats[key] as num?) ?? 0).toDouble().toStringAsFixed(3);

    return Container(
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDims.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.bodyBold),
          const SizedBox(height: 4),
          _row(
            'raw / gravity / linear',
            '${integer('rawCount')} / ${integer('gravityCount')} / '
                '${integer('linearCount')}',
          ),
          _row('원본 linear Hz', decimal('rawHz')),
          _row(
            '평균 / 최소 / 최대',
            '${decimal('meanDtMs')} / ${decimal('minDtMs')} / '
                '${decimal('maxDtMs')} ms',
          ),
          _row('256Hz 가공 개수', integer('resampledCount')),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppText.body)),
        Text(value, style: AppText.bodyBold),
      ],
    ),
  );

  Widget _messageBox(String title, String message, Color color) => Container(
    padding: const EdgeInsets.all(AppDims.gap2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(AppDims.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.bodyBold.copyWith(color: color)),
        const SizedBox(height: 4),
        SelectableText(message, style: AppText.caption),
      ],
    ),
  );
}
