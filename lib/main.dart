import 'package:flutter/material.dart';

import 'core/router.dart';
import 'core/theme.dart';

void main() {
  runApp(const VibrationCheckerApp());
}

class VibrationCheckerApp extends StatelessWidget {
  const VibrationCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OTIS 진동측정',
      theme: buildAppTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
