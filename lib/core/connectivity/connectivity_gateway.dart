/// Coarse-grained network-reachability snapshot used by transfer policies.
enum NetworkReachability {
  offline,
  unmetered, // wifi / ethernet
  metered, // cellular / bluetooth / other suspect transports
  unknown,
}

/// Abstract seam over [Connectivity] so transfer logic can be tested without
/// platform channels.
abstract class ConnectivityGateway {
  Future<NetworkReachability> current();
  Stream<NetworkReachability> watch();
}
