import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

/// A user id a test sets.
class _UserId extends Notifier<String?> {
  @override
  String? build() => 'u1';

  /// Sets [userId].
  void set(String? userId) => state = userId;
}

final _userIdProvider = NotifierProvider<_UserId, String?>(_UserId.new);

void main() {
  group('ProviderContainer.waitUntil', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('at once when it already passes', () async {
      expect(
        await container.waitUntil(_userIdProvider, (id) => id == 'u1'),
        isTrue,
      );
    });

    test('when the value changes (a sign out)', () async {
      var done = container.waitUntil(_userIdProvider, (id) => id != 'u1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      container.read(_userIdProvider.notifier).set(null);
      expect(await done, isTrue);
    });

    test('false at the timeout', () async {
      expect(
        await container.waitUntil(
          _userIdProvider,
          (id) => id == 'u2',
          timeout: const Duration(milliseconds: 50),
        ),
        isFalse,
      );
    });
  });
}
