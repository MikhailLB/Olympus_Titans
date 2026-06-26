import 'dart:convert';

import '../env/titan_facade.dart';
import '../types/dispatcher_payload.dart';
import 'local_vault.dart';
import 'mobile_http_agent.dart';

// ─────────────────────────────────────────────────────────────
//  BackendDispatcher — wraps the POST {dispatcher_endpoint}
//  call that returns either a portal URL or a "go offline" hint.
//
//  Side-effect: on a successful portal verdict it caches the URL
//  and expiry timestamp in LocalVault so subsequent boots can
//  short-circuit straight to PortalStage when the network is
//  briefly down.
// ─────────────────────────────────────────────────────────────

class BackendDispatcher {
  final LocalVault _vault;
  BackendDispatcher(this._vault);

  Future<DispatcherPayload> requestVerdict(Map<String, dynamic> body) async {
    final endpoint = TitanFacade.dispatcherEndpoint;
    if (endpoint.isEmpty) {
      return DispatcherPayload.broken('endpoint-unset');
    }

    try {
      final res = await mobileHttpAgent
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(TitanFacade.dispatcherTimeout);

      if (res.statusCode != 200) {
        return DispatcherPayload.broken('http-${res.statusCode}');
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return DispatcherPayload.broken('bad-shape');
      }

      final payload =
          DispatcherPayload.fromJson(Map<String, dynamic>.from(decoded));

      if (payload.hasDestination) {
        await _vault.writePortalUrl(payload.destination!);
        if (payload.expiresAt != null) {
          await _vault.recordExpiry(payload.expiresAt!);
        }
      }
      return payload;
    } catch (e) {
      return DispatcherPayload.broken(e.toString());
    }
  }

  /// Returns the cached portal URL — even if expired (better than
  /// showing nothing when the network just blinked).
  Future<String?> cachedDestination() => _vault.readPortalUrl();
}
