// Encode plaintext secrets into Scramble byte lists.
// Run with:  dart run tool/forge_runes.dart
//
// Paste the printed `<int>[]` arrays into lib/env/*.dart files.
//
// Always use `dart run` — PowerShell loops overflow 32-bit ints
// on Windows and produce wrong byte values.
// ignore_for_file: avoid_print, avoid_relative_lib_imports
import 'package:olympus_titans/cipher/scramble.dart';

void main() {
  // Drop in the project URLs / dev keys here when re-encoding.
  final plaintext = <String, String>{
    'endpoint_host': 'https://olympustittans.com',
    'endpoint_path': '/config.php',
    'gcd_host': 'https://gcdsdk.appsflyer.com',
    'gcd_path': '/install_data/v4.0/',
    'chrome_fragment': '132.0.6834.163',
    'webkit_fragment': '537.36',
    // Pending: provided later by the operator.
    'attribution_dev_key': '',
    'messaging_project_id': '',
  };

  plaintext.forEach((label, value) {
    if (value.isEmpty) {
      print('// $label — empty (waiting for credentials)');
      print('const List<int> ${label}_bytes = <int>[];');
      print('');
      return;
    }
    final bytes = forge(value);
    print('// $label — "$value"');
    print('const List<int> ${label}_bytes = <int>[${bytes.join(', ')}];');
    print('');
  });
}
