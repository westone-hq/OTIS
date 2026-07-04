import 'package:flutter/material.dart';
import 'package:vibration_checker/domain/auth_repository.dart';

import 'core/router.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthRepository.instance.getAutoLoginId();
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
