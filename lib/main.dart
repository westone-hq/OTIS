import 'package:flutter/material.dart';
import 'package:vibration_checker/adapter/auth_repository.dart';

import 'ui/core/router.dart';
import 'ui/core/theme.dart';

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
      title: 'OTIS 진동 측정',
      color: AppColors.bg,
      theme: buildAppTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
