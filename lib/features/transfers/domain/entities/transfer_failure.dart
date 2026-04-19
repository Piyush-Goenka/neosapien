import 'package:flutter/foundation.dart';
import 'package:neo_sapien/features/transfers/domain/entities/transfer_failure_code.dart';

@immutable
class TransferFailure {
  const TransferFailure({
    required this.code,
    required this.message,
    required this.isRecoverable,
  });

  final TransferFailureCode code;
  final String message;
  final bool isRecoverable;
}
