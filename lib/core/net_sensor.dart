import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../env/titan_facade.dart';

// ─────────────────────────────────────────────────────────────
//  NetSensor — connectivity probe used by the gray flow.
//
//  Why a custom wrapper:
//   • connectivity_plus alone can flicker `none` for a fraction
//     of a second while a VPN interface comes up.  We treat
//     vpn / bluetooth / ethernet / other as live interfaces.
//   • DNS lookup is bumped to 7 seconds (vs the 3 s baseline)
//     because tunnel latency over commercial VPNs can exceed
//     3 s on the first packet, producing a false-offline.
//   • A debounced status stream is exposed for screens that
//     need to react to drops without the well-known
//     "flash → reconnect" effect.
//
//  Hosts list rotates so we don't hammer the same DNS server.
// ─────────────────────────────────────────────────────────────

const Set<ConnectivityResult> _liveInterfaces = {
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

const List<String> _probeHosts = <String>[
  'cloudflare.com',
  'one.one.one.one',
  'apple.com',
];

class NetSensor {
  final Connectivity _plugin;
  int _probeRotor = 0;

  NetSensor({Connectivity? plugin}) : _plugin = plugin ?? Connectivity();

  /// Combination of interface check + DNS resolution.
  Future<bool> hasLink() async {
    final results = await _plugin.checkConnectivity();
    if (!results.any(_liveInterfaces.contains)) return false;
    return _resolveHost();
  }

  Future<bool> _resolveHost() async {
    final host = _probeHosts[_probeRotor % _probeHosts.length];
    _probeRotor++;
    try {
      final addresses = await InternetAddress.lookup(host)
          .timeout(TitanFacade.dnsProbeTimeout);
      return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Raw event stream from the underlying plugin.
  Stream<List<ConnectivityResult>> rawStream() =>
      _plugin.onConnectivityChanged;

  /// Emits `true` when the link transitions back to live, `false`
  /// after a debounced no-interface window.  Suitable for UI
  /// transitions that must not flicker on VPN flips.
  Stream<bool> debouncedDrops({
    Duration? offlineWindow,
  }) {
    final window = offlineWindow ?? TitanFacade.offlineDebounce;
    final controller = StreamController<bool>();
    Timer? pending;
    final sub = _plugin.onConnectivityChanged.listen((statuses) {
      final live = statuses.any(_liveInterfaces.contains);
      if (live) {
        pending?.cancel();
        controller.add(true);
        return;
      }
      pending?.cancel();
      pending = Timer(window, () {
        if (!controller.isClosed) controller.add(false);
      });
    });

    controller.onCancel = () {
      pending?.cancel();
      sub.cancel();
    };
    return controller.stream;
  }
}
