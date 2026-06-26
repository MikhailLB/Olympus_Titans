import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../env/attribution_keys.dart';
import '../env/titan_facade.dart';
import 'mobile_http_agent.dart';

// ─────────────────────────────────────────────────────────────
//  AttributionAgent — wraps the AppsFlyer SDK.
//
//  Behavioural notes (kept from the gray-flow guide):
//   • Attribution arrives via the onInstallConversionData callback
//     and may falsely fire with `af_status: "Organic"` for paid
//     installs.  We resolve that by waiting briefly then calling
//     the GCD endpoint and merging the freshly-returned dictionary.
//   • Deep-link payload (from OneLink resolves) is merged with
//     putIfAbsent so it never overwrites attribution fields with
//     the same key.
//   • Device-side fields (af_id, bundle_id, store_id, os, locale,
//     push_token, firebase_project_id) are appended last so the
//     server always receives them, even when the SDK times out.
//
//  Difference from the reference implementation:
//  the latest attribution state is exposed through a broadcast
//  StreamController instead of a Completer<Map> + flags, which
//  makes the "use the most recent successful payload" rule a
//  natural `last-event-wins` semantics.
// ─────────────────────────────────────────────────────────────

class AttributionAgent {
  AppsflyerSdk? _sdk;

  final StreamController<Map<String, dynamic>> _attributionStream =
      StreamController.broadcast();
  Map<String, dynamic>? _lastAttribution;
  Map<String, dynamic>? _lastDeepLink;
  Map<String, dynamic>? _lastAppOpen;
  bool _deepLinkSettled = false;
  bool _booted = false;

  Future<void> ignite() async {
    if (_booted) return;
    _booted = true;

    final key = TitanFacade.devKey;
    if (key.isEmpty) {
      // No credentials yet — emit empty attribution so callers
      // can move on without blocking on a 30 s timeout.
      _attributionStream.add(const <String, dynamic>{});
      _deepLinkSettled = true;
      return;
    }

    final options = AppsFlyerOptions(
      afDevKey: key,
      appId: TitanFacade.iosStoreNumeric,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    _sdk = AppsflyerSdk(options);

    _sdk!.onInstallConversionData(_handleConversion);
    _sdk!.onAppOpenAttribution((data) {
      _lastAppOpen = _extractPayload(data);
    });
    _sdk!.onDeepLinking((result) {
      final clickEvent = result.deepLink?.clickEvent;
      if (clickEvent != null) {
        _lastDeepLink = Map<String, dynamic>.from(clickEvent);
      }
      _deepLinkSettled = true;
    });

    try {
      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AttributionAgent] initSdk failed: $e');
    }
  }

  Future<void> _handleConversion(dynamic data) async {
    final payload = _extractPayload(data);
    if (payload['af_status'] == 'Organic') {
      await Future<void>.delayed(TitanFacade.organicRecheck);
      final retry = await _fetchGcdAttribution();
      _lastAttribution = retry ?? payload;
    } else {
      _lastAttribution = payload;
    }
    _attributionStream.add(_lastAttribution!);
  }

  Map<String, dynamic> _extractPayload(dynamic raw) {
    if (raw is Map) {
      final inner = raw['payload'];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  /// Awaits the first non-empty attribution dictionary.
  /// Returns `{}` after `timeout` so the boot pipeline can continue.
  Future<Map<String, dynamic>> awaitAttribution({Duration? timeout}) async {
    if (_lastAttribution != null) return _lastAttribution!;
    final budget = timeout ?? TitanFacade.firstAttributionTimeout;
    try {
      return await _attributionStream.stream
          .firstWhere((_) => true)
          .timeout(budget);
    } on TimeoutException {
      return <String, dynamic>{};
    }
  }

  Future<void> awaitDeepLink({Duration timeout = const Duration(seconds: 5)}) async {
    if (_deepLinkSettled) return;
    final start = DateTime.now();
    while (!_deepLinkSettled) {
      if (DateTime.now().difference(start) >= timeout) break;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  Future<String?> _appsFlyerUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchGcdAttribution() async {
    final key = TitanFacade.devKey;
    if (key.isEmpty) return null;
    final uid = await _appsFlyerUid();
    if (uid == null || uid.isEmpty) return null;
    final appId = Platform.isIOS
        ? TitanFacade.iosStoreNumeric
        : TitanFacade.packageRef;
    final url = buildGcdEndpoint(appId: appId, deviceId: uid);
    if (url.isEmpty) return null;
    try {
      final response = await mobileHttpAgent
          .get(Uri.parse(url), headers: {'authorization': 'Bearer $key'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AttributionAgent] GCD fetch failed: $e');
    }
    return null;
  }

  /// Assembles the JSON body sent to the dispatcher.
  ///
  /// Field order (matches the TZ):
  ///   1. attribution dictionary (verbatim, all keys)
  ///   2. deep link click event (putIfAbsent)
  ///   3. app-open attribution   (putIfAbsent)
  ///   4. device-side identifiers (always set, overwrite duplicates)
  Future<Map<String, dynamic>> describeForBackend({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_lastAttribution != null) body.addAll(_lastAttribution!);
    _lastDeepLink?.forEach((k, v) => body.putIfAbsent(k, () => v));
    _lastAppOpen?.forEach((k, v) => body.putIfAbsent(k, () => v));

    final uid = await _appsFlyerUid();
    body['af_id'] = uid ?? '';
    body['bundle_id'] = TitanFacade.packageRef;
    body['store_id'] = TitanFacade.storeRef;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final sender = TitanFacade.messagingSender;
    if (sender.isNotEmpty) {
      body['firebase_project_id'] = sender;
    }

    if (kDebugMode) {
      debugPrint('[AttributionAgent] body: ${jsonEncode(body)}');
    }
    return body;
  }
}
