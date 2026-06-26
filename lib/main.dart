import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/alert_channel.dart';
import 'core/attribution_agent.dart';
import 'core/backend_dispatcher.dart';
import 'core/local_vault.dart';
import 'core/mobile_http_agent.dart';
import 'core/net_sensor.dart';
import 'shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + AppCheck initialise opportunistically — without
  // google-services.json the call throws and is swallowed.
  // AlertChannel re-tries Firebase.initializeApp() with the same
  // try/catch shape, so push notifications remain disabled but
  // the rest of the app stays functional.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (_) {
    if (kDebugMode) debugPrint('[main] Firebase not configured — push disabled');
  }

  // Boot screens (loading + opt-in) must adapt to both orientations.
  // The white game re-locks to portrait when MenuScreen is reached.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
  ));

  await mobileHttpAgent.prepare();

  final vault = LocalVault();
  await vault.warmUp();

  final netSensor = NetSensor();
  final attribution = AttributionAgent();
  final dispatcher = BackendDispatcher(vault);
  final alerts = AlertChannel(vault);

  runApp(TitansShellApp(
    vault: vault,
    netSensor: netSensor,
    attribution: attribution,
    dispatcher: dispatcher,
    alerts: alerts,
  ));
}
