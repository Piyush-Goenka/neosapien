import 'package:flutter/foundation.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

@immutable
class Recipient {
  const Recipient({
    required this.code,
    this.displayName,
    this.userId,
    this.isOnline = false,
    this.isBlocked = false,
  });

  final RecipientCode code;
  final String? displayName;
  final String? userId;
  final bool isOnline;
  final bool isBlocked;
}
