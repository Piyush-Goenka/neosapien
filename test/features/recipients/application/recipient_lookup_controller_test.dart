import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sapien/features/identity/application/identity_controller.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/features/identity/domain/repositories/identity_repository.dart';
import 'package:neo_sapien/features/recipients/application/recipient_lookup_controller.dart';
import 'package:neo_sapien/features/recipients/domain/entities/recipient.dart';
import 'package:neo_sapien/features/recipients/domain/repositories/recipient_lookup_repository.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

void main() {
  test('fails fast for malformed recipient codes', () async {
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(
          _FakeIdentityRepository(
            UserIdentity(
              installationId: 'installation-a',
              shortCode: RecipientCode.fromRaw('ABCDEFGH'),
              createdAt: DateTime.utc(2026, 4, 19),
            ),
          ),
        ),
        recipientLookupRepositoryProvider.overrideWithValue(
          _FakeRecipientLookupRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      recipientLookupControllerProvider.notifier,
    );
    controller.updateInput('BAD');

    await controller.resolveRecipient();

    final state = container.read(recipientLookupControllerProvider);
    expect(
      state.errorMessage,
      contains('Recipient codes must contain 8 unambiguous characters.'),
    );
    expect(state.resolvedRecipient, isNull);
  });

  test('blocks self-send before repository lookup', () async {
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(
          _FakeIdentityRepository(
            UserIdentity(
              installationId: 'installation-a',
              shortCode: RecipientCode.fromRaw('ABCDEFGH'),
              createdAt: DateTime.utc(2026, 4, 19),
            ),
          ),
        ),
        recipientLookupRepositoryProvider.overrideWithValue(
          _FakeRecipientLookupRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      recipientLookupControllerProvider.notifier,
    );
    controller.updateInput('ABCD-EFGH');

    await controller.resolveRecipient();

    final state = container.read(recipientLookupControllerProvider);
    expect(state.errorMessage, 'You cannot send files to your own code.');
    expect(state.resolvedRecipient, isNull);
  });

  test('returns a clear error when no recipient owns the code', () async {
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(
          _FakeIdentityRepository(
            UserIdentity(
              installationId: 'installation-a',
              shortCode: RecipientCode.fromRaw('ABCDEFGH'),
              createdAt: DateTime.utc(2026, 4, 19),
            ),
          ),
        ),
        recipientLookupRepositoryProvider.overrideWithValue(
          _FakeRecipientLookupRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      recipientLookupControllerProvider.notifier,
    );
    controller.updateInput('WXYZ-2345');

    await controller.resolveRecipient();

    final state = container.read(recipientLookupControllerProvider);
    expect(state.errorMessage, 'No device is registered under that code yet.');
    expect(state.resolvedRecipient, isNull);
  });
}

final class _FakeIdentityRepository implements IdentityRepository {
  _FakeIdentityRepository(this._identity);

  final UserIdentity _identity;

  @override
  Future<UserIdentity> ensureProvisionedIdentity() async {
    return _identity;
  }

  @override
  Future<UserIdentity?> getCurrentIdentity() async {
    return _identity;
  }
}

final class _FakeRecipientLookupRepository
    implements RecipientLookupRepository {
  @override
  Future<Recipient?> resolveByCode(RecipientCode code) async {
    return null;
  }
}
