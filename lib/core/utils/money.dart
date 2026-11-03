import 'package:bill_tracker/core/constants/currency_constants.dart';
import 'package:bill_tracker/core/validators/money_input_parser.dart';
import 'package:intl/intl.dart';

/// Stores monetary values as integer minor units (centavos for PHP).
final class Money {
  const Money(
    this.minorUnits, {
    this.currencyCode = CurrencyConstants.defaultCode,
  });

  final int minorUnits;
  final String currencyCode;

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currencyCode: currencyCode);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currencyCode: currencyCode);
  }

  String format({String locale = CurrencyConstants.defaultLocale}) {
    final NumberFormat formatter = NumberFormat.currency(
      locale: locale,
      name: currencyCode,
      symbol: currencyCode == CurrencyConstants.defaultCode
          ? CurrencyConstants.defaultSymbol
          : currencyCode,
      decimalDigits: 2,
    );
    return formatter.format(minorUnits / 100);
  }

  static Money? parse(
    String input, {
    String currencyCode = CurrencyConstants.defaultCode,
  }) {
    final int? minorUnits = parseMinorUnits(input);
    if (minorUnits == null) return null;
    return Money(minorUnits, currencyCode: currencyCode);
  }

  void _requireSameCurrency(Money other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError('Cannot combine different currencies.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);
}
