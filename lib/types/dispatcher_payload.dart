// Backend response envelope for POST {dispatcher_endpoint}.
//
//  Success (portal): { "ok": true,  "url": "...", "expires": 173... }
//  Success (arcade): { "ok": false, "message": "organic" }
//  Local error:       allowed   = false, hint = error description
//
//  Implemented as an immutable record-style class rather than a
//  Map<String, dynamic> so callers can't mutate it post-decode.

final class DispatcherPayload {
  final bool allowed;
  final String? destination;
  final int? expiresAt;
  final String? hint;

  const DispatcherPayload({
    required this.allowed,
    this.destination,
    this.expiresAt,
    this.hint,
  });

  factory DispatcherPayload.fromJson(Map<String, dynamic> raw) {
    return DispatcherPayload(
      allowed: raw['ok'] == true,
      destination: raw['url'] as String?,
      expiresAt: raw['expires'] is int ? raw['expires'] as int : null,
      hint: raw['message'] as String?,
    );
  }

  factory DispatcherPayload.broken(String hint) =>
      DispatcherPayload(allowed: false, hint: hint);

  bool get hasDestination =>
      allowed && destination != null && destination!.isNotEmpty;
}
