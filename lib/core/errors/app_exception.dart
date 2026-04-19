sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {super.cause});
}

final class IdentityPersistenceException extends AppException {
  const IdentityPersistenceException(super.message, {super.cause});
}

final class RemoteIdentityException extends AppException {
  const RemoteIdentityException(super.message, {super.cause});
}

final class RecipientLookupException extends AppException {
  const RecipientLookupException(super.message, {super.cause});
}
