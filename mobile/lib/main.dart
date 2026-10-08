import 'package:flutter/material.dart';

import 'database/database_service.dart';
import 'screens/splash_screen.dart';
import 'services/file_intent_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService.instance.database;

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
    return MaterialApp(
      title: 'दुर्गसेवक',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Mukta',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF171717),
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white54),
          prefixIconColor: Colors.white70,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white38),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.deepOrange),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
