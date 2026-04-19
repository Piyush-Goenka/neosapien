import 'package:flutter/foundation.dart';

class RecipientCodeCodec {
  const RecipientCodeCodec._();

  static const String alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static const int length = 8;
  static final Set<String> _alphabetSet = alphabet.split('').toSet();
  static final RegExp _stripPattern = RegExp(r'[^A-Za-z0-9]');

  static String normalize(String input) {
    return input.replaceAll(_stripPattern, '').toUpperCase();
  }

  static bool isValid(String input) {
    final normalized = normalize(input);
    if (normalized.length != length) {
      return false;
    }

    for (final codeUnit in normalized.codeUnits) {
      final character = String.fromCharCode(codeUnit);
      if (!_alphabetSet.contains(character)) {
        return false;
      }
    }

    return true;
  }

  static String format(String input) {
    final normalized = normalize(input);
    if (normalized.length != length) {
      return normalized;
    }

    return '${normalized.substring(0, 4)}-${normalized.substring(4)}';
  }
}

@immutable
class RecipientCode {
  const RecipientCode._(this.raw);

  factory RecipientCode.fromRaw(String raw) {
    final normalized = RecipientCodeCodec.normalize(raw);
    if (!RecipientCodeCodec.isValid(normalized)) {
      throw const FormatException(
        'Recipient codes must contain 8 unambiguous characters.',
      );
    }

    return RecipientCode._(normalized);
  }

  final String raw;

  String get normalizedValue => raw;

  String get displayValue => RecipientCodeCodec.format(raw);

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is RecipientCode && other.raw == raw;
  }

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => displayValue;
}
