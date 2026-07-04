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
              _errorMessage = '?쇱꽌 ?곗씠?곕? ?쎌쓣 ???놁뒿?덈떎: $error';
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
      appBar: AppBar(title: const Text('?섎━踰좎씠??吏꾨룞 痢≪젙')),
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
              '痢≪젙 ?덈궡',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('?대??곗쓣 ?섎━踰좎씠??移?諛붾떏???⑤떒??怨좎젙?댁꽌 ?볦쑝?몄슂.'),
            Text('?ㅻ쭏?명룿 Y異?諛⑺뼢??異쒖엯援?諛⑺뼢 湲곗???留욌룄濡?諛곗튂?섏꽭??'),
            Text('痢≪젙 ?쒖옉 吏곹썑 1珥덈뒗 湲곗? 蹂댁젙 援ш컙?쇰줈 ?ъ슜?⑸땲??'),
            Text('痢≪젙 以묒뿉???대??곗쓣 ?ㅺ굅???吏곸씠吏 留덉꽭??'),
            Text('寃곌낵???붾㈃?먮쭔 ?쒖떆?섎ŉ Raw data ?뚯씪? ??ν븯吏 ?딆뒿?덈떎.'),
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
              '?꾩옱 ?ъ슜??媛?띾룄',
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
                  ? '痢≪젙 以? $elapsedSeconds珥?
                  : _isCountingDown
                  ? '痢≪젙 ?쒖옉源뚯? $_countdownSeconds珥?
                  : '?湲?以?,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('??λ맂 ?섑뵆 ?? ${_samples.length}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_isMeasuring || _isCountingDown)
                  ? null
                  : _startCountdown,
              child: const Text('痢≪젙 ?쒖옉'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isMeasuring
                  ? () => unawaited(_stopMeasurement())
                  : null,
              child: const Text('痢≪젙 醫낅즺'),
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
                    '?뱀감媛?痢≪젙 由ы룷??,
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
                  ? '二쇳뻾 ?쒖옉/醫낅즺 ?먮룞 寃異?援ш컙 湲곗?'
                  : '二쇳뻾 援ш컙 寃異쒖씠 ?대젮???꾩껜 援ш컙 湲곗?',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            Text(
              '泥?1珥?湲곗?媛??쒓굅 + 3-sample ?대룞?됯퇏 ?곸슜',
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
              '李멸퀬: Max P-P???쒓컙 李멸퀬媛믪씠怨? ?먯젙? A95 P-P 以묒떖?낅땲??',
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
    return Text('$axis: ${value.toStringAsFixed(4)} m/s짼');
  }

  Widget _buildReportHeader() {
    return const Row(
      children: [
        SizedBox(
          width: 42,
          child: Text('異?, style: TextStyle(fontWeight: FontWeight.bold)),
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
            '?먯젙',
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
              '$axis異?,
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
              warning ? '二쇱쓽' : '?묓샇',
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
          const Text('痢≪젙 ?붿빟', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('?꾩껜 ?섑뵆 ?? ${result.sampleCount}'),
          Text('由ы룷??怨꾩궛 ?섑뵆 ?? ${result.reportSampleCount}'),
          Text(
            '由ы룷??怨꾩궛 ?쒓컙: ${result.reportDurationSeconds.toStringAsFixed(1)}珥?,
          ),
          Text('RMS: ${result.rmsMg.toStringAsFixed(2)} mg'),
          Text('A95 吏꾨룞媛? ${result.a95Mg.toStringAsFixed(2)} mg'),
          Text('理쒕? 吏꾨룞媛? ${result.maxVibrationMg.toStringAsFixed(2)} mg'),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case '?묓샇':
        return Colors.green.shade700;
      case '二쇱쓽':
        return Colors.orange.shade800;
      default:
        return Colors.red.shade800;
    }
  }
}
