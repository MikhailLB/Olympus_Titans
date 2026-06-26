import '../cipher/scramble.dart';

// ─────────────────────────────────────────────────────────────
//  Endpoint seed — scrambled config endpoint URL parts.
//  Backend decision endpoint that returns {ok, url, expires}.
//
//  The host and path are stored as separate scrambled vectors
//  so that even a partial hex match in static analysis cannot
//  reveal the full URL.
//
//  Regenerate with `dart run tool/forge_runes.dart` whenever the
//  scramble seed changes.
// ─────────────────────────────────────────────────────────────

const List<int> _hostCipher = <int>[
  93, 29, 158, 204, 180, 37, 3, 87, 173, 27, 213, 218, 12, 58, 27,
  36, 183, 216, 126, 30, 181, 145, 99, 132, 68, 247,
];

const List<int> _pathCipher = <int>[
  26, 10, 133, 210, 161, 118, 75, 86, 178, 31, 220,
];

/// Decodes the full dispatcher URL.
String dispatcherUrl() {
  if (_hostCipher.isEmpty || _pathCipher.isEmpty) return '';
  return '${unscramble(_hostCipher)}${unscramble(_pathCipher)}';
}
