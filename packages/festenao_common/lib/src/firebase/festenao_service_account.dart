import 'dart:convert';

/// The service account json [text] as a map, null when it is not one.
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

/// What is wrong with the service account [map], null when nothing is.
///
/// It checks the fields a service account is unusable without, so a typo is
/// caught when it is given rather than on the first request. The message
/// never quotes a value: the private key must not end up in a log.
String? festenaoServiceAccountMapError(Map? map) {
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

/// What is wrong with the service account json [text], null when nothing is.
String? festenaoServiceAccountTextError(String? text) {
  if (text == null || text.trim().isEmpty) {
    return 'The service account json is empty';
  }
  return festenaoServiceAccountMapError(
    festenaoServiceAccountMapFromText(text),
  );
}
