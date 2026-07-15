import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline }

/// Riverpod provider to monitor the network connectivity state in real-time.
/// Uses connectivity_plus and accounts for multi-interface responses in v6+.
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final connectivity = Connectivity();

  // Create stream mapped from connectivity change notifications
  return connectivity.onConnectivityChanged.map((results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    return ConnectivityStatus.online;
  });
});
