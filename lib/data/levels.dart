import '../models/level_data.dart';

// Color indices: 1=blue  2=green  3=orange  4=pink  5=violet  6=yellow
//
// Every level is manually verified: I trace each path and confirm
// no two paths share a cell and every endpoint pair can be connected.

const List<LevelData> kLevels = [

  // ══════════════════════════════════════════════════════════════
  //  LEVELS 1–4 : 4×4  (Beginner)
  //  Fully verified solution grids below each level.
  // ══════════════════════════════════════════════════════════════

  // Solution: 1 2 2 3 / 1 4 2 3 / 1 4 4 3 / 1 1 4 3
  LevelData(gridSize: 4, title: 'Mortal Path', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 3, col2: 1),
    EndpointPair(colorIndex: 2, row1: 0, col1: 1, row2: 1, col2: 2),
    EndpointPair(colorIndex: 3, row1: 0, col1: 3, row2: 3, col2: 3),
    EndpointPair(colorIndex: 4, row1: 1, col1: 1, row2: 3, col2: 2),
  ]),

  // Solution: 1 1 1 2 / 3 4 1 2 / 3 4 4 2 / 3 3 4 2
  LevelData(gridSize: 4, title: 'Bronze Trial', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 1, col2: 2),
    EndpointPair(colorIndex: 2, row1: 0, col1: 3, row2: 3, col2: 3),
    EndpointPair(colorIndex: 3, row1: 1, col1: 0, row2: 3, col2: 1),
    EndpointPair(colorIndex: 4, row1: 1, col1: 1, row2: 3, col2: 2),
  ]),

  // Solution: 1 2 3 3 / 1 2 4 5 / 1 2 4 5 / 1 4 4 5
  LevelData(gridSize: 4, title: 'Demi-God Rising', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 3, col2: 0),
    EndpointPair(colorIndex: 2, row1: 0, col1: 1, row2: 2, col2: 1),
    EndpointPair(colorIndex: 3, row1: 0, col1: 2, row2: 0, col2: 3),
    EndpointPair(colorIndex: 4, row1: 1, col1: 2, row2: 3, col2: 1),
    EndpointPair(colorIndex: 5, row1: 1, col1: 3, row2: 3, col2: 3),
  ]),

  // Solution: 1 1 2 3 / 4 1 2 3 / 4 5 2 3 / 4 5 5 3
  LevelData(gridSize: 4, title: "Nymph's Maze", pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 1, col2: 1),
    EndpointPair(colorIndex: 2, row1: 0, col1: 2, row2: 2, col2: 2),
    EndpointPair(colorIndex: 3, row1: 0, col1: 3, row2: 3, col2: 3),
    EndpointPair(colorIndex: 4, row1: 1, col1: 0, row2: 3, col2: 0),
    EndpointPair(colorIndex: 5, row1: 2, col1: 1, row2: 3, col2: 2),
  ]),

  // ══════════════════════════════════════════════════════════════
  //  LEVELS 5–10 : 5×5  (Intermediate)
  //  All paths verified: listed as traces below each level.
  // ══════════════════════════════════════════════════════════════

  // L5 – paths: B=col0, G=(0,2)→(0,4), O=(1,1)→(1,2)→(2,2)→(3,2),
  //             P=(1,3)→(2,3), V=(2,4)→(3,4)→(4,4), Y=(3,1)→(4,1)→(4,2)→(4,3)
  LevelData(gridSize: 5, title: 'Cyclops Cavern', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 4, col2: 0),
    EndpointPair(colorIndex: 2, row1: 0, col1: 2, row2: 0, col2: 4),
    EndpointPair(colorIndex: 3, row1: 1, col1: 1, row2: 3, col2: 2),
    EndpointPair(colorIndex: 4, row1: 1, col1: 3, row2: 2, col2: 3),
    EndpointPair(colorIndex: 5, row1: 2, col1: 4, row2: 4, col2: 4),
    EndpointPair(colorIndex: 6, row1: 3, col1: 1, row2: 4, col2: 3),
  ]),

  // L6 – border frame design, no crossing guaranteed.
  // B=(0,0)→(0,3), G=(0,4)→(3,4), O=(4,4)→(4,1), P=(4,0)→(1,0), V=(1,1)→(3,3)
  // V solution: (1,1)→(2,1)→(2,2)→(2,3)→(3,3)
  LevelData(gridSize: 5, title: "Medusa's Gaze", pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 0, col2: 3),
    EndpointPair(colorIndex: 2, row1: 0, col1: 4, row2: 3, col2: 4),
    EndpointPair(colorIndex: 3, row1: 4, col1: 4, row2: 4, col2: 1),
    EndpointPair(colorIndex: 4, row1: 4, col1: 0, row2: 1, col2: 0),
    EndpointPair(colorIndex: 5, row1: 1, col1: 1, row2: 3, col2: 3),
  ]),

  // L7 – border frame + inner.
  // B=(0,0)→(0,4), G=(1,0)→(4,0), O=(4,1)→(4,4), P=(1,4)→(3,4), V=(2,1)→(3,2)
  LevelData(gridSize: 5, title: "Minotaur's Labyrinth", pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 0, col2: 4),
    EndpointPair(colorIndex: 2, row1: 1, col1: 0, row2: 4, col2: 0),
    EndpointPair(colorIndex: 3, row1: 4, col1: 1, row2: 4, col2: 4),
    EndpointPair(colorIndex: 4, row1: 1, col1: 4, row2: 3, col2: 4),
    EndpointPair(colorIndex: 5, row1: 2, col1: 1, row2: 3, col2: 2),
  ]),

  // L8 – perimeter + inner.
  // B=(0,0)→(0,4), G=(1,0)→(4,0), O=(4,1)→(4,4), P=(1,4)→(3,4), V=(2,2)→(3,1)
  LevelData(gridSize: 5, title: "Hades' Underworld", pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 0, col2: 4),
    EndpointPair(colorIndex: 2, row1: 1, col1: 0, row2: 4, col2: 0),
    EndpointPair(colorIndex: 3, row1: 4, col1: 1, row2: 4, col2: 4),
    EndpointPair(colorIndex: 4, row1: 1, col1: 4, row2: 3, col2: 4),
    EndpointPair(colorIndex: 5, row1: 2, col1: 2, row2: 3, col2: 1),
  ]),

  // ══════════════════════════════════════════════════════════════
  //  LEVELS 9–10 : 6×6
  // ══════════════════════════════════════════════════════════════

  // L9 – border frame 6×6.
  // B=(0,0)→(0,5), G=(1,0)→(5,0), O=(5,1)→(5,5), P=(1,5)→(4,5), V=(2,1)→(4,4)
  LevelData(gridSize: 6, title: "Poseidon's Depths", pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 0, col2: 5),
    EndpointPair(colorIndex: 2, row1: 1, col1: 0, row2: 5, col2: 0),
    EndpointPair(colorIndex: 3, row1: 5, col1: 1, row2: 5, col2: 5),
    EndpointPair(colorIndex: 4, row1: 1, col1: 5, row2: 4, col2: 5),
    EndpointPair(colorIndex: 5, row1: 2, col1: 1, row2: 4, col2: 4),
  ]),

  // L10 – border + inner 6×6, 6 colours.
  // B=top row, G=left col, O=bottom row, P=right col,
  // V=(2,1)→(4,4), Y=(3,2)→(3,3)
  LevelData(gridSize: 6, title: "Zeus' Olympus", pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 0, col2: 5),
    EndpointPair(colorIndex: 2, row1: 1, col1: 0, row2: 4, col2: 0),
    EndpointPair(colorIndex: 3, row1: 5, col1: 0, row2: 5, col2: 5),
    EndpointPair(colorIndex: 4, row1: 1, col1: 5, row2: 4, col2: 5),
    EndpointPair(colorIndex: 5, row1: 2, col1: 1, row2: 4, col2: 4),
    EndpointPair(colorIndex: 6, row1: 3, col1: 2, row2: 3, col2: 3),
  ]),

  // ══════════════════════════════════════════════════════════════
  //  LEVELS 11–15 : 5×5  (Advanced – all verified)
  // ══════════════════════════════════════════════════════════════

  // L11 verified: B=(0,0)→(0,1)→(1,1), G=(0,2)→(1,2)→(2,2)→(2,1),
  // O=(0,3)→(0,4)→(1,4)→(2,4)→(3,4)→(4,4)→(4,3), P=(1,0)→(2,0)→(3,0)→(4,0)→(4,1)→(4,2),
  // V=(1,3)→(2,3)→(3,3)→(3,2)→(3,1)
  LevelData(gridSize: 5, title: 'Ares Forges', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 1, col2: 1),
    EndpointPair(colorIndex: 2, row1: 0, col1: 2, row2: 2, col2: 1),
    EndpointPair(colorIndex: 3, row1: 0, col1: 3, row2: 4, col2: 3),
    EndpointPair(colorIndex: 4, row1: 1, col1: 0, row2: 4, col2: 2),
    EndpointPair(colorIndex: 5, row1: 1, col1: 3, row2: 3, col2: 1),
  ]),

  // L12 verified: B=left col, G=(0,1)→(0,2)→(0,3)→(1,3),
  // O=(0,4)→(1,4)→(2,4)→(2,3), P=(1,1)→(1,2)→(2,2)→(3,2)→(3,3)→(3,4)→(4,4),
  // V=(2,1)→(3,1)→(4,1)→(4,2)→(4,3)
  LevelData(gridSize: 5, title: 'Apollo Ascends', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 4, col2: 0),
    EndpointPair(colorIndex: 2, row1: 0, col1: 1, row2: 1, col2: 3),
    EndpointPair(colorIndex: 3, row1: 0, col1: 4, row2: 2, col2: 3),
    EndpointPair(colorIndex: 4, row1: 1, col1: 1, row2: 4, col2: 4),
    EndpointPair(colorIndex: 5, row1: 2, col1: 1, row2: 4, col2: 3),
  ]),

  // L13 verified: B=(0,0)→(0,1)→(1,1), G=(0,2)→(0,3)→(1,3),
  // O=(0,4)→(1,4)→(2,4)→(3,4)→(4,4), P=(1,0)→(2,0)→(3,0)→(4,0)→(4,1),
  // V=(1,2)→(2,2)→(2,3)→(3,3)→(4,3), Y=(2,1)→(3,1)→(3,2)→(4,2)
  LevelData(gridSize: 5, title: 'Athena Weaves', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 1, col2: 1),
    EndpointPair(colorIndex: 2, row1: 0, col1: 2, row2: 1, col2: 3),
    EndpointPair(colorIndex: 3, row1: 0, col1: 4, row2: 4, col2: 4),
    EndpointPair(colorIndex: 4, row1: 1, col1: 0, row2: 4, col2: 1),
    EndpointPair(colorIndex: 5, row1: 1, col1: 2, row2: 4, col2: 3),
    EndpointPair(colorIndex: 6, row1: 2, col1: 1, row2: 4, col2: 2),
  ]),

  // L14 verified: B=(0,0)→(0,1)→(0,2)→(1,2), G=(0,3)→(0,4)→(1,4)→(2,4),
  // O=(1,0)→(2,0)→(3,0)→(4,0), P=(1,1)→(2,1)→(2,2)→(3,2),
  // V=(1,3)→(2,3)→(3,3)→(3,4)→(4,4), Y=(3,1)→(4,1)→(4,2)→(4,3)
  LevelData(gridSize: 5, title: 'Hermes Runs', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 1, col2: 2),
    EndpointPair(colorIndex: 2, row1: 0, col1: 3, row2: 2, col2: 4),
    EndpointPair(colorIndex: 3, row1: 1, col1: 0, row2: 4, col2: 0),
    EndpointPair(colorIndex: 4, row1: 1, col1: 1, row2: 3, col2: 2),
    EndpointPair(colorIndex: 5, row1: 1, col1: 3, row2: 4, col2: 4),
    EndpointPair(colorIndex: 6, row1: 3, col1: 1, row2: 4, col2: 3),
  ]),

  // L15 – border frame 5×5.
  // B=(0,0)→(0,4) top row, G=(1,4)→(3,4) right col,
  // O=(4,4)→(4,0) bottom row, P=(3,0)→(1,0) left col,
  // V=(1,1)→(3,3) inner: (1,1)→(2,1)→(2,2)→(2,3)→(3,3)
  LevelData(gridSize: 5, title: 'Artemis Hunts', pairs: [
    EndpointPair(colorIndex: 1, row1: 0, col1: 0, row2: 0, col2: 4),
    EndpointPair(colorIndex: 2, row1: 1, col1: 4, row2: 3, col2: 4),
    EndpointPair(colorIndex: 3, row1: 4, col1: 4, row2: 4, col2: 0),
    EndpointPair(colorIndex: 4, row1: 3, col1: 0, row2: 1, col2: 0),
    EndpointPair(colorIndex: 5, row1: 1, col1: 1, row2: 3, col2: 3),
  ]),
];
