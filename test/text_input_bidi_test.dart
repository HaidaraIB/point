import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:point/Utils/text_input_bidi.dart';

void main() {
  group('typedInputTextDirection', () {
    test('returns RTL for Arabic text', () {
      expect(typedInputTextDirection('مرحبا'), TextDirection.rtl);
    });

    test('returns LTR for English text', () {
      expect(typedInputTextDirection('Hello'), TextDirection.ltr);
    });

    test('returns LTR for phone numbers with plus prefix', () {
      expect(
        typedInputTextDirection('+964 770 000 0000'),
        TextDirection.ltr,
      );
    });

    test('returns RTL when Arabic follows leading spaces', () {
      expect(typedInputTextDirection('   العربية'), TextDirection.rtl);
    });

    test('returns null for empty or whitespace-only text', () {
      expect(typedInputTextDirection(''), isNull);
      expect(typedInputTextDirection('   '), isNull);
    });
  });

  group('typedInputHintTextDirection', () {
    test('returns LTR for numeric phone hint', () {
      expect(
        typedInputHintTextDirection('+964 770 000 0000'),
        TextDirection.ltr,
      );
    });

    test('returns null for empty hint', () {
      expect(typedInputHintTextDirection(null), isNull);
      expect(typedInputHintTextDirection(''), isNull);
    });
  });

  group('textDirectionForTypedChatMessage', () {
    test('delegates to typed content rules (digits are LTR)', () {
      expect(
        textDirectionForTypedChatMessage(
          '+964 770 000 0000',
          TextDirection.rtl,
        ),
        TextDirection.ltr,
      );
    });
  });
}
