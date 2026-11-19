import 'package:tekartik_stripe_api/stripe_api.dart';

/// [cents] of [currency] as `12.50 €` (`12.50 USD` for another currency).
String stripeManagerFormatAmount(int? cents, [String? currency]) {
  if (cents == null) {
    return '-';
  }
  var negative = cents < 0;
  var abs = cents.abs();
  var text = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  var code = (currency ?? stripeCurrencyEuro).toLowerCase();
  var symbol = code == stripeCurrencyEuro ? '€' : code.toUpperCase();
  return '${negative ? '-' : ''}$text $symbol';
}

/// [cents] as `12.50` for a csv (no currency).
String stripeManagerFormatCsvAmount(int? cents) {
  if (cents == null) {
    return '';
  }
  var negative = cents < 0;
  var abs = cents.abs();
  return '${negative ? '-' : ''}${abs ~/ 100}.'
      '${(abs % 100).toString().padLeft(2, '0')}';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// A Stripe date (unix [seconds]) as a local `2026-11-19 14:05`.
String stripeManagerFormatDateTime(int? seconds) {
  var dateTime = stripeApiDateTime(seconds)?.toLocal();
  if (dateTime == null) {
    return '-';
  }
  return '${stripeManagerFormatDay(seconds)} '
      '${_two(dateTime.hour)}:${_two(dateTime.minute)}';
}

/// A Stripe date (unix [seconds]) as a local `2026-11-19`.
String stripeManagerFormatDay(int? seconds) {
  var dateTime = stripeApiDateTime(seconds)?.toLocal();
  if (dateTime == null) {
    return '-';
  }
  return '${dateTime.year}-${_two(dateTime.month)}-${_two(dateTime.day)}';
}

/// A period to look at.
enum StripeManagerPeriod {
  /// The last 7 days.
  days7('7 days'),

  /// The last 30 days.
  days30('30 days'),

  /// The last 90 days.
  days90('90 days'),

  /// Since January 1st.
  thisYear('This year'),

  /// The last 365 days.
  days365('365 days'),

  /// Everything.
  all('All');

  /// The label shown.
  final String label;

  const StripeManagerPeriod(this.label);

  /// The start of the period at [now] (null for [all]).
  DateTime? start([DateTime? now]) {
    now ??= DateTime.now();
    return switch (this) {
      days7 => now.subtract(const Duration(days: 7)),
      days30 => now.subtract(const Duration(days: 30)),
      days90 => now.subtract(const Duration(days: 90)),
      thisYear => DateTime(now.year),
      days365 => now.subtract(const Duration(days: 365)),
      all => null,
    };
  }

  /// [start] as Stripe seconds.
  int? startSeconds([DateTime? now]) {
    var start = this.start(now);
    return start == null ? null : stripeApiSeconds(start);
  }
}

/// A csv field, quoted when needed.
String stripeManagerCsvField(Object? value) {
  var text = value?.toString() ?? '';
  if (text.contains(RegExp(r'[",\n\r;]'))) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// [rows] as csv lines.
String stripeManagerCsv(List<List<Object?>> rows) =>
    '${rows.map((row) => row.map(stripeManagerCsvField).join(',')).join('\n')}'
    '\n';
