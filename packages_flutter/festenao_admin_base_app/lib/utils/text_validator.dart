const textFieldCannotBeEmptyError = 'Ce champ ne peut pas être vide';
const textFieldNonIntError = 'Ce champ doit contenir un nombre entier';
const textFieldNotIdError =
    'Ce champ ne peut pas avoir que minuscules, chiffres et blanc souligné';

var allowedChars = 'abcdefghijklmnopqrstuvwxyz0123456789_'.split('');

/// ID validator
String? fieldIdValidator(String? text) {
  var result = fieldNonEmptyValidator(text);
  if (result != null) {
    return result;
  }
  for (var chr in text!.split('')) {
    if (!allowedChars.contains(chr)) {
      return textFieldNotIdError;
    }
  }
  return null;
}

String? fieldNonEmptyValidator(String? text) {
  if (text?.isEmpty ?? false) {
    return textFieldCannotBeEmptyError;
  }
  return null;
}

/// int validator
String? intValidator(String? text) {
  var result = fieldNonEmptyValidator(text);
  if (result != null) {
    return textFieldNonIntError;
  }
  if (int.tryParse(text!) == null) {
    return textFieldNonIntError;
  }
  return null;
}
