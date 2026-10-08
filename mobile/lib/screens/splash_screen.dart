import 'dart:async';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/file_intent_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();

    _handleNavigation();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleNavigation() async {
    // Show splash screen logo for 1.8 seconds
    final splashDelay = Future.delayed(const Duration(milliseconds: 1800));

    // Check saved session in parallel
    final savedUserFuture = _authService.getSavedSession();

    final results = await Future.wait([splashDelay, savedUserFuture]);
    final savedUser = results[1] as AuthUser?;

    if (!mounted) return;

    if (savedUser != null) {
      final incomingFile = FileIntentService.incomingFile.value;

      if (savedUser.isViewer &&
          incomingFile != null &&
          incomingFile.trim().isNotEmpty) {
        FileIntentService.clearIncomingFile();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, _, _) => DashboardScreen(
              user: savedUser,
              initialBackupPath: incomingFile,
            ),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, _, _) => DashboardScreen(user: savedUser),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, _, _) => const LoginScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing circular logo container
                Container(
                  width: 175,
                  height: 175,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.deepOrange.withAlpha(180),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withAlpha(100),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/Durgasevak.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'दुर्गसेवक',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'दुर्ग संवर्धन व व्यवस्थापन प्रणाली',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 36),

                // Subtle custom loading indicator
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.deepOrange.withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
