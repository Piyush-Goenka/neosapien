import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

@immutable
class RemoteIdentityRecord {
  const RemoteIdentityRecord({
    required this.shortCode,
    required this.createdAt,
  });

  final RecipientCode shortCode;
  final DateTime createdAt;
}

class IdentityRegistryRemoteDataSource {
  IdentityRegistryRemoteDataSource(this._firestore);

  static const int maxReservationAttempts = 24;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>> get _codesCollection {
    return _firestore.collection('codes');
  }

  Future<RemoteIdentityRecord?> fetchRegisteredIdentity(String userId) async {
    try {
      final snapshot = await _usersCollection.doc(userId).get();
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      return _recordFromUserData(data);
    } on FirebaseException catch (error) {
      throw RemoteIdentityException(
        'Failed to read the registered identity from Firestore: ${error.message ?? error.code}.',
        cause: error,
      );
    }
  }

  Future<RemoteIdentityRecord> reserveIdentity({
    required String userId,
    required String installationId,
    required String preferredCode,
    required String Function() generateCode,
  }) async {
    final existing = await fetchRegisteredIdentity(userId);
    if (existing != null) {
      return existing;
    }

    final candidateCodes = <String>{preferredCode};
    while (candidateCodes.length < maxReservationAttempts) {
      candidateCodes.add(generateCode());
    }

    for (final candidate in candidateCodes) {
      final reserved = await _tryReserveCode(
        userId: userId,
        installationId: installationId,
        candidateCode: RecipientCode.fromRaw(candidate),
      );

      if (reserved != null) {
        return reserved;
      }
    }

    throw const RemoteIdentityException(
      'Unable to reserve a unique short code after multiple attempts.',
    );
  }

  Future<RemoteIdentityRecord?> _tryReserveCode({
    required String userId,
    required String installationId,
    required RecipientCode candidateCode,
  }) async {
    final userDocument = _usersCollection.doc(userId);
    final codeDocument = _codesCollection.doc(candidateCode.normalizedValue);
    final reservedAt = DateTime.now().toUtc();

    try {
      return await _firestore.runTransaction<RemoteIdentityRecord?>((
        transaction,
      ) async {
        final userSnapshot = await transaction.get(userDocument);
        final existingUserData = userSnapshot.data();
        final existingRecord = existingUserData == null
            ? null
            : _recordFromUserData(existingUserData);
        if (existingRecord != null) {
          return existingRecord;
        }

        final codeSnapshot = await transaction.get(codeDocument);
        if (codeSnapshot.exists) {
          return null;
        }

        transaction.set(userDocument, <String, Object?>{
          'uid': userId,
          'installationId': installationId,
          'shortCode': candidateCode.normalizedValue,
          'createdAt': Timestamp.fromDate(reservedAt),
          'updatedAt': FieldValue.serverTimestamp(),
          'status': <String, Object?>{'isOnline': false},
          'platform': defaultTargetPlatform.name,
        }, SetOptions(merge: true));

        transaction.set(codeDocument, <String, Object?>{
          'shortCode': candidateCode.normalizedValue,
          'ownerUid': userId,
          'installationId': installationId,
          'createdAt': Timestamp.fromDate(reservedAt),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return RemoteIdentityRecord(
          shortCode: candidateCode,
          createdAt: reservedAt,
        );
      });
    } on FirebaseException catch (error) {
      throw RemoteIdentityException(
        'Failed while reserving a short code in Firestore: ${error.message ?? error.code}.',
        cause: error,
      );
    }
  }

  RemoteIdentityRecord? _recordFromUserData(Map<String, dynamic> data) {
    final rawCode = data['shortCode'];
    if (rawCode is! String || !RecipientCodeCodec.isValid(rawCode)) {
      return null;
    }

    final createdAt = data['createdAt'];
    final timestamp = createdAt is Timestamp
        ? createdAt.toDate().toUtc()
        : null;

    return RemoteIdentityRecord(
      shortCode: RecipientCode.fromRaw(rawCode),
      createdAt: timestamp ?? DateTime.now().toUtc(),
    );
  }
}
