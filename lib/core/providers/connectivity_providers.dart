import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/connectivity/connectivity_gateway.dart';
import 'package:neo_sapien/core/connectivity/connectivity_plus_gateway.dart';

final connectivityGatewayProvider = Provider<ConnectivityGateway>((ref) {
  return ConnectivityPlusGateway();
});

final networkReachabilityStreamProvider = StreamProvider<NetworkReachability>((
  ref,
) {
  return ref.watch(connectivityGatewayProvider).watch();
});
