import 'package:flutter/material.dart';

/// An item with sub menu for using in popup menus
///
/// [title] is the text which will be displayed in the pop up
/// [items] is the list of items to populate the sub menu
/// [onSelected] is the callback to be fired if specific item is pressed
///
/// Selecting items from the submenu will automatically close the parent menu
/// Closing the sub menu by clicking outside of it, will automatically close the parent menu
class PopupSubMenuItem<T> extends PopupMenuEntry<T> {
  const PopupSubMenuItem({
    super.key,
    required this.title,
    required this.items,
    this.onSelected,
  });

  final String title;
  final List<T> items;
  final void Function(T value)? onSelected;

  @override
  double get height =>
      kMinInteractiveDimension; //Does not actually affect anything

  @override
  bool represents(T? value) =>
      false; //Our submenu does not represent any specific value for the parent menu

  @override
  State createState() => _PopupSubMenuState<T>();
}

/// The [State] for [PopupSubMenuItem] subclasses.
class _PopupSubMenuState<T> extends State<PopupSubMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: widget.title,
      onCanceled: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      onSelected: (T value) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        widget.onSelected?.call(value);
      },
      offset: Offset
          .zero, //TODO This is the most complex part - to calculate the correct position of the submenu being populated. For my purposes is does not matter where exactly to display it (Offset.zero will open submenu at the poistion where you tapped the item in the parent menu). Others might think of some value more appropriate to their needs.
      itemBuilder: (BuildContext context) {
        return widget.items
            .map(
              (item) => PopupMenuItem<T>(
                value: item,
                child: Text(item
                    .toString()), //MEthod toString() of class T should be overridden to repesent something meaningful
              ),
            )
            .toList();
      },
      child: Padding(
        padding: const EdgeInsets.only(
            left: 16.0, right: 8.0, top: 12.0, bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Expanded(
              child: Text(widget.title),
            ),
            Icon(
              Icons.arrow_right,
              size: 24.0,
              color: Theme.of(context).iconTheme.color,
            ),
          ],
        ),
      ),
    );
  }
}

abstract class MenuItemBase {
  String get title;
}

class SubMenuItem implements MenuItemBase {
  @override
  final String title;
  final List<MenuItem> items;

  SubMenuItem({required this.title, required this.items});
}

class MainMenuItem extends SubMenuItem {
  MainMenuItem({required super.title, required super.items});
}

class MenuItem implements MenuItemBase {
  @override
  final String title;
  final VoidCallback? onPressed;

  MenuItem({required this.title, this.onPressed});

  @override
  String toString() {
    return title;
  }
}

extension MenuItemFlutterExt on MenuItemBase {
  PopupMenuEntry<MenuItem> entry(BuildContext context) {
    var item = this;
    if (item is MenuItem) {
      return PopupMenuItem<MenuItem>(
        value: item,
        /*
        onTap: () {
          print('choice $item');
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          // Navigator.pop(context);
          item.onPressed!();
        },*/
        child: Text(title),
      );
    }
    if (item is SubMenuItem) {
      // print('sub items: ${item.items}');
      return PopupSubMenuItem<MenuItem>(
        title: title,
        items: item.items,
        onSelected: (sub) {
          // print('sub: $sub');
          sub.onPressed?.call();
        },
      );
    }
    throw UnsupportedError('Unsupported $item');
  }
}

extension MenuItemListFlutterExt on List<MenuItemBase> {
  List<PopupMenuEntry<MenuItem>> entries(BuildContext context) {
    return map((e) => e.entry(context)).toList();
  }

  Widget popupMenu(BuildContext context) {
    return PopupMenuButton<MenuItem>(
        onSelected: (item) {
          // print('item: $item');
          item.onPressed?.call();
        },
        itemBuilder: (_) => entries(context));
  }
}
