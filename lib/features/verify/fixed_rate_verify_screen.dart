import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/measure/sample_rate.dart';
import '../../domain/repository/verify_export_repository.dart';
import '../../domain/verify_sensor_channel.dart';

/// 페이지 2: 1000µs(1ms)와 3000µs(3ms)를 동시에 받아 각각 256Hz로 가공한다.
class FixedRateVerifyScreen extends StatefulWidget {
  const FixedRateVerifyScreen({super.key});

  @override
  State<FixedRateVerifyScreen> createState() => _FixedRateVerifyScreenState();
}

class _FixedRateVerifyScreenState extends State<FixedRateVerifyScreen> {
  // 이 페이지는 1ms·3ms 전용 Android 파일/채널에만 연결된다.
  final _channel = VerifySensorChannel(VerifyMode.fixed);
  final _repository = VerifyExportRepository();
  StreamSubscription<dynamic>? _subscription;

  bool _running = false;
  bool _saving = false;
  Map<String, dynamic> _oneMsStats = const {};
  Map<String, dynamic> _threeMsStats = const {};
  List<String> _savedPaths = const [];
  String? _error;

  Future<void> _start() async {
    if (_running || _saving) return;
    setState(() {
      _running = true;
      _oneMsStats = const {};
      _threeMsStats = const {};
      _savedPaths = const [];
      _error = null;
    });
    try {
      _subscription = _channel.events.listen(_onEvent);
      await _channel.start();
    } catch (error) {
      await _subscription?.cancel();
      _subscription = null;
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
      // 1ms·3ms 네이티브 파일을 모두 닫은 결과를 먼저 받는다.
      final nativePaths = await _channel.stop();
      await _subscription?.cancel();
      _subscription = null;
      // 원본·256Hz 네 파일이 모두 준비된 경우에만 최종 이름으로 확정한다.
      final exported = await _repository.exportFixed(nativePaths);
      if (!mounted) return;
      setState(() {
        _running = false;
        _saving = false;
        _savedPaths = exported.files.map((file) => file.path).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '1ms·3ms 원본·256Hz 파일 4개 저장 완료\n${exported.directory.path}',
          ),
        ),
      );
    } catch (error) {
      await _subscription?.cancel();
      _subscription = null;
      if (!mounted) return;
      setState(() {
        _running = false;
        _saving = false;
        _error = '동시 출력 실패: $error';
      });
    }
  }

  void _onEvent(dynamic event) {
    if (!mounted || event is! Map) return;
    final stats = Map<String, dynamic>.from(event);
    switch (event['lane']) {
      case 'oneMs':
        setState(() => _oneMsStats = stats);
      case 'threeMs':
        setState(() => _threeMsStats = stats);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_running) _channel.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1ms · 3ms 센서 검증')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDims.screenPad),
          children: [
            Text(
              '같은 센서를 1000µs와 3000µs로 각각 요청하고, '
              '두 원본을 독립적으로 ${SampleRate.hz}Hz 보간합니다.',
              style: AppText.body,
            ),
            const SizedBox(height: AppDims.gap2),
            _statusCard('1ms 요청 · samplingPeriodUs=1000', _oneMsStats),
            const SizedBox(height: AppDims.gap),
            _statusCard('3ms 요청 · samplingPeriodUs=3000', _threeMsStats),
            if (_savedPaths.isNotEmpty) ...[
              const SizedBox(height: AppDims.gap2),
              _messageBox('파일 4개 저장됨', _savedPaths.join('\n'), AppColors.green),
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
                child: Text(_running ? '두 스트림 수신 중' : '1ms · 3ms 검증 시작'),
              ),
            ),
            const SizedBox(height: AppDims.gap),
            SizedBox(
              height: AppDims.buttonH,
              child: OutlinedButton(
                onPressed: _running && !_saving ? _stopAndExport : null,
                child: Text(_saving ? '파일 4개 만드는 중…' : '중지 및 파일 4개 출력'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String title, Map<String, dynamic> stats) {
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
          const SizedBox(height: AppDims.gap),
          _row(
            'raw / gravity / linear',
            '${integer('rawCount')} / '
                '${integer('gravityCount')} / ${integer('linearCount')}',
          ),
          _row('원본 linear Hz', decimal('rawHz')),
          _row('평균 간격', '${decimal('meanDtMs')} ms'),
          _row(
            '최소 / 최대',
            '${decimal('minDtMs')} / '
                '${decimal('maxDtMs')} ms',
          ),
          _row('가공 실측 Hz', decimal('resampledHz')),
          _row('256Hz 가공 개수', integer('resampledCount')),
          _row(
            '최근 linear XYZ',
            '${decimal('latestX')} / ${decimal('latestY')} / '
                '${decimal('latestZ')} mg',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
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
