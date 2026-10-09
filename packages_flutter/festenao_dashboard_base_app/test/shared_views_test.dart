import 'dart:async';

import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      // A new scope for each pump: the overrides of a scope do not change.
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: festenaoAdminAppAllLocalizationsDelegates,
        supportedLocales: festenaoAdminAppSupportedLocales,
        home: home,
      ),
    );

/// An edit screen with pending changes, opened from [_Home].
class _Edit extends StatefulWidget {
  final Future<void> Function()? save;
  const _Edit({this.save});

  @override
  State<_Edit> createState() => _EditState();
}

class _EditState extends State<_Edit> with UnsavedChangesStateMixin<_Edit> {
  var pending = true;

  @override
  bool get hasPendingChanges => pending;

  @override
  Future<void> Function()? get saveAndLeave => widget.save;

  @override
  Widget build(BuildContext context) => wrapUnsavedChanges(
    child: Scaffold(appBar: AppBar(title: const Text('edit'))),
  );
}

class _Home extends StatelessWidget {
  final Future<void> Function()? save;
  const _Home({this.save});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => _Edit(save: save))),
      child: const Text('open'),
    ),
  );
}

void main() {
  group('unsaved changes', () {
    Future<void> openAndBack(
      WidgetTester tester, {
      Future<void> Function()? save,
    }) async {
      await tester.pumpWidget(_app(_Home(save: save)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    testWidgets('without save: discard or stay', (tester) async {
      await openAndBack(tester);
      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('edit'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('with save: the screen saves and leaves', (tester) async {
      var saved = false;
      late BuildContext editContext;
      await openAndBack(
        tester,
        save: () async {
          saved = true;
          Navigator.of(editContext).pop();
        },
      );
      editContext = tester.element(find.text('edit'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isTrue);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('no pending change: leaves', (tester) async {
      await tester.pumpWidget(_app(const _Home()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      tester.state<_EditState>(find.byType(_Edit)).pending = false;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('sync button', () {
    Future<void> pump(WidgetTester tester, SyncedDbSyncStatus? status) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(
              actions: const [
                ProjectContentSyncButton(projectId: 'p', dataId: 'd'),
              ],
            ),
          ),
          overrides: [
            // The content never opens here: the button stays disabled.
            projectContentProvider(
              'p',
              'd',
            ).overrideWith((ref) => Completer<SdbProjectContent>().future),
            projectContentSyncStatusProvider('p', 'd').overrideWith(
              (ref) =>
                  status == null ? const Stream.empty() : Stream.value(status),
            ),
          ],
        ),
      );
      await tester.pump();
    }

    testWidgets('idle, syncing, failed', (tester) async {
      await pump(tester, null);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.byTooltip('Synchronize'), findsOneWidget);

      await pump(
        tester,
        const SyncedDbSyncStatus(
          initialSync: SyncedDbInitialSync.thisSession,
          activity: SyncedDbSyncActivity.syncing,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pump(
        tester,
        const SyncedDbSyncStatus(
          initialSync: SyncedDbInitialSync.previousSession,
          activity: SyncedDbSyncActivity.retryScheduled,
          failureCount: 2,
        ),
      );
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
      expect(
        find.byTooltip('Synchronization failed, tap to retry'),
        findsOneWidget,
      );
    });
  });

  testWidgets('export viewer wraps and unwraps', (tester) async {
    await tester.pumpWidget(
      _app(
        const DataExportViewScreen(
          title: 'Export',
          content: '{"a":1}\n{"b":2}',
          filename: 'export.jsonl',
        ),
      ),
    );
    expect(find.text('{"a":1}\n{"b":2}'), findsOneWidget);
    expect(find.byTooltip('Wrap lines'), findsOneWidget);
    await tester.tap(find.byTooltip('Wrap lines'));
    await tester.pump();
    expect(find.byTooltip('Do not wrap lines'), findsOneWidget);
    expect(find.byTooltip('Download'), findsOneWidget);
  });
}
