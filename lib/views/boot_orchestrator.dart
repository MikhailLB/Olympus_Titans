import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/alert_channel.dart';
import '../core/attribution_agent.dart';
import '../core/backend_dispatcher.dart';
import '../core/local_vault.dart';
import '../core/net_sensor.dart';
import '../env/titan_facade.dart';
import '../screens/menu_screen.dart';
import '../types/launch_mode.dart';
import 'alert_optin_view.dart' deferred as optin;
import 'offline_notice_view.dart';
import 'portal_stage.dart' deferred as portal;

// ─────────────────────────────────────────────────────────────
//  BootOrchestrator — gray-flow entry point.
//
//  Visual: full-screen Olympus loading artwork (matches the
//  white side) with a thin amber progress arc and "Loading…"
//  caption.  Static webp/png — no video playback — so the
//  artefact fingerprint is distinct from other gray apps.
//
//  Routing:
//    LaunchMode.idle   ── first launch
//      • offline link  → OfflineNoticeView (retry → relaunch)
//      • online        → AttributionAgent → BackendDispatcher
//          ↳ portal verdict   → PortalStage (or AlertOptIn first)
//          ↳ arcade verdict   → MenuScreen (white game)
//    LaunchMode.portal ── returning paid user
//      • offline link  → OfflineNoticeView
//      • queued push   → PortalStage(pushUrl)   ★ priority
//      • otherwise     → AttributionAgent (warm timeout) →
//                        Dispatcher → PortalStage(url) (or cached)
//    LaunchMode.arcade ── returning organic user
//      • MenuScreen (no network required)
//
//  Portal entry imports are deferred to keep the WebView engine
//  out of the cold-start binary path for organic users.
// ─────────────────────────────────────────────────────────────

class BootOrchestrator extends StatefulWidget {
  final LocalVault vault;
  final NetSensor netSensor;
  final AttributionAgent attribution;
  final BackendDispatcher dispatcher;
  final AlertChannel alerts;

  const BootOrchestrator({
    super.key,
    required this.vault,
    required this.netSensor,
    required this.attribution,
    required this.dispatcher,
    required this.alerts,
  });

  @override
  State<BootOrchestrator> createState() => _BootOrchestratorState();
}

class _BootOrchestratorState extends State<BootOrchestrator>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  bool _navigated = false;
  int _dotPhase = 0;
  Timer? _dotsTicker;
  late AnimationController _haloCtrl;

  @override
  void initState() {
    super.initState();
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _dotsTicker = Timer.periodic(const Duration(milliseconds: 480), (_) {
      if (mounted) setState(() => _dotPhase = (_dotPhase + 1) % 4);
    });
    _kickoff();
  }

  @override
  void dispose() {
    widget.alerts.onTokenRotated = null;
    _dotsTicker?.cancel();
    _haloCtrl.dispose();
    super.dispose();
  }

  void _bumpProgress(double target) {
    if (!mounted) return;
    setState(() => _progress = target.clamp(0.05, 1.0));
  }

  Future<void> _kickoff() async {
    widget.alerts.onTokenRotated = _replayBackend;
    // AlertChannel.ignite() catches Firebase failures internally.
    await widget.alerts.ignite();

    final mode = widget.vault.currentMode();
    switch (mode) {
      case LaunchMode.arcade:
        _bumpProgress(0.65);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        _bumpProgress(1.0);
        await Future<void>.delayed(const Duration(milliseconds: 220));
        _jumpToArcade();
        return;
      case LaunchMode.portal:
        await _flowReturningOnline();
        return;
      case LaunchMode.idle:
        await _flowFirstRun();
        return;
    }
  }

  Future<void> _flowFirstRun() async {
    _bumpProgress(0.18);
    final live = await widget.netSensor.hasLink();
    if (!live) {
      _jumpToOffline();
      return;
    }

    _bumpProgress(0.35);
    await widget.attribution.ignite();
    await Future.wait([
      widget.attribution.awaitAttribution(
        timeout: TitanFacade.firstAttributionTimeout,
      ),
      widget.attribution.awaitDeepLink(),
    ]);

    _bumpProgress(0.7);
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.describeForBackend(
      locale: locale,
      pushToken: widget.alerts.token,
    );
    final verdict = await widget.dispatcher.requestVerdict(body);

    _bumpProgress(0.95);

    if (verdict.hasDestination) {
      await widget.vault.recordMode(LaunchMode.portal);
      _bumpProgress(1.0);
      await Future<void>.delayed(const Duration(milliseconds: 220));
      _jumpToPortal(verdict.destination!);
      return;
    }

    await widget.vault.recordMode(LaunchMode.arcade);
    _bumpProgress(1.0);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _jumpToArcade();
  }

  Future<void> _flowReturningOnline() async {
    _bumpProgress(0.2);
    final live = await widget.netSensor.hasLink();
    if (!live) {
      _jumpToOffline();
      return;
    }

    final pendingPush = await widget.vault.popPushUrl();
    if (pendingPush != null && pendingPush.isNotEmpty) {
      _bumpProgress(1.0);
      await Future<void>.delayed(const Duration(milliseconds: 220));
      _jumpToPortal(pendingPush);
      return;
    }

    final cached = await widget.dispatcher.cachedDestination();

    _bumpProgress(0.5);
    await widget.attribution.ignite();
    await Future.wait([
      widget.attribution.awaitAttribution(
        timeout: TitanFacade.warmAttributionTimeout,
      ),
      widget.attribution.awaitDeepLink(),
    ]);

    _bumpProgress(0.8);
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.describeForBackend(
      locale: locale,
      pushToken: widget.alerts.token,
    );
    final verdict = await widget.dispatcher.requestVerdict(body);

    _bumpProgress(1.0);
    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (verdict.hasDestination) {
      _jumpToPortal(verdict.destination!);
      return;
    }
    if (cached != null && cached.isNotEmpty) {
      _jumpToPortal(cached);
      return;
    }
    _jumpToOffline();
  }

  void _replayBackend(String newToken) async {
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.describeForBackend(
      locale: locale,
      pushToken: newToken,
    );
    await widget.dispatcher.requestVerdict(body);
  }

  // ── Navigation helpers ────────────────────────────────

  Future<void> _jumpToPortal(String url) async {
    if (_navigated) return;
    _navigated = true;
    await portal.loadLibrary();
    await portal.warmPortal();
    if (!mounted) return;

    if (widget.vault.shouldShowOptIn()) {
      await optin.loadLibrary();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => optin.AlertOptInView(
          vault: widget.vault,
          alerts: widget.alerts,
          netSensor: widget.netSensor,
          destination: url,
        ),
      ));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => portal.PortalStage(
          destination: url,
          vault: widget.vault,
          alerts: widget.alerts,
          netSensor: widget.netSensor,
        ),
      ));
    }
  }

  void _jumpToArcade() async {
    if (_navigated) return;
    _navigated = true;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MenuScreen()),
    );
  }

  void _jumpToOffline() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OfflineNoticeView(
        rebuilder: (_) => BootOrchestrator(
          vault: widget.vault,
          netSensor: widget.netSensor,
          attribution: widget.attribution,
          dispatcher: widget.dispatcher,
          alerts: widget.alerts,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final dots = '.' * _dotPhase;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            isLandscape
                ? 'assets/Horizontal_LoadingScreen.png'
                : 'assets/Vertical_LoadingScreen.png',
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(),
                  // Spinning halo with progress arc
                  SizedBox(
                    width: isLandscape ? 56 : 72,
                    height: isLandscape ? 56 : 72,
                    child: AnimatedBuilder(
                      animation: _haloCtrl,
                      builder: (_, __) => Transform.rotate(
                        angle: _haloCtrl.value * 6.2831853,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 4,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFD466),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Loading$dots',
                    style: TextStyle(
                      color: const Color(0xFFFFE7A1),
                      fontSize: isLandscape ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isLandscape ? 24 : 56),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
