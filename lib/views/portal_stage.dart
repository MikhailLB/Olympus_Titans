import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/alert_channel.dart';
import '../core/local_vault.dart';
import '../core/mobile_http_agent.dart';
import '../core/net_sensor.dart';
import 'offline_notice_view.dart';

// ─────────────────────────────────────────────────────────────
//  PortalStage — full-screen WebView shell.
//
//  Pitfall fixes incorporated:
//    • adjustResize in Manifest  +
//      resizeToAvoidBottomInset:false  +
//      visualViewport.resize JS scroll  → keyboard layout works
//    • behavior:'auto' (not 'smooth')   → no keyboard jitter
//    • Immediate loader overlay on any onWebResourceError so the
//      native Android error page never flashes through
//    • DNS/disconnect error codes short-circuit to the offline
//      screen directly (no redundant 7 s DNS probe)
//    • Debounced offline drop (700 ms) absorbs VPN flips
//    • Landscape adds left/right viewPadding for notched devices
//
//  Push warm-redirect: any incoming AlertChannel.onWarmDestination
//  re-loads the WebView with the new URL.
// ─────────────────────────────────────────────────────────────

Future<void> warmPortal() async {
  // Hook point for warming the WebView platform if needed.
}

class PortalStage extends StatefulWidget {
  final String destination;
  final LocalVault vault;
  final AlertChannel alerts;
  final NetSensor netSensor;

  const PortalStage({
    super.key,
    required this.destination,
    required this.vault,
    required this.alerts,
    required this.netSensor,
  });

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _ctrl;
  bool _spinning = true;
  bool _routedToOffline = false;
  StreamSubscription<bool>? _linkSub;
  String? _lastMainFrameUrl;
  int _redirectRecoveryCount = 0;

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersive();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyImmersive();
    _buildController();

    widget.alerts.onWarmDestination = (next) {
      if (mounted) _ctrl.loadRequest(Uri.parse(next));
    };

    _linkSub = widget.netSensor.debouncedDrops().listen((live) {
      if (!live) _bounceToOffline();
    });
  }

  void _buildController() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(mobileHttpAgent.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinning = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinning = false);
          _redirectRecoveryCount = 0;
          _injectSafeAreaPatch();
          _injectKeyboardPan();
        },
        onWebResourceError: _handleWebError,
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          final scheme = uri.scheme.toLowerCase();
          const inApp = {'http', 'https', 'about', 'data', 'blob'};
          if (inApp.contains(scheme)) {
            if (req.isMainFrame) _lastMainFrameUrl = req.url;
            return NavigationDecision.navigate;
          }
          _launchExternal(uri);
          return NavigationDecision.prevent;
        },
      ));

    _configureAndroidController();
    _ctrl.loadRequest(Uri.parse(widget.destination));
  }

  void _configureAndroidController() {
    if (!Platform.isAndroid) return;
    if (_ctrl.platform is! AndroidWebViewController) return;
    final aw = _ctrl.platform as AndroidWebViewController;
    aw.setMediaPlaybackRequiresUserGesture(false);
    aw.setOnShowFileSelector(_chooseFiles);
    final cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(aw, true);
  }

  // ── error handling (pitfall fix §"ERR_NAME_NOT_RESOLVED") ──
  Future<void> _handleWebError(WebResourceError err) async {
    if (err.isForMainFrame != true) return;

    final txt = err.description.toLowerCase();

    // Redirect-loop recovery first
    final isLoop = txt.contains('too_many_redirects') ||
        txt.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;
    if (isLoop &&
        _lastMainFrameUrl != null &&
        _redirectRecoveryCount < 3) {
      _redirectRecoveryCount++;
      _ctrl.loadRequest(Uri.parse(_lastMainFrameUrl!));
      return;
    }

    // Cover the WebView's native error page immediately so the
    // black-robot screen never shows through.
    if (mounted) setState(() => _spinning = true);

    final dnsHit = txt.contains('name_not_resolved') ||
        txt.contains('err_name_not_resolved') ||
        txt.contains('internet_disconnected') ||
        txt.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21;

    if (dnsHit) {
      _bounceToOffline();
      return;
    }
    _bounceToOfflineIfDown();
  }

  Future<void> _bounceToOfflineIfDown() async {
    if (_routedToOffline) return;
    final ok = await widget.netSensor.hasLink();
    if (ok || !mounted) return;
    await _bounceToOffline();
  }

  Future<void> _bounceToOffline() async {
    if (_routedToOffline || !mounted) return;
    _routedToOffline = true;

    // Preserve the URL the user was actually on when the link died,
    // not the initial destination, so Retry returns to that resource.
    String pendingUrl = widget.destination;
    try {
      final live = await _ctrl.currentUrl();
      if (live != null && live.isNotEmpty && !_isBlankUrl(live)) {
        pendingUrl = live;
      } else if (_lastMainFrameUrl != null && _lastMainFrameUrl!.isNotEmpty) {
        pendingUrl = _lastMainFrameUrl!;
      }
    } catch (_) {
      if (_lastMainFrameUrl != null && _lastMainFrameUrl!.isNotEmpty) {
        pendingUrl = _lastMainFrameUrl!;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OfflineNoticeView(
        rebuilder: (_) => PortalStage(
          destination: pendingUrl,
          vault: widget.vault,
          alerts: widget.alerts,
          netSensor: widget.netSensor,
        ),
      ),
    ));
  }

  bool _isBlankUrl(String u) {
    final s = u.trim().toLowerCase();
    return s.isEmpty || s == 'about:blank' || s.startsWith('data:text/html');
  }

  Future<List<String>> _chooseFiles(FileSelectorParams params) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (result == null) return const <String>[];
      return [
        for (final f in result.files)
          if (f.path != null) Uri.file(f.path!).toString(),
      ];
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── JS injections ───────────────────────────────────────
  void _injectKeyboardPan() {
    _ctrl.runJavaScript('''
(function(){
  if (window.__otKbBound) return;
  window.__otKbBound = true;
  var isInput = function(el){
    return !!el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
  };
  var pan = function(){
    var el = document.activeElement;
    if (!isInput(el)) return;
    var vp = window.visualViewport;
    if (vp) {
      var rect = el.getBoundingClientRect();
      var bottom = vp.offsetTop + vp.height;
      if (rect.bottom > bottom - 18 || rect.top < vp.offsetTop) {
        el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
      }
    } else {
      el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
    }
  };
  document.addEventListener('focusin', function(e){
    if (isInput(e.target)) setTimeout(pan, 350);
  });
  if (window.visualViewport) {
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if (h < prev) setTimeout(pan, 120);
      prev = h;
    });
  }
})();
''');
  }

  void _injectSafeAreaPatch() {
    _ctrl.runJavaScript(r'''
(function(){
  if (window.__otSaftyArea) return;
  window.__otSaftyArea = true;

  var STYLE_ID = '__ot_safearea';
  var STYLE_BODY =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
      '--safe-top:0px!important;--safe-right:0px!important;' +
      '--safe-bottom:0px!important;--safe-left:0px!important;' +
    '}' +
    '.gameview-mobile-header,.app-header{' +
      'padding-top:0!important;' +
    '}';

  function kbOpen(){
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }
  function apply(){
    if (kbOpen()) return;
    var head = document.head || document.documentElement;
    if (!head) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content') || '')) {
      var c = (meta.getAttribute('content') || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var node = document.getElementById(STYLE_ID);
    if (!node) {
      node = document.createElement('style');
      node.id = STYLE_ID;
      head.appendChild(node);
    }
    if (node.textContent !== STYLE_BODY) node.textContent = STYLE_BODY;
    if (head.lastElementChild !== node) head.appendChild(node);
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var orig = history[fn];
    history[fn] = function(){
      var r = orig.apply(this, arguments);
      setTimeout(apply, 80);
      setTimeout(apply, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(apply, 80); });
  setInterval(apply, 2500);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    widget.alerts.onWarmDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<bool> _onBack() async {
    if (await _ctrl.canGoBack()) {
      await _ctrl.goBack();
    }
    return false;
  }

  EdgeInsets _resolvePadding(BuildContext ctx) {
    final isLandscape =
        MediaQuery.of(ctx).orientation == Orientation.landscape;
    final vp = MediaQuery.of(ctx).viewPadding;
    if (isLandscape) {
      // Notch on the side — keep horizontal padding only.
      return EdgeInsets.only(left: vp.left, right: vp.right);
    }
    return EdgeInsets.only(top: vp.top);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: _resolvePadding(context),
              child: WebViewWidget(controller: _ctrl),
            ),
            if (_spinning)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFD466),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
