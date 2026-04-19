import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sapien/features/identity/domain/services/short_code_generator.dart';
import 'package:neo_sapien/features/recipients/domain/value_objects/recipient_code.dart';

void main() {
  group('ShortCodeGenerator', () {
    test('generates unambiguous 8 character codes', () {
      final generator = ShortCodeGenerator(random: Random(42));

      final code = generator.generateRaw();

      expect(code.length, RecipientCodeCodec.length);
      expect(RecipientCodeCodec.isValid(code), isTrue);
      expect(code.contains(RegExp(r'[O0Il1]')), isFalse);
    });

    test('formats generated codes for display', () {
      final formatted = RecipientCodeCodec.format('ABCDWXYZ');

      expect(formatted, 'ABCD-WXYZ');
    });

    test('normalizes human-entered values', () {
      final code = RecipientCode.fromRaw('abcd-wxyz');

      expect(code.normalizedValue, 'ABCDWXYZ');
      expect(code.displayValue, 'ABCD-WXYZ');
    });
  });
}
