import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scoped by the shell route, must never be read outside of it.
final currentSchoolIdProvider = Provider<String>(
  (ref) => throw StateError('not scoped'),
);

/// A provider computed from the scoped one: it must declare the scoped
/// provider in its `dependencies` to be scoped along with it.
final scopedStateProvider = Provider<String>(
  (ref) => ref.watch(currentSchoolIdProvider),
  dependencies: [currentSchoolIdProvider],
);

/// The scoped containers seen by the shell builder, to tell a scope update
/// from a scope recreation.
var scopedContainers = <ProviderContainer>[];

var schoolListPath = RoutePathDef.parse('/school', name: 'school_list');
var schoolPath = schoolListPath.child(':school_id', name: 'school');
var studentListPath = schoolPath.child('student', name: 'student_list');
var studentPath = studentListPath.child(':student_id', name: 'student');
var clasListPath = schoolPath.child('clas', name: 'clas_list');

class _ScopedText extends ConsumerWidget {
  final String label;

  const _ScopedText(this.label);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text('$label ${ref.watch(scopedStateProvider)}');
  }
}

GoRouter _router({ScopedShellKeyBuilder? scopeKey}) {
  return GoRouter(
    initialLocation: '/school',
    routes: [
      schoolListPath.goRoute(
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.goPath(
              studentPath,
              parameters: {'school_id': '124', 'student_id': '456'},
            ),
            child: const Text('schools'),
          ),
        ),
      ),
      providerScopeShellRoute(
        scopeKey: scopeKey,
        overrides: (state) => [
          currentSchoolIdProvider.overrideWithValue(
            state.pathParameter('school_id'),
          ),
        ],
        builder: (context, state, child) {
          scopedContainers.add(
            ProviderScope.containerOf(context, listen: false),
          );
          return Scaffold(
            appBar: AppBar(title: const _ScopedText('shell')),
            body: child,
          );
        },
        routes: [
          schoolPath.goRoute(
            // Direct child of a top level shell: no parent route to be
            // relative to.
            absolute: true,
            builder: (context, state) => const _ScopedText('school'),
            routes: [
              studentListPath.goRoute(
                builder: (context, state) => const _ScopedText('students'),
                routes: [
                  studentPath.goRoute(
                    builder: (context, state) => Column(
                      children: [
                        _ScopedText(
                          'student ${state.pathParameter('student_id')}',
                        ),
                        TextButton(
                          onPressed: () => context.goSibling('clas', count: 2),
                          child: const Text('sideways'),
                        ),
                        TextButton(
                          onPressed: context.goUp,
                          child: const Text('up'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              clasListPath.goRoute(
                builder: (context, state) => const _ScopedText('clas'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    scopedContainers = [];
  });

  testWidgets('the shell scope is readable by the shell and its children', (
    tester,
  ) async {
    var router = _router();
    await _pumpRouter(tester, router);

    router.go('/school/124/student');
    await tester.pumpAndSettle();
    expect(find.text('shell 124'), findsOneWidget);
    expect(find.text('students 124'), findsOneWidget);
  });

  testWidgets('a deep link builds the whole scoped branch', (tester) async {
    var router = _router();
    await _pumpRouter(tester, router);

    router.go('/school/124/student/456');
    await tester.pumpAndSettle();
    expect(find.text('student 456 124'), findsOneWidget);
  });

  testWidgets('goPath inherits nothing when out of the branch', (tester) async {
    var router = _router();
    await _pumpRouter(tester, router);

    await tester.tap(find.text('schools'));
    await tester.pumpAndSettle();
    expect(find.text('student 456 124'), findsOneWidget);
  });

  testWidgets('goSibling and goUp move inside the branch', (tester) async {
    var router = _router();
    await _pumpRouter(tester, router);

    router.go('/school/124/student/456');
    await tester.pumpAndSettle();

    await tester.tap(find.text('up'));
    await tester.pumpAndSettle();
    expect(find.text('students 124'), findsOneWidget);

    router.go('/school/124/student/456');
    await tester.pumpAndSettle();
    await tester.tap(find.text('sideways'));
    await tester.pumpAndSettle();
    // The location was rebuilt from the active one, keeping the school id and
    // staying in the same scope.
    expect(router.state.uri.toString(), '/school/124/clas');
    expect(find.text('clas 124'), findsOneWidget);
  });

  testWidgets('without a scopeKey, the scope is updated, not recreated', (
    tester,
  ) async {
    var router = _router();
    await _pumpRouter(tester, router);

    router.go('/school/124/student');
    await tester.pumpAndSettle();
    expect(find.text('students 124'), findsOneWidget);

    router.go('/school/125/student');
    await tester.pumpAndSettle();
    expect(find.text('students 125'), findsOneWidget);
    // Same container, only the overridden value changed.
    expect(scopedContainers.toSet(), hasLength(1));
  });

  testWidgets('with a scopeKey, the scope is disposed and recreated', (
    tester,
  ) async {
    var router = _router(
      scopeKey: (state) => state.pathParameters['school_id'],
    );
    await _pumpRouter(tester, router);

    router.go('/school/124/student');
    await tester.pumpAndSettle();
    expect(find.text('students 124'), findsOneWidget);

    router.go('/school/125/student');
    await tester.pumpAndSettle();
    expect(find.text('students 125'), findsOneWidget);
    // A new container per school, the previous one is disposed.
    expect(scopedContainers.toSet(), hasLength(2));
  });
}
