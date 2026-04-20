import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:neo_sapien/core/connectivity/connectivity_gateway.dart';

/// Production [ConnectivityGateway] backed by `connectivity_plus`.
class ConnectivityPlusGateway implements ConnectivityGateway {
  ConnectivityPlusGateway([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkReachability> current() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _reduce(result);
    } on Object {
      return NetworkReachability.unknown;
    }
  }

  @override
  Stream<NetworkReachability> watch() {
    return _connectivity.onConnectivityChanged.map(_reduce);
  }

  NetworkReachability _reduce(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return NetworkReachability.offline;
    }
    if (results.any(
      (r) =>
          r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
    )) {
      return NetworkReachability.unmetered;
    }
    if (results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.bluetooth ||
          r == ConnectivityResult.other,
    )) {
      return NetworkReachability.metered;
    }
    return NetworkReachability.unknown;
  }
}
