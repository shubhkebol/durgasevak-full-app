import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Authentic WhatsApp logo widget
class WhatsAppIcon extends StatelessWidget {
  final double size;

  const WhatsAppIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _WhatsAppPainter());
  }
}

class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final center = Offset(radius, radius);

    // Green circular background
    final bgPaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, bgPaint);

    // Chat bubble with tail
    final bubbleRadius = radius * 0.68;
    final path = Path();
    path.addOval(Rect.fromCircle(center: center, radius: bubbleRadius));

    // Tail on bottom-left
    final tailStart = Offset(
      radius - bubbleRadius * 0.7,
      radius + bubbleRadius * 0.4,
    );
    final tailEnd = Offset(
      radius - bubbleRadius * 0.2,
      radius + bubbleRadius * 0.85,
    );
    final tailTip = Offset(
      radius - bubbleRadius * 0.95,
      radius + bubbleRadius * 0.95,
    );

    final tailPath = Path()
      ..moveTo(tailStart.dx, tailStart.dy)
      ..lineTo(tailTip.dx, tailTip.dy)
      ..lineTo(tailEnd.dx, tailEnd.dy)
      ..close();

    final bubbleCombined = Path.combine(PathOperation.union, path, tailPath);

    // Draw white outline of bubble
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(bubbleCombined, outlinePaint);

    // Draw phone receiver inside
    final iconSize = size.width * 0.48;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.phone.codePoint),
        style: TextStyle(
          inherit: false,
          color: Colors.white,
          fontSize: iconSize,
          fontFamily: Icons.phone.fontFamily,
          package: Icons.phone.fontPackage,
        ),
      ),
    );
    textPainter.layout();

    canvas.save();
    // Rotate slightly like whatsapp handset
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 16);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
