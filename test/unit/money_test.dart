import 'package:bill_tracker/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('parses decimal input to integer minor units', () {
      expect(Money.parse('1234.5')?.minorUnits, 123450);
      expect(Money.parse('-0.25')?.minorUnits, -25);
    });

    test('rejects malformed or over-precise amounts', () {
      expect(Money.parse('1,200.00'), isNull);
      expect(Money.parse('1.234'), isNull);
      expect(Money.parse(''), isNull);
    });

    test('adds values only when currencies match', () {
      expect(const Money(150) + const Money(75), const Money(225));
      expect(
        () => const Money(100) + const Money(100, currencyCode: 'USD'),
        throwsArgumentError,
      );
    });
  });
}
