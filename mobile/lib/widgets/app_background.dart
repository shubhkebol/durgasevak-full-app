import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background color adapted to current theme
        ColoredBox(color: theme.scaffoldBackgroundColor),

        // Centered Durgasevak watermark with contrast-aware opacity
        IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: isDark ? 0.14 : 0.05,
              child: Image.asset(
                'assets/images/durgasevak_watermark.jpg',
                width: MediaQuery.sizeOf(context).width * 0.82,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Screen content.
        child,
      ],
    );
  }
}
