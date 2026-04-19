import 'dart:math';

import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

class ShortCodeGenerator {
  ShortCodeGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  String generateRaw() {
    final buffer = StringBuffer();
    for (var index = 0; index < RecipientCodeCodec.length; index += 1) {
      final nextChar = RecipientCodeCodec
          .alphabet[_random.nextInt(RecipientCodeCodec.alphabet.length)];
      buffer.write(nextChar);
    }
    return buffer.toString();
  }

  String generateDisplay() => RecipientCodeCodec.format(generateRaw());
}
