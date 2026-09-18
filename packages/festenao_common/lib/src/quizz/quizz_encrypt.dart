import 'package:tekartik_app_crypto/encrypt_codec.dart';

/// The default password of [quizzModelEncryptionCodec].
///
/// An app should set its own with [quizzSetModelEncryptionPassword] before
/// any quiz is created: the codec is what hides the correct answers of a quiz
/// document and signs a player result, both stay compatible as long as the
/// password does not change.
const quizzDefaultModelEncryptionPassword = 'FestenaoQuizzDefaultPassword2026';

EncryptCodec _codec = defaultEncryptCodec(
  rawPassword: quizzDefaultModelEncryptionPassword,
);

/// The codec hiding the correct answers in a quiz document and signing a
/// player result, see [quizzSetModelEncryptionPassword].
EncryptCodec get quizzModelEncryptionCodec => _codec;

/// Sets the password of [quizzModelEncryptionCodec].
///
/// [rawPassword] is a 32 characters string.
void quizzSetModelEncryptionPassword(String rawPassword) {
  _codec = defaultEncryptCodec(rawPassword: rawPassword);
}
