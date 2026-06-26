import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'local_vault.dart';
import 'mobile_http_agent.dart';

// ─────────────────────────────────────────────────────────────
//  AlertChannel — FCM + flutter_local_notifications wrapper.
//
//  Push URL semantics (per the gray-flow TZ):
//    KILLED  + tap notification → stash in LocalVault, the next
//                                 boot consumes it via popPushUrl.
//    WARM    + tap notification → fire onWarmDestination, never
//                                 persisted (the spec says push
//                                 URLs are one-shot).
//    FOREGROUND notification arrives → show a local notification
//                                 via flutter_local_notifications;
//                                 a tap is treated as WARM.
//
//  The OS-denied flag (LocalVault.markOptInOsDenied) is set when
//  the system dialog comes back with `denied`, so the opt-in
//  screen never re-surfaces and pretends to do nothing.
// ─────────────────────────────────────────────────────────────

const String _kChannelId = 'olympus_titans_alerts';
const String _kChannelName = 'Olympus Titans alerts';
const String _kIconRef = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _alertChannelBgEntry(RemoteMessage _) async {
  // No work in the background isolate — OS shows the system tray
  // notification automatically.  Tapping it routes through one of
  // the foreground/initial handlers.
}

class AlertChannel {
  final LocalVault _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;
  String? _token;
  bool _booted = false;

  void Function(String url)? onWarmDestination;
  void Function(String token)? onTokenRotated;

  AlertChannel(this._vault);

  String? get token => _token;

  Future<void> ignite() async {
    if (_booted) return;
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_alertChannelBgEntry);
      await _setupLocal();
      _token = await _fcm!.getToken();
      _fcm!.onTokenRefresh.listen((next) {
        _token = next;
        onTokenRotated?.call(next);
      });
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);
      final initial = await _fcm!.getInitialMessage();
      if (initial != null) {
        _onColdTap(initial);
      }
      _booted = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AlertChannel] init skipped: $e');
    }
  }

  Future<void> _setupLocal() async {
    const androidInit = AndroidInitializationSettings(_kIconRef);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final map = jsonDecode(payload);
          if (map is Map) {
            final url = map['url'];
            if (url is String && url.isNotEmpty) {
              onWarmDestination?.call(url);
            }
          }
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          description: 'Olympus Titans high-importance pushes',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Returns `true` if the OS reports `authorized` or `provisional`.
  /// Stores both grant and OS-denied flags into LocalVault so the
  /// opt-in screen doesn't re-spawn after a denial.
  Future<bool> requestSystemPermission() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    await _vault.markOptInGranted(granted);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markOptInOsDenied();
    }
    return granted;
  }

  // Foreground: app is alive, OS won't draw a tray notification
  // automatically.  We show one via flutter_local_notifications,
  // optionally with a downloaded big-picture from `imageUrl`.
  Future<void> _onForeground(RemoteMessage msg) async {
    if (!Platform.isAndroid) return;
    final n = msg.notification;
    if (n == null) return;
    AndroidNotificationDetails? details;

    final imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _grabImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _kIconRef,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _kIconRef,
    );

    final payload = msg.data.isEmpty ? null : jsonEncode(msg.data);
    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  /// Cold tap: stash the destination so the boot orchestrator
  /// can route to PortalStage on the next launch.
  void _onColdTap(RemoteMessage msg) {
    final url = msg.data['url'];
    if (url is String && url.isNotEmpty) {
      _vault.stashPushUrl(url);
    }
  }

  /// Warm tap: fire the callback (do NOT persist — one-shot rule).
  void _onWarmTap(RemoteMessage msg) {
    final url = msg.data['url'];
    if (url is String && url.isNotEmpty) {
      onWarmDestination?.call(url);
    }
  }

  Future<Uint8List?> _grabImage(String url) async {
    try {
      final res = await mobileHttpAgent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }
}
