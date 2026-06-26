import 'package:flutter/material.dart';

import 'core/alert_channel.dart';
import 'core/attribution_agent.dart';
import 'core/backend_dispatcher.dart';
import 'core/local_vault.dart';
import 'core/net_sensor.dart';
import 'screens/game_screen.dart';
import 'screens/level_select_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/webview_screen.dart';
import 'views/boot_orchestrator.dart';

class TitansShellApp extends StatelessWidget {
  final LocalVault vault;
  final NetSensor netSensor;
  final AttributionAgent attribution;
  final BackendDispatcher dispatcher;
  final AlertChannel alerts;

  const TitansShellApp({
    super.key,
    required this.vault,
    required this.netSensor,
    required this.attribution,
    required this.dispatcher,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Olympus Titans',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050E1A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC9A84C),
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans-serif',
      ),
      home: BootOrchestrator(
        vault: vault,
        netSensor: netSensor,
        attribution: attribution,
        dispatcher: dispatcher,
        alerts: alerts,
      ),
      onGenerateRoute: _resolveRoute,
    );
  }

  Route<dynamic>? _resolveRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/menu':
        return _fade(const MenuScreen(), settings);
      case '/levels':
        return _fade(const LevelSelectScreen(), settings);
      case '/game':
        final index = settings.arguments as int? ?? 0;
        return _slide(GameScreen(levelIndex: index), settings);
      case '/webview':
        final args = settings.arguments as Map<String, String>?;
        return _slide(
          WebViewScreen(
            url: args?['url'] ?? 'https://olympustittans.com',
            title: args?['title'] ?? '',
          ),
          settings,
        );
    }
    return null;
  }

  static PageRoute _fade(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 360),
    );
  }

  static PageRoute _slide(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final tween = Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: anim.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 320),
    );
  }
}
