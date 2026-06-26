import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────
//  Scramble — string obfuscation primitive for Olympus Titans
// ─────────────────────────────────────────────────────────────
//  Sensitive strings (config host, attribution dev key, messaging
//  project ids, browser identifiers) are persisted as scrambled
//  byte lists instead of plain literals.
//
//  Algorithm:
//    1. A unique seed phrase is folded with FNV-1a (32-bit) to
//       produce a 32-bit digest.
//    2. The digest is expanded into a 24-byte rolling pad by
//       repeatedly multiplying with the FNV prime and rotating.
//    3. Each cipher byte is XORed with `pad[i % 24]`, plus a
//       per-index salt derived from a Mulberry32 generator
//       so identical bytes don't decode to the same value.
//
//  To re-encode after changing the seed, drive [forge] with the
//  same key over your plaintext.  See tool/forge_runes.dart.
//
//  This is NOT cryptography — it is a static-analysis defence
//  that keeps URLs and API keys out of `strings` dumps.
// ─────────────────────────────────────────────────────────────

const List<int> _seedBytes = <int>[
  // 'olympusbolt' — change me per project
  0x6F, 0x6C, 0x79, 0x6D, 0x70, 0x75, 0x73, 0x62, 0x6F, 0x6C, 0x74,
];

const int _padLength = 24;

Uint8List _bakePad() {
  // FNV-1a 32-bit
  var digest = 0x811C9DC5;
  for (final b in _seedBytes) {
    digest ^= b;
    digest = (digest * 0x01000193) & 0xFFFFFFFF;
  }

  final pad = Uint8List(_padLength);
  var state = digest == 0 ? 0xDEADBEEF : digest;
  for (var i = 0; i < _padLength; i++) {
    state = (state * 0x01000193 ^ (i + 0x9E37)) & 0xFFFFFFFF;
    final rot = (i * 5) & 0x1F;
    final mixed = ((state >> rot) | (state << (32 - rot))) & 0xFFFFFFFF;
    pad[i] = mixed & 0xFF;
  }
  return pad;
}

int _salt(int i) {
  // Mulberry32 — deterministic per-index salt
  var x = (0xB7E15163 + i * 0x9E3779B1) & 0xFFFFFFFF;
  x = ((x ^ (x >> 15)) * 0x85EBCA6B) & 0xFFFFFFFF;
  x = ((x ^ (x >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF;
  x = (x ^ (x >> 16)) & 0xFFFFFFFF;
  return x & 0xFF;
}

final Uint8List _pad = _bakePad();

/// Decodes a scrambled byte sequence back to UTF-8.
String unscramble(List<int> cipher) {
  if (cipher.isEmpty) return '';
  final out = Uint8List(cipher.length);
  for (var i = 0; i < cipher.length; i++) {
    out[i] = (cipher[i] ^ _pad[i % _padLength] ^ _salt(i)) & 0xFF;
  }
  return String.fromCharCodes(out);
}

/// Encoder used by tool scripts to produce the byte lists baked
/// into env/* files.  Symmetric with [unscramble].
List<int> forge(String plain) {
  final bytes = plain.codeUnits;
  final out = List<int>.filled(bytes.length, 0);
  for (var i = 0; i < bytes.length; i++) {
    out[i] = (bytes[i] ^ _pad[i % _padLength] ^ _salt(i)) & 0xFF;
  }
  return out;
}
