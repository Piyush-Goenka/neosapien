import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/core/firebase/firebase_bootstrap_service.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/recipients/domain/repositories/recipient_lookup_repository.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

class FirestoreRecipientLookupRepository implements RecipientLookupRepository {
  FirestoreRecipientLookupRepository({
    required FirebaseFirestore firestore,
    required FirebaseBootstrapService firebaseBootstrapService,
  }) : _firestore = firestore,
       _firebaseBootstrapService = firebaseBootstrapService;

  final FirebaseFirestore _firestore;
  final FirebaseBootstrapService _firebaseBootstrapService;

  @override
  Future<Recipient?> resolveByCode(RecipientCode code) async {
    final bootstrapState = await _firebaseBootstrapService.ensureInitialized();
    if (!bootstrapState.isReady) {
      throw RecipientLookupException(
        'Recipient lookup is unavailable until Firebase is configured. '
        '${bootstrapState.message}',
      );
    }

    try {
      final codeSnapshot = await _firestore
          .collection('codes')
          .doc(code.normalizedValue)
          .get();
      if (!codeSnapshot.exists) {
        return null;
      }

      final codeData = codeSnapshot.data();
      if (codeData == null) {
        return null;
      }

      final ownerUid = codeData['ownerUid'];
      if (ownerUid is! String || ownerUid.isEmpty) {
        return null;
      }

      final userSnapshot = await _firestore
          .collection('users')
          .doc(ownerUid)
          .get();
      final userData = userSnapshot.data();
      final status = userData == null ? null : userData['status'];

      return Recipient(
        code: code,
        displayName: userData == null
            ? null
            : userData['displayName'] as String?,
        userId: ownerUid,
        isOnline: status is Map<String, dynamic>
            ? status['isOnline'] == true
            : false,
      );
    } on FirebaseException catch (error) {
      throw RecipientLookupException(
        'Recipient lookup failed: ${error.message ?? error.code}.',
        cause: error,
      );
    }
  }
}
