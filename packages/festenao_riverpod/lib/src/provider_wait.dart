import 'dart:async';

import 'package:riverpod/misc.dart' show ProviderListenable;
import 'package:riverpod/riverpod.dart';

/// Waits until a value [listen] delivers passes [test], at most [timeout]
/// (5 seconds): the shared body of the `waitUntil` of a [ProviderContainer]
/// (here) and of a flutter `WidgetRef` (festenao_riverpod_flutter).
///
/// [listen] subscribes the listener it is given to a provider, the current
/// value first (`fireImmediately: true`); the subscription is closed when
/// done. Returns true when a value passed, false at the timeout.
Future<bool> festenaoWaitUntil<T>(
  ProviderSubscription<T> Function(void Function(T? previous, T next) listener)
  listen,
  bool Function(T value) test, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  var passed = Completer<bool>();
  var subscription = listen((previous, next) {
    if (!passed.isCompleted && test(next)) {
      passed.complete(true);
    }
  });
  var timer = Timer(timeout, () {
    if (!passed.isCompleted) {
      passed.complete(false);
    }
  });
  try {
    return await passed.future;
  } finally {
    timer.cancel();
    subscription.close();
  }
}

/// Waiting on a provider of a container.
extension FestenaoProviderContainerWaitExtension on ProviderContainer {
  /// Waits until the value of [provider] passes [test] (the providers
  /// following a new user after a sign in, or leaving one after a sign
  /// out), at most [timeout] (5 seconds).
  ///
  /// Done at once when the value already passes. Listens to [provider]
  /// meanwhile (no polling). Returns true when it passed, false at the
  /// timeout: the caller goes on either way.
  Future<bool> waitUntil<T>(
    ProviderListenable<T> provider,
    bool Function(T value) test, {
    Duration timeout = const Duration(seconds: 5),
  }) => festenaoWaitUntil<T>(
    (listener) => listen<T>(provider, listener, fireImmediately: true),
    test,
    timeout: timeout,
  );
}
