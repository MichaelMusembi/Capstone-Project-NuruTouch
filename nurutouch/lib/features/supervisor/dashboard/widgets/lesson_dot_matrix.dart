import 'package:flutter/material.dart';
import '../../../../theme/colors.dart';

enum LessonStatus { passed, inProgress, notAttempted }

class LessonDotMatrix extends StatelessWidget {
  final List<LessonStatus> statuses;

  const LessonDotMatrix({super.key, required this.statuses});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _DotMatrixPainter(statuses: statuses),
        );
      },
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  final List<LessonStatus> statuses;

  _DotMatrixPainter({required this.statuses});

  @override
  void paint(Canvas canvas, Size size) {
    if (statuses.isEmpty) return;

    final double dotRadius = 4.0;
    final double spacing = 16.0;

    // Calculate how many columns can fit
    final int cols = (size.width / spacing).floor();
    if (cols <= 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < statuses.length; i++) {
      final int row = i ~/ cols;
      final int col = i % cols;

      final double x = col * spacing + dotRadius;
      final double y = row * spacing + dotRadius;

      // Stop drawing if we exceed height (optional, but good for bounding)
      if (y > size.height) break;

      switch (statuses[i]) {
        case LessonStatus.passed:
          paint.color = NuruColors.green;
          break;
        case LessonStatus.inProgress:
          paint.color = NuruColors.indigo;
          break;
        case LessonStatus.notAttempted:
          paint.color = Colors.grey.withValues(alpha: 0.3);
          break;
      }

      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) {
    return oldDelegate.statuses != statuses;
  }
}
