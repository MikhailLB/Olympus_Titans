import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../env/titan_facade.dart';
import '../types/launch_mode.dart';

// ─────────────────────────────────────────────────────────────
//  LocalVault — persistence layer for the gray flow.
//
//  Sensitive blobs (portal URL, queued push URL) live in
//  flutter_secure_storage (Keystore on Android).
//
//  Soft state (launch mode, opt-in skip window, OS-denied flag,
//  expiry timestamp) lives in SharedPreferences.
//
//  Key vocabulary is intentionally Olympus-flavored to avoid
//  matching the SharedPrefs blob of any other gray-flow project.
// ─────────────────────────────────────────────────────────────

class LocalVault {
  // Soft-state keys
  static const String _kMode = 'ot_launch_mode';
  static const String _kExpiry = 'ot_portal_expiry';
  static const String _kOptInSkipUntil = 'ot_optin_skip_until';
  static const String _kOptInGranted = 'ot_optin_granted';
  static const String _kOptInOsDenied = 'ot_optin_os_denied';

  // Secret-state keys
  static const String _kPortalUrl = 'ot_secret_portal';
  static const String _kQueuedPush = 'ot_secret_push';

  final FlutterSecureStorage _safe = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  Future<void> warmUp() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── launch mode ─────────────────────────────────────────
  LaunchMode currentMode() => LaunchMode.parse(_prefs.getString(_kMode));

  Future<void> recordMode(LaunchMode mode) =>
      _prefs.setString(_kMode, mode.token);

  // ── portal url & expiry ─────────────────────────────────
  Future<String?> readPortalUrl() => _safe.read(key: _kPortalUrl);
  Future<void> writePortalUrl(String url) =>
      _safe.write(key: _kPortalUrl, value: url);

  int? expiryTimestamp() => _prefs.getInt(_kExpiry);
  Future<void> recordExpiry(int unixSeconds) =>
      _prefs.setInt(_kExpiry, unixSeconds);
  bool isPortalExpired() {
    final until = expiryTimestamp();
    if (until == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= until;
  }

  // ── push opt-in flow ────────────────────────────────────
  bool optInGranted() => _prefs.getBool(_kOptInGranted) ?? false;
  Future<void> markOptInGranted(bool value) =>
      _prefs.setBool(_kOptInGranted, value);

  /// Pitfall fix (guide §"Push notifications"): once the OS dialog
  /// is denied it cannot be re-shown.  We record that fact so the
  /// opt-in screen never re-surfaces in vain.
  bool optInOsDenied() => _prefs.getBool(_kOptInOsDenied) ?? false;
  Future<void> markOptInOsDenied() =>
      _prefs.setBool(_kOptInOsDenied, true);

  int? optInSkipUntil() => _prefs.getInt(_kOptInSkipUntil);
  Future<void> scheduleSkip({Duration? duration}) {
    final cooldown = duration ?? TitanFacade.optInCooldown;
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        cooldown.inSeconds;
    return _prefs.setInt(_kOptInSkipUntil, until);
  }

  bool shouldShowOptIn() {
    if (optInGranted()) return false;
    if (optInOsDenied()) return false;
    final until = optInSkipUntil();
    if (until == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= until;
  }

  // ── one-shot push url ───────────────────────────────────
  Future<void> stashPushUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _safe.delete(key: _kQueuedPush);
    } else {
      await _safe.write(key: _kQueuedPush, value: url);
    }
  }

  Future<String?> popPushUrl() async {
    final value = await _safe.read(key: _kQueuedPush);
    if (value != null) {
      await _safe.delete(key: _kQueuedPush);
    }
    return value;
  }
}
