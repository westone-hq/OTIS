import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/sensor_sample.dart';
import '../models/vibration_result.dart';
import '../services/vibration_analyzer.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  final VibrationAnalyzer _analyzer = VibrationAnalyzer();
  final List<SensorSample> _samples = [];

  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  Timer? _countdownTimer;
  Timer? _elapsedTimer;

  bool _isCountingDown = false;
  bool _isMeasuring = false;
  int _countdownSeconds = 5;
  Duration _elapsed = Duration.zero;
  DateTime? _measurementStartedAt;

  double _currentX = 0;
  double _currentY = 0;
  double _currentZ = 0;
  VibrationResult? _result;
  String? _errorMessage;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _sensorSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _sensorSubscription?.cancel();

    setState(() {
      _samples.clear();
      _result = null;
      _errorMessage = null;
      _elapsed = Duration.zero;
      _countdownSeconds = 5;
      _isCountingDown = true;
      _isMeasuring = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds <= 1) {
        timer.cancel();
        unawaited(_startMeasurement());
        return;
      }

      setState(() {
        _countdownSeconds -= 1;
      });
    });
  }

  Future<void> _startMeasurement() async {
    await WakelockPlus.enable();

    _measurementStartedAt = DateTime.now();
    setState(() {
      _isCountingDown = false;
      _isMeasuring = true;
      _elapsed = Duration.zero;
    });

    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final startedAt = _measurementStartedAt;
      if (startedAt == null || !_isMeasuring) {
        return;
      }

      setState(() {
        _elapsed = DateTime.now().difference(startedAt);
      });
    });

    _sensorSubscription =
        userAccelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          (event) {
            final sample = SensorSample(
              timestamp: DateTime.now(),
              x: event.x,
              y: event.y,
              z: event.z,
            );

            setState(() {
              _samples.add(sample);
              _currentX = event.x;
              _currentY = event.y;
              _currentZ = event.z;
            });
          },
          onError: (Object error) {
            setState(() {
              _errorMessage = '센서 데이터를 읽을 수 없습니다: $error';
            });
          },
        );
  }

  Future<void> _stopMeasurement() async {
    _elapsedTimer?.cancel();
    await _sensorSubscription?.cancel();
    await WakelockPlus.disable();

    setState(() {
      _isMeasuring = false;
      _measurementStartedAt = null;
    });

    try {
      final result = _analyzer.analyze(_samples);
      setState(() {
        _result = result;
        _errorMessage = null;
      });
    } on Object catch (error) {
      setState(() {
        _result = null;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('엘리베이터 진동 측정')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGuideCard(),
              const SizedBox(height: 12),
              _buildCurrentSensorCard(),
              const SizedBox(height: 12),
              _buildControlCard(),
              const SizedBox(height: 12),
              if (_errorMessage != null) _buildErrorCard(_errorMessage!),
              if (_result != null) _buildResultCard(_result!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '측정 안내',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('휴대폰을 엘리베이터 카 바닥에 단단히 고정해서 놓으세요.'),
            Text('스마트폰 Y축 방향이 출입구 방향 기준에 맞도록 배치하세요.'),
            Text('측정 시작 직후 1초는 기준 보정 구간으로 사용됩니다.'),
            Text('측정 중에는 휴대폰을 들거나 움직이지 마세요.'),
            Text('결과는 화면에만 표시되며 Raw data 파일은 저장하지 않습니다.'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSensorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '현재 사용자 가속도',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildAxisText('X', _currentX),
            _buildAxisText('Y', _currentY),
            _buildAxisText('Z', _currentZ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard() {
    final elapsedSeconds = (_elapsed.inMilliseconds / 1000).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isMeasuring
                  ? '측정 중: $elapsedSeconds초'
                  : _isCountingDown
                  ? '측정 시작까지 $_countdownSeconds초'
                  : '대기 중',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('저장된 샘플 수: ${_samples.length}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_isMeasuring || _isCountingDown)
                  ? null
                  : _startCountdown,
              child: const Text('측정 시작'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isMeasuring
                  ? () => unawaited(_stopMeasurement())
                  : null,
              child: const Text('측정 종료'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(VibrationResult result) {
    final gradeColor = _gradeColor(result.overallGrade);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '승차감 측정 리포트',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: gradeColor),
                  ),
                  child: Text(
                    result.overallGrade,
                    style: TextStyle(
                      color: gradeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              result.usedDetectedRideSegment
                  ? '주행 시작/종료 자동 검출 구간 기준'
                  : '주행 구간 검출이 어려워 전체 구간 기준',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            Text(
              '첫 1초 기준값 제거 + 3-sample 이동평균 적용',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            _buildReportHeader(),
            const Divider(height: 18),
            _buildAxisReportRow(
              axis: 'X',
              result: result.xRide,
              warning: result.isXWarning,
            ),
            _buildAxisReportRow(
              axis: 'Y',
              result: result.yRide,
              warning: result.isYWarning,
            ),
            _buildAxisReportRow(
              axis: 'Z',
              result: result.zRide,
              warning: result.isZWarning,
            ),
            const SizedBox(height: 14),
            _buildSummaryBox(result),
            const SizedBox(height: 8),
            Text(
              '참고: Max P-P는 순간 참고값이고, 판정은 A95 P-P 중심입니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: Colors.red.shade900)),
      ),
    );
  }

  Widget _buildAxisText(String axis, double value) {
    return Text('$axis: ${value.toStringAsFixed(4)} m/s²');
  }

  Widget _buildReportHeader() {
    return const Row(
      children: [
        SizedBox(
          width: 42,
          child: Text('축', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(
            'Max P-P',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            'A95 P-P',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            '판정',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAxisReportRow({
    required String axis,
    required AxisRideResult result,
    bool warning = false,
  }) {
    final color = warning ? Colors.red.shade800 : Colors.green.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '$axis축',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              '${result.maxPeakToPeakMg.toStringAsFixed(2)} mg',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: warning ? Colors.red.shade800 : null,
                fontWeight: warning ? FontWeight.bold : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${result.a95PeakToPeakMg.toStringAsFixed(2)} mg',
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              warning ? '주의' : '양호',
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(VibrationResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('측정 요약', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('전체 샘플 수: ${result.sampleCount}'),
          Text('리포트 계산 샘플 수: ${result.reportSampleCount}'),
          Text(
            '리포트 계산 시간: ${result.reportDurationSeconds.toStringAsFixed(1)}초',
          ),
          Text('RMS: ${result.rmsMg.toStringAsFixed(2)} mg'),
          Text('A95 진동값: ${result.a95Mg.toStringAsFixed(2)} mg'),
          Text('최대 진동값: ${result.maxVibrationMg.toStringAsFixed(2)} mg'),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case '양호':
        return Colors.green.shade700;
      case '주의':
        return Colors.orange.shade800;
      default:
        return Colors.red.shade800;
    }
  }
}
