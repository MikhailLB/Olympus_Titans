import 'package:flutter/material.dart';
import '../models/level_data.dart';
import 'path_painter.dart';

// Asset name for each color index
String runeAsset(int colorIndex) {
  switch (colorIndex) {
    case 1:
      return 'assets/blue.webp';
    case 2:
      return 'assets/green.webp';
    case 3:
      return 'assets/orange.webp';
    case 4:
      return 'assets/pink.webp';
    case 5:
      return 'assets/viol.webp';
    case 6:
      return 'assets/yellow.webp';
    default:
      return 'assets/blue.webp';
  }
}

const Map<int, Color> kRuneColors = {
  1: Color(0xFF4FC3F7),
  2: Color(0xFF66BB6A),
  3: Color(0xFFFF7043),
  4: Color(0xFFEC407A),
  5: Color(0xFFAB47BC),
  6: Color(0xFFFFCA28),
};

class GameBoard extends StatefulWidget {
  final LevelData level;
  final VoidCallback onWin;

  const GameBoard({super.key, required this.level, required this.onWin});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  // grid[row][col] = colorIndex (0 = empty)
  late List<List<int>> grid;

  // completed paths
  final Map<int, List<List<int>>> paths = {};

  // which color is currently being dragged
  int? activeColor;

  // endpoint lookup: "row,col" → colorIndex
  late Map<String, int> endpointMap;

  // second endpoint of active color
  late Map<int, List<int>> endpointA; // colorIndex → [row, col]
  late Map<int, List<int>> endpointB;

  @override
  void initState() {
    super.initState();
    _initLevel();
  }

  @override
  void didUpdateWidget(GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) _initLevel();
  }

  void _initLevel() {
    final n = widget.level.gridSize;
    grid = List.generate(n, (_) => List.filled(n, 0));
    paths.clear();
    endpointMap = {};
    endpointA = {};
    endpointB = {};
    activeColor = null;

    for (final pair in widget.level.pairs) {
      endpointMap['${pair.row1},${pair.col1}'] = pair.colorIndex;
      endpointMap['${pair.row2},${pair.col2}'] = pair.colorIndex;
      endpointA[pair.colorIndex] = [pair.row1, pair.col1];
      endpointB[pair.colorIndex] = [pair.row2, pair.col2];
      grid[pair.row1][pair.col1] = pair.colorIndex;
      grid[pair.row2][pair.col2] = pair.colorIndex;
    }
  }

  bool _isEndpoint(int row, int col) =>
      endpointMap.containsKey('$row,$col');

  // Clear path for a color and reset grid cells it occupied
  void _clearPath(int colorIndex) {
    final path = paths[colorIndex];
    if (path == null) return;
    for (final cell in path) {
      final r = cell[0];
      final c = cell[1];
      // Don't clear endpoints
      if (!_isEndpoint(r, c)) {
        grid[r][c] = 0;
      }
    }
    paths.remove(colorIndex);
  }

  void _onPanStart(DragStartDetails details, double cellSize) {
    final row = (details.localPosition.dy / cellSize).floor();
    final col = (details.localPosition.dx / cellSize).floor();
    final n = widget.level.gridSize;
    if (row < 0 || row >= n || col < 0 || col >= n) return;

    final cellColor = grid[row][col];
    if (cellColor == 0) return;

    setState(() {
      activeColor = cellColor;
      _clearPath(cellColor);

      // Start from whichever endpoint is closer
      final ep = _isEndpoint(row, col) ? [row, col] : null;
      if (ep != null) {
        paths[cellColor] = [
          [row, col]
        ];
        grid[row][col] = cellColor;
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details, double cellSize) {
    if (activeColor == null) return;
    final row = (details.localPosition.dy / cellSize).floor();
    final col = (details.localPosition.dx / cellSize).floor();
    final n = widget.level.gridSize;
    if (row < 0 || row >= n || col < 0 || col >= n) return;

    final currentPath = paths[activeColor!];
    if (currentPath == null || currentPath.isEmpty) return;

    final last = currentPath.last;
    if (last[0] == row && last[1] == col) return;

    // Must be adjacent
    final dr = (row - last[0]).abs();
    final dc = (col - last[1]).abs();
    if (dr + dc != 1) return;

    // Check if revisiting own path → truncate
    final visitedIdx = currentPath.indexWhere((c) => c[0] == row && c[1] == col);
    if (visitedIdx >= 0) {
      setState(() {
        // Remove cells after visitedIdx from grid
        for (int i = visitedIdx + 1; i < currentPath.length; i++) {
          final r = currentPath[i][0];
          final c = currentPath[i][1];
          if (!_isEndpoint(r, c)) grid[r][c] = 0;
        }
        currentPath.removeRange(visitedIdx + 1, currentPath.length);
      });
      return;
    }

    // Check if cell is occupied by another color
    final existingColor = grid[row][col];
    if (existingColor != 0 && existingColor != activeColor) {
      // Cannot overwrite another color's path (only endpoints)
      if (!_isEndpoint(row, col)) return;
      // If it's another color's endpoint, don't overwrite
      if (endpointMap['$row,$col'] != activeColor) return;
    }

    // Determine if we just reached the target endpoint BEFORE setState
    final a = endpointA[activeColor!]!;
    final b = endpointB[activeColor!]!;
    final startCell = currentPath.first;
    final isStartA = startCell[0] == a[0] && startCell[1] == a[1];
    final targetEndpoint = isStartA ? b : a;
    final reachedEnd =
        row == targetEndpoint[0] && col == targetEndpoint[1];

    setState(() {
      grid[row][col] = activeColor!;
      currentPath.add([row, col]);
      if (reachedEnd) activeColor = null;
    });

    // Check win OUTSIDE setState to avoid nested-setState bug
    if (reachedEnd) _checkWin();
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() {
      activeColor = null;
    });
  }

  bool _isPathComplete(int colorIndex) {
    final path = paths[colorIndex];
    if (path == null || path.length < 2) return false;
    final a = endpointA[colorIndex]!;
    final b = endpointB[colorIndex]!;
    final first = path.first;
    final last = path.last;
    final connectsAtoB =
        (first[0] == a[0] && first[1] == a[1] && last[0] == b[0] && last[1] == b[1]);
    final connectsBtoA =
        (first[0] == b[0] && first[1] == b[1] && last[0] == a[0] && last[1] == a[1]);
    return connectsAtoB || connectsBtoA;
  }

  void _checkWin() {
    // Win condition: ALL pairs connected (no fill requirement)
    for (final pair in widget.level.pairs) {
      if (!_isPathComplete(pair.colorIndex)) return;
    }
    // Use post-frame callback to safely call parent setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onWin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final cellSize = size / widget.level.gridSize;

        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, cellSize),
          onPanUpdate: (d) => _onPanUpdate(d, cellSize),
          onPanEnd: _onPanEnd,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                // Grid background
                CustomPaint(
                  size: Size(size, size),
                  painter: _GridPainter(
                    gridSize: widget.level.gridSize,
                    cellSize: cellSize,
                  ),
                ),
                // Paths
                CustomPaint(
                  size: Size(size, size),
                  painter: PathPainter(
                    gridSize: widget.level.gridSize,
                    paths: paths,
                    colorMap: kRuneColors,
                    cellSize: cellSize,
                  ),
                ),
                // Endpoints
                ..._buildEndpoints(cellSize),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildEndpoints(double cellSize) {
    final widgets = <Widget>[];
    for (final pair in widget.level.pairs) {
      for (final ep in [
        [pair.row1, pair.col1],
        [pair.row2, pair.col2]
      ]) {
        final row = ep[0];
        final col = ep[1];
        final color = kRuneColors[pair.colorIndex] ?? Colors.white;
        widgets.add(
          Positioned(
            left: col * cellSize + cellSize * 0.08,
            top: row * cellSize + cellSize * 0.08,
            width: cellSize * 0.84,
            height: cellSize * 0.84,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.25),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  runeAsset(pair.colorIndex),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _GridPainter extends CustomPainter {
  final int gridSize;
  final double cellSize;

  _GridPainter({required this.gridSize, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = const Color(0xFF0D1B2A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid lines
    final linePaint = Paint()
      ..color = const Color(0xFF1E3A5F)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= gridSize; i++) {
      final pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), linePaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), linePaint);
    }

    // Corner decorations
    final cornerPaint = Paint()
      ..color = const Color(0xFFC9A84C).withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    for (int r = 0; r <= gridSize; r++) {
      for (int c = 0; c <= gridSize; c++) {
        final x = c * cellSize;
        final y = r * cellSize;
        canvas.drawCircle(Offset(x, y), 3, cornerPaint..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
