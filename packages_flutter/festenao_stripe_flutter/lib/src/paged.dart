import 'package:flutter/foundation.dart';

/// Reads the page after [startingAfter] (the first one when null):
/// `(items, hasMore)`.
typedef StripeManagerPageReader<T> = Future<(List<T>, bool)> Function(
  String? startingAfter,
);

/// A Stripe list read page by page on demand ([loadMore]), kept in memory
/// (the service caches it per list, see `StripeManagerService.pagedList`):
/// coming back to a screen shows what was read, [refresh] reads again from
/// the first page.
class StripeManagerPagedList<T> extends ChangeNotifier {
  final StripeManagerPageReader<T> _readPage;
  final String? Function(T item) _idOf;

  /// The items read so far, newest first.
  final items = <T>[];

  /// More pages exist (true until the last page is read).
  var hasMore = true;

  /// A page is being read.
  var loading = false;

  /// The error of the last read, if it failed.
  Object? error;

  /// When the first page was read.
  DateTime? loadedAt;

  var _generation = 0;
  var _disposed = false;

  /// A list read with [readPage], [idOf] giving the cursor of the next page.
  StripeManagerPagedList({required this._readPage, required this._idOf});

  /// Nothing read nor being read yet.
  bool get isFresh => loadedAt == null && !loading && error == null;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Reads the next page (nothing when one is being read or none is left).
  Future<void> loadMore() async {
    if (loading || !hasMore || _disposed) {
      return;
    }
    String? startingAfter;
    if (items.isNotEmpty) {
      startingAfter = _idOf(items.last);
      if (startingAfter == null) {
        hasMore = false;
        _notify();
        return;
      }
    }
    var generation = _generation;
    loading = true;
    error = null;
    _notify();
    try {
      var (data, more) = await _readPage(startingAfter);
      if (generation != _generation) {
        return;
      }
      items.addAll(data);
      hasMore = more && data.isNotEmpty;
      loadedAt ??= DateTime.now();
    } catch (e) {
      if (generation != _generation) {
        return;
      }
      error = e;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  /// Forgets what was read and reads the first page again.
  Future<void> refresh() {
    _generation++;
    items.clear();
    hasMore = true;
    loading = false;
    error = null;
    loadedAt = null;
    _notify();
    return loadMore();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
