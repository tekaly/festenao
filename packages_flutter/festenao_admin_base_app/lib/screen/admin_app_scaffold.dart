import 'package:festenao_admin_base_app/screen/screen_import.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';

/// Class that maps Scaffold widget with some customizations (appBar, body, footer, drawer, floatingActionButton, bottomNavigationBar,...)
class FestenaoAdminAppScaffold extends StatefulWidget {
  const FestenaoAdminAppScaffold(
      {super.key,
      this.appBar,
      this.body,
      this.footer,
      this.drawer,
      this.floatingActionButton});

  final AppBar? appBar;
  final Widget? body;
  final Widget? footer;
  final Widget? drawer;
  final Widget? floatingActionButton;
  @override
  State<FestenaoAdminAppScaffold> createState() =>
      _FestenaoAdminAppScaffoldState();
}

const _appBarHeight = 32.0;
const _useAppBar = !kIsWeb;
// final _useAppBar = devWarning(true); // !kIsWeb;

class _AppBarHistory {
  final list = <String>[]; // <String>[];
  void add(String path) {
    if (list.lastOrNull == path) {
      return;
    }
    list.remove(path);
    list.add(path);

    if (list.length > 50) {
      // list = list.sublist(list.length - 25);
      list.removeRange(0, 10);
    }
  }
}

final _appBarHistory = _AppBarHistory();

class DebugAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget? appBar;
  const DebugAppBar({super.key, required this.appBar});

  Future<void> _goToPath(BuildContext context, String path) async {
    await ContentNavigator.of(context)
        .pushPath<void>(ContentPath.fromString(path));
  }

  @override
  Widget build(BuildContext context) {
    assert(_useAppBar);
    final routeName = Navigator.of(context).widget.pages.last.name;
    if (routeName != null) {
      _appBarHistory.add(routeName);
    }
    final appBar = this.appBar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  var list = _appBarHistory.list;
                  var newIndex = await muiSelectString(context, list: list);

                  if (newIndex != null && context.mounted) {
                    var newPath = list[newIndex];
                    await _goToPath(context, newPath);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  height: _appBarHeight,
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Colors.indigoAccent),
                  child: Text('$routeName'),
                ),
              ),
            ),
            SizedBox(
                height: _appBarHeight,
                child: IconButton(
                  onPressed: () async {
                    var newPath = await muiGetString(context, value: routeName);
                    if (newPath != null && context.mounted) {
                      await _goToPath(context, newPath);
                    }
                  },
                  icon: const Icon(Icons.edit),
                  iconSize: 16,
                )),
          ],
        ),
        if (appBar != null) appBar
      ],
    );
    /*AppBar(
      title: const Text('Festenao'), // appIntl(context).ProjectsTitle),
      actions: [
        IconButton(
            onPressed: () {
//              goToAuthScreen(context);
            },
            icon: const Icon(Icons.person)),
      ],
      // automaticallyImplyLeading: false,
    );*/
  }

  @override
  // TODO: implement preferredSize
  Size get preferredSize {
    assert(_useAppBar);
    var size = appBar?.preferredSize;
    return Size(
        size?.width ?? double.infinity, (size?.height ?? 0) + _appBarHeight);
  }
}

class _FestenaoAdminAppScaffoldState extends State<FestenaoAdminAppScaffold> {
  @override
  Widget build(BuildContext context) {
    var appBar = widget.appBar;
    return Scaffold(
      appBar: _useAppBar ? DebugAppBar(appBar: appBar) : appBar,
      body: widget.body,
      drawer: widget.drawer,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.footer,
    );
  }
}
