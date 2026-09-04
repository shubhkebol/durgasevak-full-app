import 'package:flutter/material.dart';

import 'database/database_service.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
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
      title: 'Durgasevak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();

  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoggingIn) return;

    final username = _usernameController.text.trim();

    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );

      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    final user = await _authService.login(username, password);

    if (!mounted) return;

    setState(() {
      _isLoggingIn = false;
    });

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid username or password')),
      );

      return;
    }

    /*
     * If the Viewer opened a Durgasevak backup
     * file before logging in, keep that file path
     * and pass it to Dashboard.
     *
     * Dashboard will then open Data Sync and
     * automatically import the received backup.
     */
    final incomingFile = FileIntentService.incomingFile.value;

    if (user.isViewer &&
        incomingFile != null &&
        incomingFile.trim().isNotEmpty) {
      FileIntentService.clearIncomingFile();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              DashboardScreen(user: user, initialBackupPath: incomingFile),
        ),
      );

      return;
    }

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DashboardScreen(user: user)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),

          /*
           * Full-screen Durgasevak logo/watermark.
           */
          IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.20,
                child: Image.asset(
                  'assets/images/'
                  'durgasevak_watermark.jpg',
                  width: screenWidth * 0.90,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 55),

                    /*
                     * Main Durgasevak logo.
                     *
                     * This replaces the need for
                     * separate Admin/Durgasevak
                     * profile images on the login.
                     */
                    Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/images/'
                          'durgasevak_watermark.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'DURGASEVAK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Management System',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),

                    const SizedBox(height: 28),

                    TextField(
                      controller: _usernameController,
                      enabled: !_isLoggingIn,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: _passwordController,
                      enabled: !_isLoggingIn,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: _isLoggingIn
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoggingIn ? null : _login,
                        child: _isLoggingIn
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
