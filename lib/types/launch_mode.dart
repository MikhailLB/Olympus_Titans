// ─────────────────────────────────────────────────────────────
//  LaunchMode — terminal decision of the gray-flow boot.
//
//   • idle    — fresh install, no decision recorded yet
//   • portal  — paid install, send user to the WebView portal
//   • arcade  — organic install, run the offline puzzle game
//
//  Persisted as a short token in LocalVault.  The vocabulary is
//  intentionally Olympus-themed so the SharedPreferences blob
//  doesn't visibly match any other gray-flow project.
// ─────────────────────────────────────────────────────────────

enum LaunchMode {
  idle('idle'),
  portal('portal'),
  arcade('arcade');

  final String token;
  const LaunchMode(this.token);

  static LaunchMode parse(String? raw) {
    if (raw == null) return LaunchMode.idle;
    return LaunchMode.values.firstWhere(
      (m) => m.token == raw,
      orElse: () => LaunchMode.idle,
    );
  }
}
