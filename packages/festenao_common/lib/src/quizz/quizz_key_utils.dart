import 'dart:math';

import 'package:uuid/uuid.dart';

/// Short lowercase key generator, for human friendly quiz ids.
class QuizIdGenerator {
  /// The number of characters generated.
  final int count;

  static const String _chars = 'abcdefghijklmnopqrstuvwxyz';
  static final _charsLength = _chars.length;

  static final Random _random = Random(DateTime.now().millisecondsSinceEpoch);

  /// Creates a generator of [count] characters keys.
  QuizIdGenerator(this.count);

  /// Generates a key.
  String generate() {
    final result = StringBuffer();

    for (var i = 0; i < count; i++) {
      result.write(_chars[_random.nextInt(_charsLength)]);
    }
    return result.toString();
  }
}

/// Generates a 4 letters quiz key.
String generateQuizKey() => QuizIdGenerator(4).generate();

/// Generates a device (controller) id, unique per install.
String quizzGenerateDeviceId() => const Uuid().v4();
