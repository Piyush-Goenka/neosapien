import 'package:firebase_auth/firebase_auth.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';

class AuthenticatedUser {
  const AuthenticatedUser({required this.uid});

  final String uid;
}

class FirebaseAuthDataSource {
  FirebaseAuthDataSource(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  Future<AuthenticatedUser> ensureAnonymousSession() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      return AuthenticatedUser(uid: currentUser.uid);
    }

    try {
      final credential = await _firebaseAuth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw const RemoteIdentityException(
          'Firebase anonymous auth completed without a user session.',
        );
      }

      return AuthenticatedUser(uid: user.uid);
    } on FirebaseAuthException catch (error) {
      throw RemoteIdentityException(
        'Firebase anonymous authentication failed: ${error.message ?? error.code}.',
        cause: error,
      );
    }
  }
}
