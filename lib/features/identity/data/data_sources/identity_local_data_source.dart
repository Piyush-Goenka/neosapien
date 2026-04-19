import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';

class IdentityLocalDataSource {
  IdentityLocalDataSource(this._secureStorage);

  static const String _identityStorageKey = 'identity.local.v1';

  final FlutterSecureStorage _secureStorage;

  Future<UserIdentity?> readIdentity() async {
    try {
      final encoded = await _secureStorage.read(key: _identityStorageKey);
      if (encoded == null || encoded.isEmpty) {
        return null;
      }

      final json = jsonDecode(encoded);
      if (json is! Map<String, Object?>) {
        await clearIdentity();
        return null;
      }

      return UserIdentity.fromJson(json);
    } on FormatException {
      await clearIdentity();
      return null;
    } on Object catch (error) {
      throw IdentityPersistenceException(
        'Failed to read the local device identity.',
        cause: error,
      );
    }
  }

  Future<void> writeIdentity(UserIdentity identity) async {
    try {
      await _secureStorage.write(
        key: _identityStorageKey,
        value: jsonEncode(identity.toJson()),
      );
    } on Object catch (error) {
      throw IdentityPersistenceException(
        'Failed to persist the local device identity.',
        cause: error,
      );
    }
  }

  Future<void> clearIdentity() async {
    try {
      await _secureStorage.delete(key: _identityStorageKey);
    } on Object catch (error) {
      throw IdentityPersistenceException(
        'Failed to clear the local device identity.',
        cause: error,
      );
    }
  }
}
