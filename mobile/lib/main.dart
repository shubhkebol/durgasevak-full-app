import 'package:flutter/material.dart';

import 'database/database_service.dart';
import 'screens/splash_screen.dart';
import 'services/file_intent_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService.instance.database;
  await ThemeService.instance.init();

  final initialFile = await FileIntentService.getInitialFile();

  if (initialFile != null && initialFile.trim().isNotEmpty) {
    FileIntentService.incomingFile.value = initialFile;
  }

  FileIntentService.listen();

  runApp(const DurgasevakApp());
}

class DurgasevakApp extends StatelessWidget {
  const DurgasevakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'दुर्गसेवक',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
