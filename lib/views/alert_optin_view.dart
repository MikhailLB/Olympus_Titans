import 'package:flutter/material.dart';

import '../core/alert_channel.dart';
import '../core/local_vault.dart';
import '../core/net_sensor.dart';
import 'portal_stage.dart' deferred as portal;

// ─────────────────────────────────────────────────────────────
//  AlertOptInView — push permission promo.
//
//  Background art (per the assets pack):
//    portrait   assets/Notifications/Vertical_Notifications_Screen.png
//    landscape  assets/Notifications/Horizontal_Notifications_Screen.png
//
//  Two action buttons:
//    Accept → call AlertChannel.requestSystemPermission, then
//             advance to PortalStage.  If the user denied at the
//             OS level, the OS-denied flag is stored in LocalVault
//             so the screen never re-surfaces in vain.
//    Skip   → schedule a 3-day cooldown and advance.
//
//  The button design is deliberately different from the reference
//  template (Zeus-mythology blue-to-amber lightning, capsule
//  shape, top sheen).
// ─────────────────────────────────────────────────────────────

class AlertOptInView extends StatefulWidget {
  final LocalVault vault;
  final AlertChannel alerts;
  final NetSensor netSensor;
  final String destination;

  const AlertOptInView({
    super.key,
    required this.vault,
    required this.alerts,
    required this.netSensor,
    required this.destination,
  });

  @override
  State<AlertOptInView> createState() => _AlertOptInViewState();
}

class _AlertOptInViewState extends State<AlertOptInView> {
  bool _busy = false;

  Future<void> _onAccept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final granted = await widget.alerts.requestSystemPermission();
    if (!granted) {
      await widget.vault.scheduleSkip();
    }
    if (!mounted) return;
    await _forwardToPortal();
  }

  Future<void> _onSkip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.vault.scheduleSkip();
    if (!mounted) return;
    await _forwardToPortal();
  }

  Future<void> _forwardToPortal() async {
    await portal.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => portal.PortalStage(
        destination: widget.destination,
        vault: widget.vault,
        alerts: widget.alerts,
        netSensor: widget.netSensor,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final bg = isLandscape
        ? 'assets/Notifications/Horizontal_Notifications_Screen.png'
        : 'assets/Notifications/Vertical_Notifications_Screen.png';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.30),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: isLandscape ? size.height * 0.08 : size.height * 0.08,
            child: Center(
              child: SizedBox(
                width: isLandscape ? size.width * 0.42 : size.width * 0.78,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CapsuleAction(
                      label: 'Accept',
                      primary: true,
                      onTap: _busy ? null : _onAccept,
                    ),
                    const SizedBox(height: 12),
                    _CapsuleAction(
                      label: 'Skip',
                      primary: false,
                      onTap: _busy ? null : _onSkip,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapsuleAction extends StatefulWidget {
  final String label;
  final bool primary;
  final VoidCallback? onTap;
  const _CapsuleAction({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  State<_CapsuleAction> createState() => _CapsuleActionState();
}

class _CapsuleActionState extends State<_CapsuleAction>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _sheenCtrl;

  @override
  void initState() {
    super.initState();
    _sheenCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _sheenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: (_) => disabled ? null : setState(() => _pressed = true),
      onTapUp: (_) {
        if (disabled) return;
        setState(() => _pressed = false);
        widget.onTap!();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedBuilder(
          animation: _sheenCtrl,
          builder: (_, __) {
            final sheen = _sheenCtrl.value;
            final palette = widget.primary
                ? const [
                    Color(0xFF1E2B6F),
                    Color(0xFF3057E1),
                    Color(0xFF6CB2FF),
                  ]
                : const [
                    Color(0xFF1A1A2A),
                    Color(0xFF2A2A3F),
                    Color(0xFF3D3D55),
                  ];
            return Container(
              padding: EdgeInsets.symmetric(vertical: widget.primary ? 16 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: palette,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: const Color(0xFFFFE7A1).withValues(
                    alpha: widget.primary ? 0.85 : 0.45,
                  ),
                  width: widget.primary ? 1.6 : 1.0,
                ),
                boxShadow: widget.primary
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6CB2FF)
                              .withValues(alpha: 0.45 + sheen * 0.25),
                          blurRadius: 20 + sheen * 14,
                          spreadRadius: 1 + sheen * 2,
                        ),
                        const BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.primary
                        ? const Color(0xFFFFF5D9)
                        : Colors.white.withValues(alpha: 0.85),
                    fontSize: widget.primary ? 19 : 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: widget.primary ? 1.6 : 1.2,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 6),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
