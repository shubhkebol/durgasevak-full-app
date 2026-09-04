import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main black background.
        const ColoredBox(
          color: Colors.black,
        ),

        // Centered Durgasevak watermark.
        IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: 0.14,
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