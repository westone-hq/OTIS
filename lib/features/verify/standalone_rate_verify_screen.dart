import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../../core/theme.dart';
import '../../domain/auth_repository.dart';
import '../../domain/prefs_store.dart';
import '../../domain/repository/verify_export_repository.dart';
import '../../domain/verify_sensor_channel.dart';

/// 128Hz Core 하나만 실행하는 단독 측정 화면.
class Requested128VerifyScreen extends StatelessWidget {
  const Requested128VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _StandaloneRateVerifyScreen(
    rateHz: 128,
    samplingPeriodUs: 7813,
    mode: VerifyMode.requested128,
  );
}

/// 64Hz Core 하나만 실행하는 단독 측정 화면.
class Requested64VerifyScreen extends StatelessWidget {
  const Requested64VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _StandaloneRateVerifyScreen(
    rateHz: 64,
    samplingPeriodUs: 15625,
    mode: VerifyMode.requested64,
  );
}

class _StandaloneRateVerifyScreen extends StatefulWidget {
  const _StandaloneRateVerifyScreen({
    required this.rateHz,
    required this.samplingPeriodUs,
    required this.mode,
  });

  final int rateHz;
  final int samplingPeriodUs;
  final VerifyMode mode;

  @override
  State<_StandaloneRateVerifyScreen> createState() =>
      _StandaloneRateVerifyScreenState();
}

class _StandaloneRateVerifyScreenState
    extends State<_StandaloneRateVerifyScreen> {
  late final VerifySensorChannel _channel;
  final _repository = VerifyExportRepository();
  StreamSubscription<dynamic>? _subscription;
  Map<String, dynamic> _stats = const {};
  bool _running = false;
  bool _saving = false;
  bool _emailSending = false;
  String? _savedPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _channel = VerifySensorChannel(widget.mode);
  }

  Future<void> _start() async {
    if (_running || _saving) return;
    setState(() {
      _running = true;
      _stats = const {};
      _savedPath = null;
      _error = null;
    });
    try {
      _subscription = _channel.events.listen(_onEvent);
      await _channel.start(targetSampleRate: widget.rateHz);
    } catch (error) {
      await _stopWithoutExport();
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = '${widget.rateHz}Hz 단독 측정을 시작하지 못했습니다: $error';
      });
    }
  }

  Future<void> _stopAndExport() async {
    if (!_running || _saving) return;
    setState(() => _saving = true);
    try {
      final nativePaths = await _channel.stop();
      await _cancelSubscription();
      final exported = widget.rateHz == 128
          ? await _repository.exportStandalone128(nativePaths)
          : await _repository.exportStandalone64(nativePaths);
      if (!mounted) return;
      setState(() {
        _running = false;
        _saving = false;
        _savedPath = exported.files.single.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.rateHz}Hz 단독 측정 파일 저장 완료')),
      );
    } catch (error) {
      await _cancelSubscription();
      if (!mounted) return;
      setState(() {
        _running = false;
        _saving = false;
        _error = '${widget.rateHz}Hz 단독 측정 파일 저장 실패: $error';
      });
    }
  }

  Future<void> _sendEmail() async {
    final path = _savedPath;
    if (path == null || _emailSending) return;
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
          subject: 'OTIS ${widget.rateHz}Hz 단독 센서 측정 결과',
          body: '${widget.rateHz}Hz만 단독으로 요청한 원본 timestamp 및 실측 Hz 결과입니다.',
          recipients: [recipient.trim()],
          attachmentPaths: [path],
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 작성창을 열었습니다. 파일 1개가 첨부되었습니다.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '메일 작성창 호출 실패: $error');
    } finally {
      if (mounted) setState(() => _emailSending = false);
    }
  }

  void _onEvent(dynamic event) {
    if (!mounted || event is! Map) return;
    setState(() => _stats = Map<String, dynamic>.from(event));
  }

  Future<void> _stopWithoutExport() async {
    try {
      await _channel.stop();
    } catch (_) {}
    await _cancelSubscription();
  }

  Future<void> _cancelSubscription() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_running) _channel.stop();
    super.dispose();
  }

  String _integer(String key) =>
      ((_stats[key] as num?) ?? 0).toInt().toString();

  String _decimal(String key) =>
      ((_stats[key] as num?) ?? 0).toDouble().toStringAsFixed(3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.rateHz}Hz 단독 센서 측정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDims.screenPad),
          children: [
            Text(
              '다른 검증 센서는 실행하지 않고 ${widget.rateHz}Hz 요청만 단독으로 측정합니다.\n'
              'samplingPeriodUs=${widget.samplingPeriodUs}',
              style: AppText.body,
            ),
            const SizedBox(height: AppDims.gap2),
            _statsCard(),
            if (_savedPath != null) ...[
              const SizedBox(height: AppDims.gap2),
              _messageBox('파일 1개 저장됨', _savedPath!, AppColors.green),
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
                child: Text(
                  _running
                      ? '${widget.rateHz}Hz 단독 수신 중'
                      : '${widget.rateHz}Hz 측정 시작',
                ),
              ),
            ),
            const SizedBox(height: AppDims.gap),
            SizedBox(
              height: AppDims.buttonH,
              child: OutlinedButton(
                onPressed: _running && !_saving ? _stopAndExport : null,
                child: Text(_saving ? '파일 만드는 중…' : '측정 종료 및 파일 저장'),
              ),
            ),
            const SizedBox(height: AppDims.gap),
            SizedBox(
              height: AppDims.buttonH,
              child: ElevatedButton.icon(
                onPressed: _savedPath != null && !_emailSending
                    ? _sendEmail
                    : null,
                icon: const Icon(Icons.email_outlined),
                label: Text(_emailSending ? '메일 준비 중…' : '측정 파일 1개 이메일 보내기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsCard() {
    return Container(
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.rateHz}Hz 단독 요청 실시간 통계', style: AppText.bodyBold),
          const SizedBox(height: AppDims.gap),
          Text(
            '원본 개수  raw ${_integer('rawCount')} · '
            'gravity ${_integer('gravityCount')} · '
            'linear ${_integer('linearCount')}',
            style: AppText.body,
          ),
          Text(
            '실측 Hz  raw ${_decimal('rawHz')} · '
            'gravity ${_decimal('gravityHz')} · '
            'linear ${_decimal('linearHz')}',
            style: AppText.body,
          ),
          Text(
            'linear 간격  평균 ${_decimal('meanDtUs')}µs · '
            '최소 ${_decimal('minDtUs')}µs · 최대 ${_decimal('maxDtUs')}µs',
            style: AppText.body,
          ),
        ],
      ),
    );
  }

  Widget _messageBox(String title, String body, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDims.gap2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDims.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.bodyBold.copyWith(color: color)),
          const SizedBox(height: AppDims.gap),
          SelectableText(body, style: AppText.caption),
        ],
      ),
    );
  }
}
