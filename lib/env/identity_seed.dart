import '../cipher/scramble.dart';

// ─────────────────────────────────────────────────────────────
//  Identity seed — Chrome / WebKit fragments used by the
//  fabricated User-Agent string.
//
//  Keeping these scrambled stops scanners from grepping the
//  binary for a literal Chrome version number.
// ─────────────────────────────────────────────────────────────

const List<int> _chromeFragmentCipher = <int>[
  4, 90, 216, 146, 247, 49, 26, 64, 241, 67, 130, 134, 74, 124,
];

const List<int> _webkitFragmentCipher = <int>[
  0, 90, 221, 146, 244, 41,
];

String chromeFragment() => _chromeFragmentCipher.isEmpty
    ? '132.0.6834.163'
    : unscramble(_chromeFragmentCipher);

String webkitFragment() => _webkitFragmentCipher.isEmpty
    ? '537.36'
    : unscramble(_webkitFragmentCipher);
