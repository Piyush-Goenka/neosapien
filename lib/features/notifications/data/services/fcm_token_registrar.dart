import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Persists the device's FCM token under the user's private subcollection so
/// the Cloud Function can push on `transfers/{id}` create.
///
/// Uses `arrayUnion` to append to `users/{uid}/private/fcm.tokens`, which
/// supports multi-device: a user signed in on phone A and tablet B has both
/// tokens and will be paged on both. The Cloud Function prunes invalid
/// tokens on send failures.
class FcmTokenRegistrar {
  FcmTokenRegistrar({
    required FirebaseFirestore firestore,
    required FirebaseMessaging messaging,
  }) : _firestore = firestore,
       _messaging = messaging;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Future<void> registerForUser({required String currentUserUid}) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await _writeToken(currentUserUid: currentUserUid, token: token);
    } on Object {
      // FCM init can fail on simulators / missing APNs key; don't block boot.
      return;
    }

    _messaging.onTokenRefresh.listen((token) {
      if (token.isEmpty) return;
      // Best-effort; ignore errors so the stream keeps alive.
      _writeToken(currentUserUid: currentUserUid, token: token).catchError(
        (Object _) {},
      );
    });
  }

  Future<void> _writeToken({
    required String currentUserUid,
    required String token,
  }) async {
    final tokensDoc = _firestore.doc('users/$currentUserUid/private/fcm');
    await tokensDoc.set(<String, Object?>{
      'tokens': FieldValue.arrayUnion(<String>[token]),
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    }, SetOptions(merge: true));
  }
}
