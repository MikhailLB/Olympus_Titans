import '../cipher/scramble.dart';

// ─────────────────────────────────────────────────────────────
//  Attribution & messaging credentials (scrambled).
//
//  Plain-text sources:
//    • Dev key — AppsFlyer dashboard → App Settings → Dev Key
//    • Project number — Firebase Console → Project Settings →
//                       General → "Project number" (the integer one)
//    • GCD URL parts — https://gcdsdk.appsflyer.com/install_data/v4.0/
//
//  Producing new ciphers:
//    1. Drop plaintext into `tool/forge_runes.dart`
//    2. `dart run tool/forge_runes.dart`
//    3. Paste the printed lists below
//
//  Empty cipher → caller treats the credential as absent and
//  the gray flow falls back to the offline (game) branch.
// ─────────────────────────────────────────────────────────────

const List<int> _devKeyCipher = <int>[
  // TODO: paste forged bytes once AppsFlyer issues the dev key.
];

const List<int> _projectIdCipher = <int>[
  // TODO: paste forged bytes once Firebase project is wired.
];

const List<int> _gcdHostCipher = <int>[
  93, 29, 158, 204, 180, 37, 3, 87, 165, 20, 200, 196, 24, 36, 70,
  49, 174, 220, 121, 25, 183, 155, 40, 149, 5, 249, 240, 48,
];

const List<int> _gcdPathCipher = <int>[
  26, 0, 132, 207, 179, 126, 64, 20, 157, 19, 205, 195, 29, 96, 30,
  100, 240, 156, 37,
];

/// AppsFlyer Dev Key.
String revealDevKey() =>
    _devKeyCipher.isEmpty ? '' : unscramble(_devKeyCipher);

/// Firebase messaging sender id (project number, numeric string).
String revealMessagingProjectId() =>
    _projectIdCipher.isEmpty ? '' : unscramble(_projectIdCipher);

/// Builds the GCD retry endpoint used when AppsFlyer initially returns
/// `af_status: "Organic"` for a paid install.
///
/// Format (AppsFlyer docs):
///   GET https://gcdsdk.appsflyer.com/install_data/v4.0/{app_id}?device_id={uid}
///   Authorization: Bearer {dev_key}
String buildGcdEndpoint({required String appId, required String deviceId}) {
  if (_gcdHostCipher.isEmpty) return '';
  final host = unscramble(_gcdHostCipher);
  final path = unscramble(_gcdPathCipher);
  return '$host$path$appId?device_id=$deviceId';
}
