import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/file_intent_service.dart';
import '../widgets/admin_selection_sheet.dart';
import 'dashboard_screen.dart';

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
        const SnackBar(
          content: Text('कृपया वापरकर्ता नाव आणि पासवर्ड प्रविष्ट करा'),
        ),
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
        const SnackBar(content: Text('चुकीचे वापरकर्ता नाव किंवा पासवर्ड')),
      );
      return;
    }

    final incomingFile = FileIntentService.incomingFile.value;

    if (user.isViewer &&
        incomingFile != null &&
        incomingFile.trim().isNotEmpty) {
      FileIntentService.clearIncomingFile();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DashboardScreen(user: user, initialBackupPath: incomingFile),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 55),
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
                          'assets/images/durgasevak_watermark.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'दुर्गसेवक',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'व्यवस्थापन प्रणाली',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _usernameController,
                      enabled: !_isLoggingIn,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'वापरकर्ता नाव',
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
                        labelText: 'पासवर्ड',
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
                                'लॉगिन करा',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _isLoggingIn
                          ? null
                          : () => AdminSelectionSheet.show(
                              context,
                              viewerEmail: '',
                              isLoginScreen: true,
                            ),
                      icon: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                      label: const Text(
                        'अधिकृत ॲडमिन संपर्क (WhatsApp)',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
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
