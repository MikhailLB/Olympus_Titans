import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — same image as loading screen
          Image.asset(
            'assets/Vertical_LoadingScreen.png',
            fit: BoxFit.cover,
          ),

          // Dark gradient overlay so UI is readable
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0xBB050E1A),
                  Color(0xEE050E1A),
                ],
              ),
            ),
          ),

          // Zeus — centered vertically between title text (top) and buttons (bottom)
          Align(
            alignment: const Alignment(0, 0.05),
            child: SizedBox(
              height: size.height * 0.26,
              child: Image.asset(
                'assets/zeu.webp',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // UI column
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // Buttons
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.12),
                  child: Column(
                    children: [
                      _MenuButton(
                        label: 'PLAY',
                        icon: Icons.play_arrow_rounded,
                        color: const Color(0xFFC9A84C),
                        onTap: () => Navigator.pushNamed(context, '/levels'),
                      ),
                      const SizedBox(height: 12),
                      _MenuButton(
                        label: 'PRIVACY POLICY',
                        icon: Icons.shield_outlined,
                        color: const Color(0xFF4FC3F7),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/webview',
                          arguments: {
                            'url': 'https://olympustittans.com/privacy-policy.html',
                            'title': 'Privacy Policy',
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MenuButton(
                        label: 'SUPPORT',
                        icon: Icons.help_outline_rounded,
                        color: const Color(0xFF4FC3F7),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/webview',
                          arguments: {
                            'url': 'https://olympustittans.com/support.html',
                            'title': 'Support',
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 44),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.75), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
