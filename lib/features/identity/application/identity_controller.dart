import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/providers/firebase_providers.dart';
import 'package:neo_sapien/core/providers/secure_storage_provider.dart';
import 'package:neo_sapien/features/identity/data/data_sources/firebase_auth_data_source.dart';
import 'package:neo_sapien/features/identity/data/data_sources/identity_local_data_source.dart';
import 'package:neo_sapien/features/identity/data/data_sources/identity_registry_remote_data_source.dart';
import 'package:neo_sapien/features/identity/data/repositories/hybrid_identity_repository.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/features/identity/domain/repositories/identity_repository.dart';
import 'package:neo_sapien/features/identity/domain/services/short_code_generator.dart';

final shortCodeGeneratorProvider = Provider<ShortCodeGenerator>((ref) {
  return ShortCodeGenerator();
});

final firebaseAuthDataSourceProvider = Provider<FirebaseAuthDataSource>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return FirebaseAuthDataSource(firebaseAuth);
});

final identityRegistryRemoteDataSourceProvider =
    Provider<IdentityRegistryRemoteDataSource>((ref) {
      final firestore = ref.watch(firebaseFirestoreProvider);
      return IdentityRegistryRemoteDataSource(firestore);
    });

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final shortCodeGenerator = ref.watch(shortCodeGeneratorProvider);
  final firebaseAuthDataSource = ref.watch(firebaseAuthDataSourceProvider);
  final identityRegistryRemoteDataSource = ref.watch(
    identityRegistryRemoteDataSourceProvider,
  );
  final firebaseBootstrapService = ref.watch(firebaseBootstrapServiceProvider);

  return HybridIdentityRepository(
    localDataSource: IdentityLocalDataSource(secureStorage),
    firebaseAuthDataSource: firebaseAuthDataSource,
    identityRegistryRemoteDataSource: identityRegistryRemoteDataSource,
    firebaseBootstrapService: firebaseBootstrapService,
    shortCodeGenerator: shortCodeGenerator,
  );
});

final currentIdentityProvider =
    AsyncNotifierProvider<CurrentIdentityController, UserIdentity>(
      CurrentIdentityController.new,
    );

class CurrentIdentityController extends AsyncNotifier<UserIdentity> {
  @override
  Future<UserIdentity> build() {
    return ref.watch(identityRepositoryProvider).ensureProvisionedIdentity();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<UserIdentity>();
    state = await AsyncValue.guard<UserIdentity>(
      () => ref.read(identityRepositoryProvider).ensureProvisionedIdentity(),
    );
  }
}
