import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neo_sapien/core/errors/app_exception.dart';
import 'package:neo_sapien/core/providers/firebase_providers.dart';
import 'package:neo_sapien/features/identity/application/identity_controller.dart';
import 'package:neo_sapien/features/recipients/data/repositories/firestore_recipient_lookup_repository.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/recipients/domain/repositories/recipient_lookup_repository.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

@immutable
class RecipientLookupState {
  const RecipientLookupState({
    this.input = '',
    this.isSubmitting = false,
    this.resolvedRecipient,
    this.errorMessage,
  });

  final String input;
  final bool isSubmitting;
  final Recipient? resolvedRecipient;
  final String? errorMessage;

  RecipientLookupState copyWith({
    String? input,
    bool? isSubmitting,
    Object? resolvedRecipient = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return RecipientLookupState(
      input: input ?? this.input,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      resolvedRecipient: resolvedRecipient == _sentinel
          ? this.resolvedRecipient
          : resolvedRecipient as Recipient?,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();

final recipientLookupRepositoryProvider = Provider<RecipientLookupRepository>((
  ref,
) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final firebaseBootstrapService = ref.watch(firebaseBootstrapServiceProvider);

  return FirestoreRecipientLookupRepository(
    firestore: firestore,
    firebaseBootstrapService: firebaseBootstrapService,
  );
});

final recipientLookupControllerProvider =
    NotifierProvider<RecipientLookupController, RecipientLookupState>(
      RecipientLookupController.new,
    );

class RecipientLookupController extends Notifier<RecipientLookupState> {
  @override
  RecipientLookupState build() {
    return const RecipientLookupState();
  }

  void updateInput(String value) {
    state = state.copyWith(
      input: value,
      errorMessage: null,
      resolvedRecipient: null,
    );
  }

  Future<void> resolveRecipient() async {
    final normalized = RecipientCodeCodec.normalize(state.input);
    if (normalized.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter a recipient code to continue.',
        resolvedRecipient: null,
      );
      return;
    }

    if (!RecipientCodeCodec.isValid(normalized)) {
      state = state.copyWith(
        errorMessage:
            'Recipient codes must contain 8 unambiguous characters. '
            'Characters like O, 0, I, l, and 1 are not valid.',
        resolvedRecipient: null,
      );
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      resolvedRecipient: null,
    );

    final code = RecipientCode.fromRaw(normalized);

    try {
      final currentIdentity = await ref
          .read(identityRepositoryProvider)
          .getCurrentIdentity();
      if (currentIdentity != null && currentIdentity.shortCode == code) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'You cannot send files to your own code.',
        );
        return;
      }

      final recipient = await ref
          .read(recipientLookupRepositoryProvider)
          .resolveByCode(code);
      if (recipient == null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'No device is registered under that code yet.',
        );
        return;
      }

      state = state.copyWith(isSubmitting: false, resolvedRecipient: recipient);
    } on AppException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    } on Object catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
    }
  }
}
