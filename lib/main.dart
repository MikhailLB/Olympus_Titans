import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/level_select_screen.dart';
import 'screens/game_screen.dart';
import 'screens/webview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Orientation is NOT locked here; SplashScreen locks to portrait before navigating away.
  // This allows the loading screen to render in whichever orientation the device is held.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const OlympusTitansApp());
}

class OlympusTitansApp extends StatelessWidget {
  const OlympusTitansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Olympus Titans',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC9A84C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050E1A),
        fontFamily: 'sans-serif',
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _fadeRoute(const SplashScreen(), settings);
          case '/menu':
            return _fadeRoute(const MenuScreen(), settings);
          case '/levels':
            return _fadeRoute(const LevelSelectScreen(), settings);
          case '/game':
            final index = settings.arguments as int? ?? 0;
            return _slideRoute(GameScreen(levelIndex: index), settings);
          case '/webview':
            final args = settings.arguments as Map<String, String>?;
            return _slideRoute(
              WebViewScreen(
                url: args?['url'] ?? 'https://olympustittans.com',
                title: args?['title'] ?? '',
              ),
              settings,
            );
          default:
            return _fadeRoute(const MenuScreen(), settings);
        }
      },
    );
  }

  static PageRoute _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  static PageRoute _slideRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
