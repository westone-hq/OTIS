import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration_checker/adapter/sensor_channel.dart';

import '../../core/theme.dart';

/// 작성: 2026-09-21 · 박희정
/// 클래스: _NoiseTestModeOption
/// 목적: 소음 테스트 4모드 UI 선택 항목
class _NoiseTestModeOption {
  final String id;
  final String label;
  final String detail;

  const _NoiseTestModeOption({
    required this.id,
    required this.label,
    required this.detail,
  });
}

const _kModes = <_NoiseTestModeOption>[
  _NoiseTestModeOption(
    id: 'rate40k',
    label: 'rate40k',
    detail: '요청 40 kHz · Fast 창 0.125초',
  ),
  _NoiseTestModeOption(
    id: 'rate80k',
    label: 'rate80k',
    detail: '요청 80 kHz · Fast 창 0.125초',
  ),
  _NoiseTestModeOption(
    id: 'aweight',
    label: 'aweight',
    detail: '요청 48 kHz · Fast + 근사 A가중',
  ),
  _NoiseTestModeOption(
    id: 'slow',
    label: 'slow',
    detail: '요청 48 kHz · Slow 창 1.0초',
  ),
];

/// 작성: 2026-09-21 · 박희정
/// 수정: 2026-09-21 · 박희정
/// 클래스: NoiseTestScreen
/// 목적: 소음(dB) 전용 테스트 화면. EVIMP1과 별개로
///       4모드(40k / 80k / A가중 / Slow창)를 골라 측정하고 CSV를 저장한다.
class NoiseTestScreen extends StatefulWidget {
  const NoiseTestScreen({super.key, this.sensorManager});

  final SensorChannelManager? sensorManager;

  @override
  State<NoiseTestScreen> createState() => _NoiseTestScreenState();
}

/// 작성: 2026-09-21 · 박희정
/// 클래스: _NoiseTestScreenState
/// 목적: 모드 선택·시작/정지·라이브 표시·4모드 연속 10초 실행을 관리한다.
class _NoiseTestScreenState extends State<NoiseTestScreen> {
  late final SensorChannelManager _sensors =
      widget.sensorManager ?? SensorChannelManager();

  String _selectedModeId = _kModes.first.id;
  bool _running = false;
  bool _batchRunning = false;
  String? _error;
  String? _lastFileName;
  final List<String> _batchFilePaths = [];

  double _dbLevel = 0;
  double _minDb = 0;
  double _avgDb = 0;
  double _maxDb = 0;
  int _elapsedMs = 0;
  int _requestedRate = 0;
  int _actualRate = 0;
  bool _aWeighting = false;

  StreamSubscription<Map<String, dynamic>>? _liveSub;

  @override
  void initState() {
    super.initState();
    _liveSub = _sensors.noiseTestStream.listen(_onLive);
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    if (_running) {
      unawaited(_sensors.stopNoiseTest());
    }
    super.dispose();
  }

  void _onLive(Map<String, dynamic> map) {
    if (!mounted) return;
    setState(() {
      _dbLevel = _asDouble(map['dbLevel']);
      _minDb = _asDouble(map['minDb']);
      _avgDb = _asDouble(map['avgDb']);
      _maxDb = _asDouble(map['maxDb']);
      _elapsedMs = _asInt(map['elapsedMs']);
      _requestedRate = _asInt(map['requestedSampleRate']);
      _actualRate = _asInt(map['actualSampleRate']);
      _aWeighting = map['aWeighting'] == true;
    });
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return 0;
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return 0;
  }

  /// 작성: 2026-09-21 · 박희정
  /// 함수: _start
  /// 목적: 선택한 모드로 소음 테스트를 시작한다.
  Future<void> _start() async {
    if (_running || _batchRunning) return;
    setState(() {
      _error = null;
      _lastFileName = null;
    });

    final granted = await _sensors.requestAudioPermission();
    if (!granted) {
      setState(() => _error = '마이크 권한이 필요합니다.');
      return;
    }

    final result = await _sensors.startNoiseTest(_selectedModeId);
    if (!mounted) return;
    if (result['ok'] != true) {
      setState(() => _error = (result['error'] as String?) ?? '시작 실패');
      return;
    }

    setState(() {
      _running = true;
      _requestedRate = _asInt(result['requestedSampleRate']);
      _actualRate = _asInt(result['actualSampleRate']);
      _aWeighting = result['aWeighting'] == true;
      _lastFileName = result['fileName'] as String?;
      _dbLevel = 0;
      _minDb = 0;
      _avgDb = 0;
      _maxDb = 0;
      _elapsedMs = 0;
    });
  }

  /// 작성: 2026-09-21 · 박희정
  /// 함수: _stop
  /// 목적: 소음 테스트를 멈추고 저장된 파일명을 반영한다.
  Future<void> _stop() async {
    if (!_running) return;
    final result = await _sensors.stopNoiseTest();
    if (!mounted) return;
    setState(() {
      _running = false;
      _lastFileName = result['fileName'] as String? ?? _lastFileName;
      if (result['ok'] != true) {
        _error = (result['error'] as String?) ?? '종료 실패';
      }
    });
  }

  /// 작성: 2026-09-21 · 박희정
  /// 함수: _runBatch10s
  /// 목적: 4모드를 순차적으로 각 10초씩 실행한다. 모드 사이에 반드시
  ///       stop해 마이크·파일 충돌을 피한다.
  Future<void> _runBatch10s() async {
    if (_running || _batchRunning) return;

    final granted = await _sensors.requestAudioPermission();
    if (!granted) {
      setState(() => _error = '마이크 권한이 필요합니다.');
      return;
    }

    setState(() {
      _batchRunning = true;
      _batchFilePaths.clear();
      _error = null;
    });

    for (final mode in _kModes) {
      if (!mounted) break;
      setState(() => _selectedModeId = mode.id);

      final start = await _sensors.startNoiseTest(mode.id);
      if (!mounted) break;
      if (start['ok'] != true) {
        setState(() {
          _error = '${mode.id}: ${(start['error'] as String?) ?? '시작 실패'}';
          _batchRunning = false;
        });
        return;
      }

      setState(() {
        _running = true;
        _requestedRate = _asInt(start['requestedSampleRate']);
        _actualRate = _asInt(start['actualSampleRate']);
        _aWeighting = start['aWeighting'] == true;
        _lastFileName = start['fileName'] as String?;
        _dbLevel = 0;
        _minDb = 0;
        _avgDb = 0;
        _maxDb = 0;
        _elapsedMs = 0;
      });

      await Future<void>.delayed(const Duration(seconds: 10));
      if (!mounted) break;

      final stop = await _sensors.stopNoiseTest();
      if (!mounted) break;
      setState(() => _running = false);

      final path = stop['filePath'] as String?;
      if (path != null && path.isNotEmpty) {
        _batchFilePaths.add(path);
      }
      setState(() {
        _lastFileName = stop['fileName'] as String? ?? _lastFileName;
      });

      // 모드 전환 전 짧게 대기해 마이크 해제 여유를 둔다
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;
    setState(() => _batchRunning = false);
  }

  bool get _rateMismatch =>
      _requestedRate > 0 &&
      _actualRate > 0 &&
      _requestedRate != _actualRate;

  @override
  Widget build(BuildContext context) {
    final busy = _running || _batchRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('소음(dB) 테스트')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDims.screenPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('측정 모드', style: AppText.bodyBold),
              const SizedBox(height: AppDims.gap),
              Wrap(
                spacing: AppDims.gap,
                runSpacing: AppDims.gap,
                children: _kModes.map((m) {
                  final selected = m.id == _selectedModeId;
                  return ChoiceChip(
                    label: Text(m.label, style: AppText.caption),
                    selected: selected,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => _selectedModeId = m.id),
                    selectedColor: AppColors.blue.withValues(alpha: 0.2),
                    labelStyle: AppText.caption.copyWith(
                      color: selected ? AppColors.navy : AppColors.text,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDims.gap),
              Text(
                _kModes
                    .firstWhere((m) => m.id == _selectedModeId)
                    .detail,
                style: AppText.caption,
              ),
              const SizedBox(height: AppDims.gap3),

              Container(
                padding: const EdgeInsets.all(AppDims.gap2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDims.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_dbLevel.toStringAsFixed(1)} dB',
                      style: AppText.bigNumber.copyWith(color: AppColors.navy),
                    ),
                    const SizedBox(height: AppDims.gap),
                    Text(
                      '경과 ${(_elapsedMs / 1000).toStringAsFixed(1)} 초',
                      style: AppText.body,
                    ),
                    const SizedBox(height: AppDims.gap2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('최소', _minDb),
                        _stat('평균', _avgDb),
                        _stat('최대', _maxDb),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDims.gap2),

              _infoRow('요청 샘플레이트', '$_requestedRate Hz'),
              _infoRow('실제 샘플레이트', '$_actualRate Hz'),
              _infoRow('A가중', _aWeighting ? '사용(근사)' : '없음'),
              if (_rateMismatch) ...[
                const SizedBox(height: AppDims.gap),
                Container(
                  padding: const EdgeInsets.all(AppDims.gap),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDims.radius),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.gold),
                      const SizedBox(width: AppDims.gap),
                      Expanded(
                        child: Text(
                          '이 기기는 요청 $_requestedRate Hz를 지원하지 않아 '
                          '실제 $_actualRate Hz로 측정합니다.',
                          style: AppText.caption.copyWith(color: AppColors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_lastFileName != null) ...[
                const SizedBox(height: AppDims.gap2),
                Text('마지막 저장 파일', style: AppText.bodyBold),
                const SizedBox(height: 4),
                Text(_lastFileName!, style: AppText.caption),
              ],
              if (_batchFilePaths.isNotEmpty) ...[
                const SizedBox(height: AppDims.gap2),
                Text('연속 측정 파일 (${_batchFilePaths.length})',
                    style: AppText.bodyBold),
                const SizedBox(height: 4),
                ..._batchFilePaths.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      p.split(RegExp(r'[/\\]')).last,
                      style: AppText.caption,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppDims.gap2),
                Text(
                  _error!,
                  style: AppText.body.copyWith(color: AppColors.red),
                ),
              ],
              const SizedBox(height: AppDims.gap3),

              SizedBox(
                height: AppDims.buttonH,
                child: ElevatedButton(
                  onPressed: busy
                      ? (_running && !_batchRunning ? _stop : null)
                      : _start,
                  child: Text(_running ? '정지' : '시작'),
                ),
              ),
              const SizedBox(height: AppDims.gap),
              SizedBox(
                height: AppDims.buttonH,
                child: OutlinedButton(
                  onPressed: busy ? null : _runBatch10s,
                  child: Text(
                    _batchRunning ? '연속 측정 중…' : '4모드 연속 10초',
                    style: AppText.button.copyWith(color: AppColors.navy),
                  ),
                ),
              ),
              const SizedBox(height: AppDims.gap2),
              Text(
                '파일은 앱 외부 저장소 noise_tests/ 아래에 저장됩니다. '
                'A가중은 근사 필터이며 실험실급이 아닙니다.',
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, double value) {
    return Column(
      children: [
        Text(label, style: AppText.caption),
        Text(value.toStringAsFixed(1), style: AppText.bodyBold),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDims.gap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body),
          Text(value, style: AppText.bodyBold),
        ],
      ),
    );
  }
}
