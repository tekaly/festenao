import 'package:festenao_riverpod/festenao_riverpod.dart'
    show festenaoWaitUntil;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Waiting on a provider from a widget.
extension FestenaoWidgetRefWaitExtension on WidgetRef {
  /// Waits until the value of [provider] passes [test] (the providers
  /// following a new user after a sign in, or leaving one after a sign
  /// out), at most [timeout] (5 seconds).
  ///
  /// Done at once when the value already passes. Listens to [provider]
  /// meanwhile (no polling). Returns true when it passed, false at the
  /// timeout: the caller goes on either way. A flow outliving its widget
  /// (a sign out) waits on the app container instead
  /// (`ProviderContainer.waitUntil`).
  Future<bool> waitUntil<T>(
    ProviderListenable<T> provider,
    bool Function(T value) test, {
    Duration timeout = const Duration(seconds: 5),
  }) => festenaoWaitUntil<T>(
    (listener) => listenManual<T>(provider, listener, fireImmediately: true),
    test,
    timeout: timeout,
  );
}
