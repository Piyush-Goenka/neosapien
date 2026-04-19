import 'dart:math';

import 'package:neo_sapien/features/identity/data/data_sources/identity_local_data_source.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/features/identity/domain/repositories/identity_repository.dart';
import 'package:neo_sapien/features/identity/domain/services/short_code_generator.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

class LocalIdentityRepository implements IdentityRepository {
  LocalIdentityRepository({
    required IdentityLocalDataSource localDataSource,
    required ShortCodeGenerator shortCodeGenerator,
    Random? random,
  }) : _localDataSource = localDataSource,
       _shortCodeGenerator = shortCodeGenerator,
       _random = random ?? Random.secure();

  final IdentityLocalDataSource _localDataSource;
  final ShortCodeGenerator _shortCodeGenerator;
  final Random _random;

  @override
  Future<UserIdentity> ensureProvisionedIdentity() async {
    final existing = await _localDataSource.readIdentity();
    if (existing != null) {
      return existing;
    }

    final identity = UserIdentity(
      installationId: _generateInstallationId(),
      shortCode: RecipientCode.fromRaw(_shortCodeGenerator.generateRaw()),
      createdAt: DateTime.now().toUtc(),
    );

    await _localDataSource.writeIdentity(identity);
    return identity;
  }

  @override
  Future<UserIdentity?> getCurrentIdentity() {
    return _localDataSource.readIdentity();
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
