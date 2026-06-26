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

class _BootOrchestratorState extends State<BootOrchestrator> {
  // Visible bar fill (0..1).  Walks smoothly up to [_kSlowCap] while
  // gray-flow work is in flight, then jumps to 1.0 only at the very
  // moment before we navigate away (per UX spec).
  static const double _kSlowCap = 0.88;
  static const Duration _kSlowTotal = Duration(milliseconds: 3600);

  double _progress = 0.0;
  bool _navigated = false;
  int _dotPhase = 0;
  Timer? _dotsTicker;
  Timer? _fillTicker;

  @override
  void initState() {
    super.initState();
    _startCosmetics();
    _kickoff();
  }

  @override
  void dispose() {
    widget.alerts.onTokenRotated = null;
    _dotsTicker?.cancel();
    _fillTicker?.cancel();
    super.dispose();
  }

  /// Drives the "Loading…" dots and the slow fill toward [_kSlowCap].
  /// The fill never exceeds the cap on its own — only [_finalizeFill]
  /// (called right before navigation) takes it to 1.0.
  void _startCosmetics() {
    _dotsTicker = Timer.periodic(const Duration(milliseconds: 460), (_) {
      if (mounted) setState(() => _dotPhase = (_dotPhase + 1) % 4);
    });

    const stepMs = 60;
    final steps = _kSlowTotal.inMilliseconds ~/ stepMs;
    _fillTicker = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      if (!mounted) return;
      final fraction = t.tick / steps;
      final next = (fraction * _kSlowCap).clamp(0.0, _kSlowCap);
      if (_progress < _kSlowCap) {
        setState(() => _progress = next);
      }
      if (t.tick >= steps) t.cancel();
    });
  }

  /// Called right before any push-replacement to flash the bar
  /// to 100% and give the eye a brief beat to register the change.
  Future<void> _finalizeFill() async {
    _fillTicker?.cancel();
    if (!mounted) return;
    setState(() => _progress = 1.0);
    await Future<void>.delayed(const Duration(milliseconds: 320));
  }

  Future<void> _kickoff() async {
    widget.alerts.onTokenRotated = _replayBackend;
    // AlertChannel.ignite() catches Firebase failures internally.
    await widget.alerts.ignite();

    final mode = widget.vault.currentMode();
    switch (mode) {
      case LaunchMode.arcade:
        // Small artificial pause so the bar visibly advances even
        // when nothing else needs to happen.
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _jumpToArcade();
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
    final live = await widget.netSensor.hasLink();
    if (!live) {
      await _jumpToOffline();
      return;
    }

    await widget.attribution.ignite();
    await Future.wait([
      widget.attribution.awaitAttribution(
        timeout: TitanFacade.firstAttributionTimeout,
      ),
      widget.attribution.awaitDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.describeForBackend(
      locale: locale,
      pushToken: widget.alerts.token,
    );
    final verdict = await widget.dispatcher.requestVerdict(body);

    if (verdict.hasDestination) {
      await widget.vault.recordMode(LaunchMode.portal);
      await _jumpToPortal(verdict.destination!);
      return;
    }

    await widget.vault.recordMode(LaunchMode.arcade);
    await _jumpToArcade();
  }

  Future<void> _flowReturningOnline() async {
    final live = await widget.netSensor.hasLink();
    if (!live) {
      await _jumpToOffline();
      return;
    }

    final pendingPush = await widget.vault.popPushUrl();
    if (pendingPush != null && pendingPush.isNotEmpty) {
      await _jumpToPortal(pendingPush);
      return;
    }

    final cached = await widget.dispatcher.cachedDestination();

    await widget.attribution.ignite();
    await Future.wait([
      widget.attribution.awaitAttribution(
        timeout: TitanFacade.warmAttributionTimeout,
      ),
      widget.attribution.awaitDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.describeForBackend(
      locale: locale,
      pushToken: widget.alerts.token,
    );
    final verdict = await widget.dispatcher.requestVerdict(body);

    if (verdict.hasDestination) {
      await _jumpToPortal(verdict.destination!);
      return;
    }
    if (cached != null && cached.isNotEmpty) {
      await _jumpToPortal(cached);
      return;
    }
    await _jumpToOffline();
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
    await _finalizeFill();
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

  Future<void> _jumpToArcade() async {
    if (_navigated) return;
    _navigated = true;
    await _finalizeFill();
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MenuScreen()),
    );
  }

  Future<void> _jumpToOffline() async {
    if (_navigated) return;
    _navigated = true;
    await _finalizeFill();
    if (!mounted) return;
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
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.08,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Loading$dots',
                        style: TextStyle(
                          color: const Color(0xFFFFE7A1),
                          fontSize: isLandscape ? 18 : 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                            Shadow(
                              color: Colors.black,
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Horizontal progress bar — grows STRICTLY left
                      // to right via AnimatedPositioned(left: 0, width:
                      // maxWidth * progress).  No symmetric gradient,
                      // no centered alignment.  Hits 100% only inside
                      // _finalizeFill() right before pushReplacement.
                      Container(
                        height: isLandscape ? 12 : 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(
                            color: const Color(0xFFC9A84C)
                                .withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final fillWidth =
                                  constraints.maxWidth * _progress;
                              return Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  AnimatedPositioned(
                                    duration:
                                        const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: fillWidth,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        // Strictly left → right gradient.
                                        // Brighter highlight on the
                                        // moving right edge.
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color(0xFFB8902F),
                                            Color(0xFFC9A84C),
                                            Color(0xFFFFE7A1),
                                          ],
                                          stops: [0.0, 0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isLandscape ? 20 : 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
