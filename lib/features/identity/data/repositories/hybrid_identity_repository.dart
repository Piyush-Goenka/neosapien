import 'dart:math';

import 'package:neo_sapien/core/firebase/firebase_bootstrap_service.dart';
import 'package:neo_sapien/features/identity/data/data_sources/firebase_auth_data_source.dart';
import 'package:neo_sapien/features/identity/data/data_sources/identity_local_data_source.dart';
import 'package:neo_sapien/features/identity/data/data_sources/identity_registry_remote_data_source.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/features/identity/domain/repositories/identity_repository.dart';
import 'package:neo_sapien/features/identity/domain/services/short_code_generator.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

class HybridIdentityRepository implements IdentityRepository {
  HybridIdentityRepository({
    required IdentityLocalDataSource localDataSource,
    required FirebaseAuthDataSource firebaseAuthDataSource,
    required IdentityRegistryRemoteDataSource identityRegistryRemoteDataSource,
    required FirebaseBootstrapService firebaseBootstrapService,
    required ShortCodeGenerator shortCodeGenerator,
    Random? random,
  }) : _localDataSource = localDataSource,
       _firebaseAuthDataSource = firebaseAuthDataSource,
       _identityRegistryRemoteDataSource = identityRegistryRemoteDataSource,
       _firebaseBootstrapService = firebaseBootstrapService,
       _shortCodeGenerator = shortCodeGenerator,
       _random = random ?? Random.secure();

  final IdentityLocalDataSource _localDataSource;
  final FirebaseAuthDataSource _firebaseAuthDataSource;
  final IdentityRegistryRemoteDataSource _identityRegistryRemoteDataSource;
  final FirebaseBootstrapService _firebaseBootstrapService;
  final ShortCodeGenerator _shortCodeGenerator;
  final Random _random;

  @override
  Future<UserIdentity> ensureProvisionedIdentity() async {
    final localIdentity = await _localDataSource.readIdentity();
    final installationId =
        localIdentity?.installationId ?? _generateInstallationId();

    final bootstrapState = await _firebaseBootstrapService.ensureInitialized();
    if (!bootstrapState.isReady) {
      return _ensureLocalFallback(
        existingIdentity: localIdentity,
        installationId: installationId,
      );
    }

    final authenticatedUser = await _firebaseAuthDataSource
        .ensureAnonymousSession();
    final remoteIdentity = await _identityRegistryRemoteDataSource
        .fetchRegisteredIdentity(authenticatedUser.uid);

    if (remoteIdentity != null) {
      final mergedIdentity = UserIdentity(
        installationId: installationId,
        shortCode: remoteIdentity.shortCode,
        createdAt: remoteIdentity.createdAt,
      );
      await _localDataSource.writeIdentity(mergedIdentity);
      return mergedIdentity;
    }

    final preferredCode =
        localIdentity?.shortCode.normalizedValue ??
        _shortCodeGenerator.generateRaw();
    final reservedIdentity = await _identityRegistryRemoteDataSource
        .reserveIdentity(
          userId: authenticatedUser.uid,
          installationId: installationId,
          preferredCode: preferredCode,
          generateCode: _shortCodeGenerator.generateRaw,
        );

    final mergedIdentity = UserIdentity(
      installationId: installationId,
      shortCode: reservedIdentity.shortCode,
      createdAt: reservedIdentity.createdAt,
    );
    await _localDataSource.writeIdentity(mergedIdentity);
    return mergedIdentity;
  }

  @override
  Future<UserIdentity?> getCurrentIdentity() {
    return _localDataSource.readIdentity();
  }

  Future<UserIdentity> _ensureLocalFallback({
    required UserIdentity? existingIdentity,
    required String installationId,
  }) async {
    if (existingIdentity != null) {
      return existingIdentity;
    }

    final identity = UserIdentity(
      installationId: installationId,
      shortCode: RecipientCode.fromRaw(_shortCodeGenerator.generateRaw()),
      createdAt: DateTime.now().toUtc(),
    );
    await _localDataSource.writeIdentity(identity);
    return identity;
  }

  String _generateInstallationId() {
    final segments = <String>[];
    for (var index = 0; index < 4; index += 1) {
      final segment = _random
          .nextInt(0x10000)
          .toRadixString(16)
          .padLeft(4, '0');
      segments.add(segment);
    }
    return segments.join('-');
  }
}
