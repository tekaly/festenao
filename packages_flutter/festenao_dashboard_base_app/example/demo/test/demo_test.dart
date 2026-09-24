import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_dashboard_app_demo/main.dart';
import 'package:festenao_dashboard_app_demo/src/demo_cms.dart';
import 'package:festenao_dashboard_app_demo/src/demo_data.dart';
import 'package:festenao_dashboard_app_demo/src/demo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// See the explorer tests: the backends are really asynchronous, so the demo
/// runs with real timers.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void _testWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    await tester.runAsync(() async {
      // The home page carries a theme picker above the menu, so the window
      // has to be tall enough for the last entry to be built.
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      try {
        await body(tester);
      } finally {
        await tester.binding.setSurfaceSize(null);
      }
    });
  });
}

void main() {
  group('the demo data', () {
    test(
      'builds a firestore tree, users, documents and two databases',
      () async {
        var data = await DemoData.create();

        // Firestore: the collections, and a sub collection under a document.
        var collections = await data.firestore.listCollections();
        expect(collections.map((collection) => collection.id).toSet(), {
          'settings',
          'user',
          'event',
        });
        expect(
          (await data.firestore.doc('user/alice').listCollections()).map(
            (collection) => collection.id,
          ),
          ['note'],
        );

        // The users: alice and bob match the user documents, and anonymous,
        // disabled and phone only ones show what a listing marks.
        var users = (await data.auth.listUsers()).users.nonNulls;
        expect(users.map((user) => user.uid), [
          'alice',
          'anonymous-visitor',
          'bob',
          'carol',
          'dave',
          'erin',
        ]);
        expect((await data.firestore.doc('user/bob').get()).exists, isTrue);

        // The file system: one document of each kind, and a sub directory.
        var entries = await data.explorer.list();
        expect(entries.map((entry) => entry.name), [
          'data',
          'sub',
          'config.json',
          'notes.txt',
          'picture.bin',
          'settings.yaml',
        ]);

        // The databases, one of each kind, found by walking the tree.
        var databases = await listFileSystemDatabases(data.explorer);
        expect(
          {for (var (entry, kind) in databases) entry.name: kind},
          {
            'sdb_demo.db': FileSystemDatabaseKind.sdb,
            'sembast_demo.db': FileSystemDatabaseKind.sembast,
          },
        );
      },
    );

    test('builds a cms site whose every link leads somewhere', () async {
      var data = await DemoData.create();
      var cms = data.cms;
      expect((await cms.pages.getPages()).length, demoCmsPages().length);
      var published = await cms.pages.getPages(publishedOnly: true);
      expect(
        published.map((page) => page.slug.v),
        isNot(contains('line-up-2027')),
      );

      // Crawl the site from the index as a search engine would: every link
      // within the site is a page that is served.
      var handler = CmsSiteHandler(
        pages: cms.pages,
        renderer: cms.renderer,
        pageOptions: cms.pageOptions,
      );
      var hrefRegExp = RegExp(r'href="([^"]+)"');
      var visited = <String>{};
      var toVisit = ['', 'sitemap.xml', 'robots.txt'];
      while (toVisit.isNotEmpty) {
        var path = toVisit.removeLast();
        if (!visited.add(path)) {
          continue;
        }
        var response = await handler.handlePath(path);
        expect(response.statusCode, 200, reason: path);
        var url = Uri.parse(handler.urlOf(path));
        for (var match in hrefRegExp.allMatches(response.body)) {
          var target = handler.pathOf(url.resolve(match.group(1)!));
          if (target != null) {
            toVisit.add(target);
          }
        }
      }
      // Every published page is reached, the draft is not.
      for (var page in published) {
        expect(visited, contains('page/${page.slug.v}'));
      }
      expect(visited, isNot(contains('page/line-up-2027')));

      // The pages presenting an item carry its structured data.
      var event = await handler.handlePath('page/opening-night-concert');
      expect(event.body, contains('"@type":"Event"'));
      expect(event.body, contains('<dt>Date</dt><dd>2027-07-09 20:00</dd>'));
      // The no index page stays out of the sitemap.
      var sitemap = await handler.handlePath('sitemap.xml');
      expect(sitemap.body, isNot(contains('page/legal')));
    });

    test('is editable and loses the edits on a restart', () async {
      var data = await DemoData.create();
      expect(data.explorer.isReadOnly, isFalse);
      await data.explorer.writeAsString('config.json', '{"edited": true}');
      expect(
        await data.explorer.readAsString('config.json'),
        '{"edited": true}',
      );

      // A fresh start builds the demo content again, the edit gone with the
      // file system it was made in.
      var restarted = await DemoData.create();
      expect(
        await restarted.explorer.readAsString('config.json'),
        demoJsonContent,
      );
    });
  });

  group('the demo app', () {
    _testWidgets('offers every explorer, in order', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      var titles = find
          .descendant(of: find.byType(ListTile), matching: find.byType(Text))
          .evaluate()
          .map((element) => (element.widget as Text).data)
          .toList();
      expect(
        titles,
        containsAllInOrder([
          'Firestore explorer',
          'Users explorer',
          'File system explorer',
          'Sdb explorer',
          'Sembast explorer',
        ]),
      );
    });

    _testWidgets('swaps the theme from the home screen', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      // Every theme is offered, the first one being on.
      for (var demoTheme in demoThemes()) {
        expect(find.text(demoTheme.name), findsWidgets);
      }
      var before = Theme.of(
        tester.element(find.text('Firestore explorer')),
      ).colorScheme;
      expect(before.brightness, Brightness.light);

      // The dark one is another brightness, and the explorers follow it
      // without a colour of their own.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Material dark'));
      await _settle(tester);
      var after = Theme.of(
        tester.element(find.text('Firestore explorer')),
      ).colorScheme;
      expect(after.brightness, Brightness.dark);
      expect(after.surface, isNot(before.surface));

      // And it carries into the screens it opens.
      await tester.tap(find.text('File system explorer'));
      await _settle(tester);
      expect(
        Theme.of(
          tester.element(find.text('config.json')),
        ).colorScheme.brightness,
        Brightness.dark,
      );
    });

    _testWidgets('offers the poppins themes', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Festenao poppins dark'),
      );
      await _settle(tester);
      var theme = Theme.of(tester.element(find.text('Firestore explorer')));
      expect(theme.colorScheme.brightness, Brightness.dark);
      // The poppins themes carry the rules of themeData1: floating snack
      // bars, and a font family of their own.
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.textTheme.bodyMedium?.fontFamily, isNotNull);
    });

    _testWidgets('opens the firestore explorer on the demo tree', (
      tester,
    ) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('Firestore explorer'));
      await _settle(tester);
      expect(find.text('settings'), findsOneWidget);
      expect(find.text('user'), findsOneWidget);

      await tester.tap(find.text('settings'));
      await _settle(tester);
      await tester.tap(find.text('main'));
      await _settle(tester);
      // The document, with its types.
      expect(find.text('updatedAt'), findsOneWidget);
      expect(find.byIcon(Icons.event), findsOneWidget);
      expect(find.text('48.8584,2.2945'), findsOneWidget);
    });

    _testWidgets('opens the users explorer on the demo users', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('Users explorer'));
      await _settle(tester);
      expect(find.text('6 users'), findsOneWidget);
      expect(find.text('Dave (disabled)'), findsOneWidget);

      await tester.tap(find.text('Alice'));
      await _settle(tester);
      expect(find.text('alice@example.com'), findsOneWidget);
    });

    _testWidgets('opens the sdb databases and edits a record', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('Sdb explorer'));
      await _settle(tester);
      expect(find.text('sdb_demo.db'), findsOneWidget);
      // Only the sdb one, the sembast database is left out.
      expect(find.text('sembast_demo.db'), findsNothing);

      await tester.tap(find.text('sdb_demo.db'));
      await _settle(tester);
      expect(find.text('note'), findsOneWidget);

      await tester.tap(find.text('note'));
      await _settle(tester);
      await tester.tap(find.text('first'));
      await _settle(tester);
      // Full edition: the record opens in the editor, save and all.
      expect(find.text('title'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    _testWidgets('opens the sembast databases', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('Sembast explorer'));
      await _settle(tester);
      expect(find.text('sembast_demo.db'), findsOneWidget);
      expect(find.text('sdb_demo.db'), findsNothing);

      await tester.tap(find.text('sembast_demo.db'));
      await _settle(tester);
      expect(find.text('settings'), findsOneWidget);
      expect(find.text('event'), findsOneWidget);
    });

    _testWidgets('manages the cms pages', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('CMS pages'));
      await _settle(tester);
      // Drafts included, with their publish toggle.
      expect(find.text('About the festival'), findsOneWidget);
      expect(find.text('Line-up 2027'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);

      // A page, as the app shows it, then as the site serves it.
      await tester.tap(find.text('Program'));
      await _settle(tester);
      expect(find.byType(CmsPagePreviewScreen), findsOneWidget);
      await tester.tap(find.byTooltip('View the generated html'));
      await _settle(tester);
      expect(find.byType(CmsSiteBrowserScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://festival.example.com/page/program',
      );

      // And the editor, from the browser.
      await tester.tap(find.byTooltip('Edit this page'));
      await _settle(tester);
      expect(find.byType(CmsPageEditScreen), findsOneWidget);
      expect(find.text('Body (markdown)'), findsOneWidget);
    });

    _testWidgets('browses the generated cms site', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('CMS site'));
      await _settle(tester);
      // The index: a card per published page.
      expect(
        find.text(
          'Three days of music, workshops and night markets by the lake.',
        ),
        findsWidgets,
      );
      expect(find.text('Line-up 2027'), findsNothing);

      // The header navigation, then a link of the body.
      await tester.tap(find.widgetWithText(TextButton, 'Program'));
      await _settle(tester);
      expect(
        find.text('Who plays when, and where.', findRichText: true),
        findsOneWidget,
      );
      await tester.tapOnText(
        find.textRange.ofSubstring('Opening night concert').first,
      );
      await _settle(tester);
      expect(find.text('2027-07-09 20:00', findRichText: true), findsOneWidget);

      // Its head, with the event structured data.
      await tester.tap(find.text('SEO'));
      await _settle(tester);
      expect(find.text('Opening night concert'), findsWidgets);
      expect(find.text('og:type'), findsOneWidget);
      expect(find.text('event'), findsOneWidget);
    });

    _testWidgets('opens the file system explorer, writable', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('File system explorer'));
      await _settle(tester);
      expect(find.text('config.json'), findsOneWidget);
      expect(find.text('picture.bin'), findsOneWidget);
      // Writable: the create button is there, no padlock.
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });
  });

  group('project urls', () {
    _testWidgets('checks, claims and resolves slugs', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);
      await tester.scrollUntilVisible(find.text('Project urls'), 200);
      await tester.tap(find.text('Project urls'));
      await _settle(tester);

      var slugField = find.byType(TextField).first;
      await tester.enterText(slugField, 'festival');
      await _settle(tester);
      expect(find.text('Already taken'), findsOneWidget);

      await tester.enterText(slugField, 'My URL');
      await _settle(tester);
      expect(find.text('Available'), findsOneWidget);
      await tester.tap(find.text('Use this url'));
      await _settle(tester);
      expect(find.text('/p/my-url'), findsOneWidget);
      expect(find.text('Current url'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Open a link'),
        'https://my-app.web.app/p/festival',
      );
      await tester.tap(find.text('Resolve'));
      await _settle(tester);
      expect(find.text('Project fest (an old url of it)'), findsOneWidget);
    });
  });
}
