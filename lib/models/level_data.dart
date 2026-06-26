class EndpointPair {
  final int colorIndex; // 1-6
  final int row1, col1;
  final int row2, col2;

  const EndpointPair({
    required this.colorIndex,
    required this.row1,
    required this.col1,
    required this.row2,
    required this.col2,
  });
}

class LevelData {
  final int gridSize;
  final List<EndpointPair> pairs;
  final String title;

  const LevelData({
    required this.gridSize,
    required this.pairs,
    required this.title,
  });
}
