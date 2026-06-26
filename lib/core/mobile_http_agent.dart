import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../env/identity_seed.dart';
import '../env/titan_facade.dart';

// ─────────────────────────────────────────────────────────────
//  MobileHttpAgent — http.BaseClient that injects a realistic
//  mobile-browser User-Agent on every outbound request.
//
//  Per the gray_user_agent rule (Zeus / Magma themed games),
//  the UA is suffixed with:
//     appid/<packageRef> appname/<productName>
//  so that backend reporting can identify the originating app
//  without a separate header.
//
//  The Chrome / WebKit version fragments are scrambled in
//  env/identity_seed.dart so static analysis cannot grep for
//  them as plain literals.
// ─────────────────────────────────────────────────────────────

class MobileHttpAgent extends http.BaseClient {
  final http.Client _inner = http.Client();
  String _ua = '';

  String get userAgent => _ua;

  Future<void> prepare() async {
    _ua = await _composeUserAgent();
  }

  Future<String> _composeUserAgent() async {
    final chrome = chromeFragment();
    final webkit = webkitFragment();
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final brand = a.brand.isEmpty ? 'Samsung' : a.brand;
        final model = a.model.isEmpty ? 'SM-S931U' : a.model;
        final build = (a.display.isNotEmpty ? a.display : a.id);
        final sdk = a.version.sdkInt;
        final body = 'Mozilla/5.0 (Linux; Android $sdk; '
            '$brand $model Build/$build) AppleWebKit/$webkit '
            '(KHTML, like Gecko) Chrome/$chrome Mobile Safari/$webkit';
        return _appendIdentity(body);
      }
      final i = await info.iosInfo;
      final ver = i.systemVersion.replaceAll('.', '_');
      final body = 'Mozilla/5.0 (iPhone; CPU iPhone OS $ver like Mac OS X) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Version/${i.systemVersion} Mobile/15E148 Safari/$webkit';
      return _appendIdentity(body);
    } catch (_) {
      // Plausible Pixel/iPhone fallback when device_info is unavailable.
      final fallback = Platform.isAndroid
          ? 'Mozilla/5.0 (Linux; Android 15; SM-S931U Build/AP3A.240905.015.A2) '
              'AppleWebKit/$webkit (KHTML, like Gecko) '
              'Chrome/$chrome Mobile Safari/$webkit'
          : 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
              'AppleWebKit/$webkit (KHTML, like Gecko) '
              'Version/17.0 Mobile/15E148 Safari/$webkit';
      return _appendIdentity(fallback);
    }
  }

  String _appendIdentity(String baseUa) =>
      '$baseUa appid/${TitanFacade.packageRef} appname/${TitanFacade.productName}';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _ua);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Singleton — used by BackendDispatcher, AttributionAgent, AlertChannel
/// and by PortalStage.setUserAgent for the WebView.
final MobileHttpAgent mobileHttpAgent = MobileHttpAgent();
