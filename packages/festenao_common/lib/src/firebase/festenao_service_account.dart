import 'dart:convert';

import 'package:tekartik_app_crypto/encrypt.dart';
import 'package:tekartik_app_crypto/password_generator.dart';

/// The `type` of the obfuscated json of a service account
/// ([festenaoServiceAccountEncMap]), where a service account says
/// `service_account`.
const festenaoServiceAccountEncType = 'service_account_enc';

/// The key lengths aes takes as a password, in bytes.
const _encPasswordLengths = [16, 24, 32];

/// The service account json [text] as a map, null when it is not one.
///
/// The map is read as it is: an obfuscated json
/// ([festenaoServiceAccountMapIsEnc]) is decoded by
/// [festenaoServiceAccountMapDecode].
Map<String, Object?>? festenaoServiceAccountMapFromText(String? text) {
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  try {
    var decoded = jsonDecode(text);
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  } catch (_) {
    return null;
  }
}

/// What is wrong with the service account [map] (a plain one), null when
/// nothing is: the fields it is unusable without.
String? _plainMapError(Map? map) {
  if (map == null) {
    return 'The service account is not a json object';
  }
  for (var key in ['project_id', 'client_email', 'private_key']) {
    var value = map[key];
    if (value is! String || value.isEmpty) {
      return 'The service account has no $key';
    }
  }
  return null;
}

/// What is wrong with the service account [map], null when nothing is.
///
/// It checks the fields a service account is unusable without, so a typo is
/// caught when it is given rather than on the first request. An obfuscated
/// json ([festenaoServiceAccountMapIsEnc]) is decoded first. The message
/// never quotes a value: the private key must not end up in a log.
String? festenaoServiceAccountMapError(Map? map) {
  if (map != null && festenaoServiceAccountMapIsEnc(map)) {
    try {
      festenaoServiceAccountMapFromEncMap(map);
      return null;
    } on StateError catch (e) {
      return e.message;
    }
  }
  return _plainMapError(map);
}

/// What is wrong with the service account json [text], null when nothing is.
String? festenaoServiceAccountTextError(String? text) {
  if (text == null || text.trim().isEmpty) {
    return 'The service account json is empty';
  }
  return festenaoServiceAccountMapError(
    festenaoServiceAccountMapFromText(text),
  );
}

/// The obfuscated json of [serviceAccount], as a map: the project id, the
/// account email and the key id in clear, the whole service account aes
/// encrypted with [password] (`enc`), the password next to it.
///
/// ```json
/// {
///   "type": "service_account_enc",
///   "project_id": "my-project",
///   "client_email": "firebase-adminsdk-xxx@my-project.iam.gserviceaccount.com",
///   "private_key_id": "0a1b...",
///   "password": "<16, 24 or 32 characters>",
///   "enc": "<aes, base 64>"
/// }
/// ```
///
/// The password is in the file: this hides the key from a glance, a grep or
/// a secret scanner, nothing more. It is for a git ignored file of a folder
/// (`.local/service_account_enc.json`) on a developer machine that holds the
/// key anyway. [password] is 16, 24 or 32 ascii characters, a random one by
/// default, so the same account never obfuscates the same way twice.
///
/// [serviceAccount] may be an obfuscated json already: it is decoded first.
/// Throws an [ArgumentError] when it is not a usable service account.
Map<String, Object?> festenaoServiceAccountEncMap(
  Map serviceAccount, {
  String? password,
}) {
  Map<String, Object?> plain;
  try {
    plain = festenaoServiceAccountMapDecode(serviceAccount)!;
  } on StateError catch (e) {
    throw ArgumentError(e.message);
  }
  var error = _plainMapError(plain);
  if (error != null) {
    throw ArgumentError(error);
  }
  password ??= generatePassword();
  if (!_encPasswordLengths.contains(utf8.encode(password).length)) {
    throw ArgumentError('The password must be 16, 24 or 32 ascii characters');
  }
  return {
    'type': festenaoServiceAccountEncType,
    'project_id': plain['project_id'],
    'client_email': plain['client_email'],
    if (plain['private_key_id'] case String privateKeyId)
      'private_key_id': privateKeyId,
    'password': password,
    'enc': aesEncrypt(jsonEncode(plain), password),
  };
}

/// True when [map] is the obfuscated json of a service account
/// ([festenaoServiceAccountEncMap]): it has `enc` and `password`.
bool festenaoServiceAccountMapIsEnc(Map? map) =>
    map != null && map['enc'] is String && map['password'] is String;

/// The service account of its obfuscated json [encMap]
/// ([festenaoServiceAccountEncMap]).
///
/// Throws a [StateError] when [encMap] is not one, does not decode as a
/// service account (a wrong password, a damaged text), or is not the one of
/// the project it says in clear; the message never quotes a value.
Map<String, Object?> festenaoServiceAccountMapFromEncMap(Map encMap) {
  if (!festenaoServiceAccountMapIsEnc(encMap)) {
    throw StateError('Not an obfuscated service account (no enc and password)');
  }
  Map<String, Object?>? map;
  try {
    map = festenaoServiceAccountMapFromText(
      aesDecrypt(encMap['enc'] as String, encMap['password'] as String),
    );
  } catch (_) {
    // Not decrypted: said below.
  }
  if (map == null) {
    throw StateError(
      'The obfuscated service account does not decrypt (enc or password)',
    );
  }
  var error = _plainMapError(map);
  if (error != null) {
    throw StateError('Obfuscated: $error');
  }
  var projectId = encMap['project_id'];
  if (projectId != null && projectId != map['project_id']) {
    throw StateError(
      'The obfuscated service account is not the one of project $projectId',
    );
  }
  return map;
}

/// [map] as a service account: itself, or the one of an obfuscated json
/// ([festenaoServiceAccountMapIsEnc], decoded by
/// [festenaoServiceAccountMapFromEncMap], which throws a [StateError] when
/// it does not decode); null when [map] is null.
Map<String, Object?>? festenaoServiceAccountMapDecode(Map? map) {
  if (map == null) {
    return null;
  }
  if (festenaoServiceAccountMapIsEnc(map)) {
    return festenaoServiceAccountMapFromEncMap(map);
  }
  return map is Map<String, Object?> ? map : map.cast<String, Object?>();
}
