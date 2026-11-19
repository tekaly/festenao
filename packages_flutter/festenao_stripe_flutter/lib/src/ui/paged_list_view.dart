import 'package:material_ui/material_ui.dart';
import 'package:tekartik_stripe_api/stripe_api.dart';

import '../paged.dart';

/// The items of a [StripeManagerPagedList], shown as soon as the first page
/// is read; the next page is read when the end of the list comes into view.
/// Pull down (or the refresh action of the screen) reads it again.
class StripeManagerPagedListView<T> extends StatefulWidget {
  /// The list.
  final StripeManagerPagedList<T> list;

  /// The view of an item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Shown when the list is empty.
  final String emptyText;

  /// The name of the items in the footer (`12 links`).
  final String itemsName;

  /// A view of [list].
  const StripeManagerPagedListView({
    super.key,
    required this.list,
    required this.itemBuilder,
    this.emptyText = 'Nothing',
    this.itemsName = 'items',
  });

  @override
  State<StripeManagerPagedListView<T>> createState() =>
      _StripeManagerPagedListViewState<T>();
}

class _StripeManagerPagedListViewState<T>
    extends State<StripeManagerPagedListView<T>> {
  StripeManagerPagedList<T> get list => widget.list;

  @override
  void initState() {
    super.initState();
    _startIfFresh();
  }

  @override
  void didUpdateWidget(covariant StripeManagerPagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.list, widget.list)) {
      _startIfFresh();
    }
  }

  void _startIfFresh() {
    if (list.isFresh) {
      // Not during the build.
      WidgetsBinding.instance.addPostFrameCallback((_) => list.loadMore());
    }
  }

  Widget _error(Object error) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(stripeApiErrorMessage(error), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: list.loadMore, child: const Text('Retry')),
      ],
    ),
  );

  Widget _footer(BuildContext context) {
    var error = list.error;
    if (error != null) {
      return _error(error);
    }
    if (list.hasMore) {
      if (!list.loading) {
        // The end is in view: read the next page.
        WidgetsBinding.instance.addPostFrameCallback((_) => list.loadMore());
      }
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          '${list.items.length} ${widget.itemsName}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: list,
      builder: (context, _) {
        var items = list.items;
        if (items.isEmpty) {
          var error = list.error;
          if (error != null) {
            return Center(child: _error(error));
          }
          if (list.loading || list.hasMore) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(child: Text(widget.emptyText));
        }
        return RefreshIndicator(
          onRefresh: list.refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length + 1,
            itemBuilder: (context, index) => index < items.length
                ? widget.itemBuilder(context, items[index])
                : _footer(context),
          ),
        );
      },
    );
  }
}
