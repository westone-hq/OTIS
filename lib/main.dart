import 'package:flutter/material.dart';

import 'screens/measurement_screen.dart';

void main() {
  runApp(const OtisVibrationApp());
}

class OtisVibrationApp extends StatelessWidget {
  const OtisVibrationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTIS Vibration Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const MeasurementScreen(),
    );
  }
}
