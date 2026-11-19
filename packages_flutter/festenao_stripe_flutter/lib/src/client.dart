/// A Stripe key the manager works with: a name and a secret (`sk_`) or
/// restricted (`rk_`) key of one account, test or live.
class StripeManagerClient {
  /// The id in the store (`builtin_...` for a built-in one).
  final String id;

  /// The name shown.
  final String name;

  /// The secret or restricted key, never shown in full ([keyHint]).
  final String secretKey;

  /// Given by the app (debug keys), not stored, not deletable.
  final bool builtIn;

  /// A client [name] of [secretKey].
  StripeManagerClient({
    required this.id,
    required this.name,
    required this.secretKey,
    this.builtIn = false,
  });

  /// A live key: real money.
  bool get isLive => stripeManagerKeyIsLive(secretKey);

  /// A restricted key (`rk_`): some calls may be refused.
  bool get isRestricted => secretKey.startsWith('rk_');

  /// `sk_live_…a1b2`: the kind and the last 4 characters, never the key.
  String get keyHint => stripeManagerKeyHint(secretKey);

  /// `LIVE` or `TEST`.
  String get modeLabel => isLive ? 'LIVE' : 'TEST';

  @override
  String toString() => 'StripeManagerClient($id, $name, $keyHint)';
}

final _keyRegExp = RegExp(r'^(sk|rk)_(live|test)_[A-Za-z0-9]{8,}$');

/// The error of a pasted [key], null when it looks like a secret or a
/// restricted key (a publishable key `pk_` cannot read an account).
String? stripeManagerKeyError(String key) {
  var trimmed = key.trim();
  if (trimmed.isEmpty) {
    return 'Paste a secret (sk_...) or restricted (rk_...) key';
  }
  if (trimmed.startsWith('pk_')) {
    return 'A publishable key (pk_...) cannot read the account, use a '
        'secret or restricted key';
  }
  if (!_keyRegExp.hasMatch(trimmed)) {
    return 'Not a Stripe secret (sk_live_/sk_test_) or restricted '
        '(rk_live_/rk_test_) key';
  }
  return null;
}

/// A live key.
bool stripeManagerKeyIsLive(String key) =>
    key.startsWith('sk_live_') || key.startsWith('rk_live_');

/// The prefix and the last 4 characters of [key] (`sk_test_…a1b2`).
String stripeManagerKeyHint(String key) {
  var match = RegExp(r'^[a-z]+_(live|test)_').firstMatch(key);
  var prefix = match?.group(0) ?? '';
  var rest = key.substring(prefix.length);
  if (rest.length < 12) {
    return '$prefix…';
  }
  return '$prefix…${rest.substring(rest.length - 4)}';
}
