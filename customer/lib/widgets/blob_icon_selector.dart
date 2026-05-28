import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget con forma blob irregolare per icone di selezione
/// Ispirato al design di Glovo
class BlobIconSelector extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;
  final double size;

  const BlobIconSelector({
    super.key,
    required this.child,
    required this.isSelected,
    required this.onTap,
    this.selectedColor = const Color(0xFFFFD042), // Giallo accento default
    this.unselectedColor = const Color(0xFFE8E8E8), // Grigio chiaro
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        child: CustomPaint(
          painter: BlobPainter(
            color: isSelected ? selectedColor : unselectedColor,
            isSelected: isSelected,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: isSelected ? -0.15 : 0, // Rotazione leggera (~8.6 gradi)
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, angle, child) {
                  return Transform.rotate(angle: angle, child: child);
                },
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter per disegnare una forma blob irregolare
class BlobPainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  BlobPainter({required this.color, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = _createBlobPath(size);
    canvas.drawPath(path, paint);

    // Ombra se selezionato
    if (isSelected) {
      final shadowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, shadowPaint);
    }
  }

  /// Crea un path blob irregolare usando curve di Bézier
  /// Partendo da un cerchio, lo rende irregolare come nelle categorie
  Path _createBlobPath(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final centerY = height / 2;

    // Raggio base del cerchio
    final baseRadius = math.min(width, height) / 2.2;

    // Molti punti per forma fluida senza spigoli (come category screen)
    const numPoints = 24;
    final points = <Offset>[];

    // Crea un cerchio base e poi lo rende irregolare
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;

      // Piccole variazioni organiche per rendere il cerchio irregolare
      final noise1 = math.sin(angle * 2.3) * 0.035;
      final noise2 = math.cos(angle * 3.7) * 0.025;
      final noise3 = math.sin(angle * 5.1) * 0.015;

      final radiusVariation = 1.0 + noise1 + noise2 + noise3;
      final radius = baseRadius * radiusVariation;

      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      points.add(Offset(x, y));
    }

    // Inizio percorso
    path.moveTo(points[0].dx, points[0].dy);

    // Crea curve super fluide usando Catmull-Rom spline (come category screen)
    for (int i = 0; i < points.length; i++) {
      final p0 = points[(i - 1 + points.length) % points.length];
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final p3 = points[(i + 2) % points.length];

      // Calcola punti di controllo per Catmull-Rom spline (massima morbidezza)
      const tension = 0.5;

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6 * tension;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6 * tension;

      final cp2x = p2.dx - (p3.dx - p1.dx) / 6 * tension;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6 * tension;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant BlobPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected;
  }
}
