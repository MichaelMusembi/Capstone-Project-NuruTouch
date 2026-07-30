import 'package:flutter/material.dart';
import '../../../../theme/colors.dart';

class DotCell extends StatelessWidget {
  final List<int> targetDots;
  final List<int>? inputDots; // If provided, renders an error comparison
  final Color baseColor;
  final double dotSize;
  final double spacing;

  const DotCell({
    super.key,
    required this.targetDots,
    this.inputDots,
    this.baseColor = NuruColors.indigo,
    this.dotSize = 6.0,
    this.spacing = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    if (inputDots != null) {
      // Render comparison: Target [space] Input
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCell(targetDots, NuruColors.sage),
          SizedBox(width: dotSize * 2),
          _buildCell(inputDots!, NuruColors.coral),
        ],
      );
    }
    return _buildCell(targetDots, baseColor);
  }

  Widget _buildCell(List<int> activeDots, Color activeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(1, activeDots, activeColor),
            SizedBox(width: spacing),
            _buildDot(4, activeDots, activeColor),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(2, activeDots, activeColor),
            SizedBox(width: spacing),
            _buildDot(5, activeDots, activeColor),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(3, activeDots, activeColor),
            SizedBox(width: spacing),
            _buildDot(6, activeDots, activeColor),
          ],
        ),
      ],
    );
  }

  Widget _buildDot(int dotNumber, List<int> activeDots, Color activeColor) {
    bool isActive = activeDots.contains(dotNumber);
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? activeColor : activeColor.withValues(alpha: 0.15),
      ),
    );
  }
}
