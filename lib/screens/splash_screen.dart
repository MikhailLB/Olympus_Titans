import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  int _dotCount = 0;
  Timer? _progressTimer;
  Timer? _dotTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    // Animated dots
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });


    // Progress fills to ~88% slowly, then jumps to 100%
    const totalMs = 3000;
    const steps = 80;
    const stepMs = totalMs ~/ steps;

    _progressTimer = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      if (!mounted) return;
      final raw = t.tick / steps;
      setState(() => _progress = raw.clamp(0.0, 0.88));

      if (t.tick >= steps) {
        t.cancel();
        // Final burst to 100%
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _progress = 1.0);
          Future.delayed(const Duration(milliseconds: 400), _navigate);
        });
      }
    });
  }

  Future<void> _navigate() async {
    if (_navigated) return;
    _navigated = true;
    // Lock to portrait for all screens after splash
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/menu');
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final dots = '.' * _dotCount;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image — horizontal or vertical
          Image.asset(
            isLandscape
                ? 'assets/Horizontal_LoadingScreen.png'
                : 'assets/Vertical_LoadingScreen.png',
            fit: BoxFit.cover,
          ),

          // Dark overlay for readability
          Container(color: Colors.black.withValues(alpha: 0.35)),

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // Progress bar area
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.08,
                  ),
                  child: Column(
                    children: [
                      // Loading text
                      Text(
                        'Loading$dots',
                        style: TextStyle(
                          color: const Color(0xFFC9A84C),
                          fontSize: isLandscape ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Progress bar container
                      Container(
                        height: isLandscape ? 12 : 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(
                            color: const Color(0xFFC9A84C).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: LayoutBuilder(
                            builder: (ctx, constraints) => Stack(
                              children: [
                                // Filled portion
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  width: constraints.maxWidth * _progress,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFC9A84C),
                                        Color(0xFFFFF176),
                                        Color(0xFFC9A84C),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFC9A84C)
                                            .withValues(alpha: 0.8),
                                        blurRadius: 6,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
