import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sapien/app/app.dart';
import 'package:neo_sapien/features/identity/application/identity_controller.dart';
import 'package:neo_sapien/features/identity/domain/entities/user_identity.dart';
import 'package:neo_sapien/features/identity/domain/repositories/identity_repository.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

void main() {
  testWidgets('renders the production dashboard shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            _FakeIdentityRepository(),
          ),
        ],
        child: const NeoSapienApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('NeoSapien'), findsOneWidget);
    expect(find.text('Your code'), findsOneWidget);
    expect(find.text('ABCD-EFGH'), findsOneWidget);
    expect(find.text('Send files'), findsOneWidget);
    expect(find.text('Open inbox'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}

final class _FakeIdentityRepository implements IdentityRepository {
  @override
  Future<UserIdentity> ensureProvisionedIdentity() async {
    return UserIdentity(
      installationId: 'test-installation',
      shortCode: RecipientCode.fromRaw('ABCDEFGH'),
      createdAt: DateTime.utc(2026, 4, 19),
    );
  }

  @override
  Future<UserIdentity?> getCurrentIdentity() {
    return ensureProvisionedIdentity();
  }
}
