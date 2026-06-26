import 'package:flutter/material.dart';

class PathPainter extends CustomPainter {
  final int gridSize;
  final Map<int, List<List<int>>> paths; // colorIndex → [[row,col], ...]
  final Map<int, Color> colorMap;
  final double cellSize;

  PathPainter({
    required this.gridSize,
    required this.paths,
    required this.colorMap,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in paths.entries) {
      final colorIndex = entry.key;
      final path = entry.value;
      if (path.length < 2) continue;

      final color = colorMap[colorIndex] ?? Colors.white;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = cellSize * 0.45
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final uiPath = Path();
      final first = _cellCenter(path[0][0], path[0][1]);
      uiPath.moveTo(first.dx, first.dy);
      for (int i = 1; i < path.length; i++) {
        final pt = _cellCenter(path[i][0], path[i][1]);
        uiPath.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(uiPath, paint);
    }
  }

  Offset _cellCenter(int row, int col) {
    return Offset(
      col * cellSize + cellSize / 2,
      row * cellSize + cellSize / 2,
    );
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) => true;
}
