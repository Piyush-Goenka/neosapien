import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/firebase/firebase_bootstrap_service.dart';
import 'package:neo_sapien/core/providers/app_environment_provider.dart';

final firebaseBootstrapServiceProvider = Provider<FirebaseBootstrapService>((
  ref,
) {
  final environment = ref.watch(appEnvironmentProvider);
  return FirebaseBootstrapService(environment);
});

final firebaseBootstrapProvider = FutureProvider<FirebaseBootstrapState>((ref) {
  return ref.watch(firebaseBootstrapServiceProvider).ensureInitialized();
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});
