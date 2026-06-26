import 'attribution_keys.dart';
import 'endpoint_seed.dart';
import 'legal_urls.dart';

// ─────────────────────────────────────────────────────────────
//  TitanFacade — single source of truth for app-level constants.
//
//  All secrets resolve lazily through the scrambled vectors so
//  no plain credentials end up in the compiled binary.
// ─────────────────────────────────────────────────────────────

abstract final class TitanFacade {
  TitanFacade._();

  // Identity ────────────────────────────────────────────────
  static const String packageRef = 'com.titanlight.olympustitans';
  static const String storeRef = 'com.titanlight.olympustitans';
  static const String productName = 'OlympusTitans';

  /// AppsFlyer iOS App Store numeric id (not used on Android).
  static const String iosStoreNumeric = '';

  // Endpoints ───────────────────────────────────────────────
  static String get dispatcherEndpoint => dispatcherUrl();
  static String get devKey => revealDevKey();
  static String get messagingSender => revealMessagingProjectId();

  static String get privacyPageUrl => privacyEndpoint;
  static String get supportPageUrl => supportEndpoint;
  static String get sitePageUrl => siteEndpoint;

  // Behaviour ───────────────────────────────────────────────
  /// "Skip" cooldown for the push opt-in screen — 3 days, per TZ.
  static const Duration optInCooldown = Duration(days: 3);

  /// Backoff before retrying attribution via GCD when AppsFlyer
  /// returns the false-Organic flag on first launch.
  static const Duration organicRecheck = Duration(seconds: 5);

  /// Hard timeout for the very first attribution wait.
  static const Duration firstAttributionTimeout = Duration(seconds: 30);

  /// Shorter timeout used for warm starts.
  static const Duration warmAttributionTimeout = Duration(seconds: 10);

  /// DNS probe timeout used by NetSensor.
  static const Duration dnsProbeTimeout = Duration(seconds: 7);

  /// Connectivity-drop debounce before navigating to OfflineNotice.
  static const Duration offlineDebounce = Duration(milliseconds: 700);

  /// Dispatcher (POST /config.php) overall timeout.
  static const Duration dispatcherTimeout = Duration(seconds: 15);
}
