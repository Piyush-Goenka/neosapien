import 'package:flutter/foundation.dart';
import 'package:neo_sapien/core/firebase/firebase_bootstrap_service.dart';
import 'package:neo_sapien/features/identity/data/data_sources/firebase_auth_data_source.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/features/identity/domain/repositories/identity_repository.dart';

@immutable
class TransferRemoteContext {
  const TransferRemoteContext({required this.uid, required this.identity});

  final String uid;
  final UserIdentity identity;
}

class TransferRemoteContextResolver {
  TransferRemoteContextResolver({
    required FirebaseBootstrapService firebaseBootstrapService,
    required FirebaseAuthDataSource firebaseAuthDataSource,
    required IdentityRepository identityRepository,
  }) : _firebaseBootstrapService = firebaseBootstrapService,
       _firebaseAuthDataSource = firebaseAuthDataSource,
       _identityRepository = identityRepository;

  final FirebaseBootstrapService _firebaseBootstrapService;
  final FirebaseAuthDataSource _firebaseAuthDataSource;
  final IdentityRepository _identityRepository;

  Future<TransferRemoteContext?> tryResolve() async {
    final bootstrapState = await _firebaseBootstrapService.ensureInitialized();
    if (!bootstrapState.isReady) {
      return null;
    }

    final identity =
        await _identityRepository.getCurrentIdentity() ??
        await _identityRepository.ensureProvisionedIdentity();
    final authenticatedUser = await _firebaseAuthDataSource
        .ensureAnonymousSession();

    return TransferRemoteContext(
      uid: authenticatedUser.uid,
      identity: identity,
    );
  }
}
