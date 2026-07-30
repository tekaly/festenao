import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _projectPath = RoutePathDef.parse(
  '/project/:project_id',
  name: 'project',
);

/// Declared as a child of the project, but mounted at the top level — the way
/// a feature module contributes a screen it cannot nest into another module's
/// tree.
final _blogPath = _projectPath.child('blog_demo', name: 'blog_demo');

class _Screen extends StatelessWidget {
  const _Screen({required this.label, this.upPath});

  final String label;
  final RoutePathDef? upPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: upPath == null ? null : RouteUpBackButton(upPath: upPath),
        title: Text(label),
      ),
      body: TextButton(
        onPressed: () => context.pushPath(_blogPath),
        child: const Text('to blog'),
      ),
    );
  }
}

GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    _projectPath.goRoute(
      absolute: true,
      builder: (context, state) => const _Screen(label: 'project'),
    ),
    _blogPath.goRoute(
      absolute: true,
      builder: (context, state) => _Screen(label: 'blog', upPath: _projectPath),
    ),
  ],
);

Future<GoRouter> _pump(WidgetTester tester, String location) async {
  var router = _router(location);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('RouteUpBackButton', () {
    testWidgets('goes up when a deep link left nothing to pop', (tester) async {
      // Straight to the child location, as a fresh page load on the web does.
      var router = await _pump(tester, '/project/p1/blog_demo');
      expect(find.text('blog'), findsOneWidget);
      expect(router.canPop(), isFalse);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Up went to the parent, with `project_id` inherited from the location.
      expect(find.text('project'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/project/p1',
      );
    });

    testWidgets('pops when the screen was pushed', (tester) async {
      var router = await _pump(tester, '/project/p1');
      await tester.tap(find.text('to blog'));
      await tester.pumpAndSettle();
      expect(find.text('blog'), findsOneWidget);
      expect(router.canPop(), isTrue);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('project'), findsOneWidget);
    });

    testWidgets('popOrGoUp drops a segment when there is nothing to pop', (
      tester,
    ) async {
      var router = await _pump(tester, '/project/p1/blog_demo');
      var context = tester.element(find.text('blog'));
      context.popOrGoUp();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/project/p1',
      );
    });
  });
}
