import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';

abstract interface class IdentityRepository {
  Future<UserIdentity> ensureProvisionedIdentity();

  Future<UserIdentity?> getCurrentIdentity();
}
