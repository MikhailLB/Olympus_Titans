import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  OfflineNoticeView — full-screen artwork from the assets pack
//  with a lightning-bolt themed "Retry" button.
//
//  Background art:
//    portrait   assets/Nowifi/Vertical_Nowifi_Screen.webp
//    landscape  assets/Nowifi/Horizontal_Nowifi_Screen.webp
//
//  The retry workflow rebuilds whatever the parent supplies
//  (rebuilder callback), which is normally BootOrchestrator.
// ─────────────────────────────────────────────────────────────

class OfflineNoticeView extends StatefulWidget {
  final WidgetBuilder rebuilder;
  const OfflineNoticeView({super.key, required this.rebuilder});

  @override
  State<OfflineNoticeView> createState() => _OfflineNoticeViewState();
}

class _OfflineNoticeViewState extends State<OfflineNoticeView>
    with SingleTickerProviderStateMixin {
  bool _retrying = false;
  bool _pressed = false;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.rebuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final bg = isLandscape
        ? 'assets/Nowifi/Horizontal_Nowifi_Screen.webp'
        : 'assets/Nowifi/Vertical_Nowifi_Screen.webp';

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
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: isLandscape ? size.height * 0.07 : size.height * 0.09,
            child: Center(
              child: SizedBox(
                width: isLandscape ? size.width * 0.38 : size.width * 0.74,
                child: _LightningButton(
                  label: _retrying ? 'Reconnecting…' : 'Retry',
                  loading: _retrying,
                  pressed: _pressed,
                  shimmer: _shimmerCtrl,
                  onDown: () => setState(() => _pressed = true),
                  onUp: () {
                    setState(() => _pressed = false);
                    _onRetry();
                  },
                  onCancel: () => setState(() => _pressed = false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightningButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool pressed;
  final AnimationController shimmer;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onCancel;
  const _LightningButton({
    required this.label,
    required this.loading,
    required this.pressed,
    required this.shimmer,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onCancel,
      child: AnimatedScale(
        scale: pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedBuilder(
          animation: shimmer,
          builder: (_, __) {
            final glow = (1.0 - shimmer.value).clamp(0.2, 1.0);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E2B6F),
                    Color(0xFF3057E1),
                    Color(0xFF6CB2FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFE7A1).withValues(alpha: 0.85),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6CB2FF).withValues(alpha: glow * 0.7),
                    blurRadius: 18 + glow * 14,
                    spreadRadius: glow * 2,
                  ),
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    loading ? Icons.bolt_outlined : Icons.flash_on_rounded,
                    color: const Color(0xFFFFE7A1),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
