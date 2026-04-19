import 'package:flutter/foundation.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

@immutable
class UserIdentity {
  const UserIdentity({
    required this.installationId,
    required this.shortCode,
    required this.createdAt,
  });

  factory UserIdentity.fromJson(Map<String, Object?> json) {
    final installationId = json['installationId'];
    final shortCode = json['shortCode'];
    final createdAtMillis = json['createdAtMillis'];

    if (installationId is! String ||
        shortCode is! String ||
        createdAtMillis is! int) {
      throw const FormatException('Invalid user identity payload.');
    }

    return UserIdentity(
      installationId: installationId,
      shortCode: RecipientCode.fromRaw(shortCode),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtMillis,
        isUtc: true,
      ),
    );
  }

  final String installationId;
  final RecipientCode shortCode;
  final DateTime createdAt;

  Map<String, Object> toJson() {
    return <String, Object>{
      'installationId': installationId,
      'shortCode': shortCode.normalizedValue,
      'createdAtMillis': createdAt.toUtc().millisecondsSinceEpoch,
    };
  }
}
