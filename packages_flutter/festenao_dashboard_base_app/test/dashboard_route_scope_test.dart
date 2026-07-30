import 'dart:async';

import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_dashboard_base_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows whatever the scope holds, so a test can read it back from the tree.
class _ScopeProbe extends ConsumerWidget {
  const _ScopeProbe({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var projectId = ref.watch(currentProjectIdProvider);
    var dataId = ref.watch(currentDataIdProvider);
    return Scaffold(
      appBar: AppBar(title: Text('$label $projectId/$dataId')),
      body: const SizedBox.shrink(),
    );
  }
}

/// `/project/:project_id/probe`, the project id only.
final _projectProbePath = dashboardProjectPath.child('probe', name: 'probe');

/// `/project/:project_id/data/:data_id/probe`, both ids from the location.
final _dataProbePath = dashboardProjectDataPath.child(
  'probe',
  name: 'data_probe',
);

/// `/project/:project_id/fixed_probe`, a data id fixed by the route.
final _fixedProbePath = dashboardProjectPath.child(
  'fixed_probe',
  name: 'fixed_probe',
);

/// Two branches declared apart, the way two feature modules would.
GoRouter _router(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    _projectProbePath.goRoute(
      absolute: true,
      builder: (context, state) =>
          dashboardProjectScope(state, child: const _ScopeProbe(label: 'a')),
    ),
    _dataProbePath.goRoute(
      absolute: true,
      builder: (context, state) =>
          dashboardProjectScope(state, child: const _ScopeProbe(label: 'b')),
    ),
    _fixedProbePath.goRoute(
      absolute: true,
      builder: (context, state) => dashboardProjectScope(
        state,
        dataId: 'blog',
        child: const _ScopeProbe(label: 'c'),
      ),
    ),
  ],
);

Future<GoRouter> _pump(WidgetTester tester, String location) async {
  var router = _router(location);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('dashboard route scope', () {
    testWidgets('exposes the project id', (tester) async {
      await _pump(tester, '/project/p1/probe');
      // The data id falls back to its default outside a data branch.
      expect(find.text('a p1/content'), findsOneWidget);
    });

    testWidgets('exposes both ids when the location has them', (tester) async {
      await _pump(tester, '/project/p1/data/d1/probe');
      expect(find.text('b p1/d1'), findsOneWidget);
    });

    testWidgets('a fixed data id wins over the default', (tester) async {
      await _pump(tester, '/project/p1/fixed_probe');
      expect(find.text('c p1/blog'), findsOneWidget);
    });

    testWidgets('the scope follows the location', (tester) async {
      var router = await _pump(tester, '/project/p1/probe');
      router.go('/project/p2/data/d2/probe');
      await tester.pumpAndSettle();
      expect(find.text('b p2/d2'), findsOneWidget);
    });

    testWidgets('a push between two scoped branches can be popped', (
      tester,
    ) async {
      // The regression this guards: scoping used to be a ShellRoute, which owns
      // a nested Navigator, so pushing from a route of one branch to a route of
      // another landed on a fresh stack — no back button, nothing to pop.
      var router = await _pump(tester, '/project/p1/probe');
      expect(find.text('a p1/content'), findsOneWidget);

      unawaited(router.push('/project/p1/fixed_probe'));
      await tester.pumpAndSettle();
      expect(find.text('c p1/blog'), findsOneWidget);

      // The pushed page is on the same navigator: it has a back button…
      expect(find.byType(BackButton), findsOneWidget);
      // …and popping comes back to the project screen.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('a p1/content'), findsOneWidget);
    });
  });
}
