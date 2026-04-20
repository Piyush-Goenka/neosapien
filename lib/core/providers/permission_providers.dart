import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/permissions/permission_gateway.dart';
import 'package:neo_sapien/core/permissions/permission_handler_gateway.dart';

final permissionGatewayProvider = Provider<PermissionGateway>((ref) {
  return const PermissionHandlerGateway();
});
