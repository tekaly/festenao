/// Renders every screen of the demo and writes it as a png.
///
/// It goes through the flutter test pipeline rather than a running window:
/// the widgets are the real ones and so is the rendering, but nothing needs a
/// display, and each screen is reached on purpose rather than by driving a
/// window.
///
/// ```sh
/// flutter test tool/screenshot_test.dart
/// ```
///
/// The users explorer screens go to their own folder when
/// `FESTENAO_DEMO_USER_SCREENSHOT_DIR` is defined (the user management
/// screens, kept apart). The fonts and the session come from
/// `festenao_screenshot`.
library;

import 'dart:io';

import 'package:festenao_dashboard_app_demo/src/demo_data.dart';
import 'package:festenao_dashboard_app_demo/src/demo_home_page.dart';
import 'package:festenao_dashboard_app_demo/src/demo_theme.dart';
import 'package:festenao_screenshot/festenao_screenshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Where the pngs land.
const screenshotDirectory = String.fromEnvironment(
  'FESTENAO_DEMO_SCREENSHOT_DIR',
  defaultValue: '.local/screenshots_1',
);

/// Where the users explorer pngs land, [screenshotDirectory] when empty.
const userScreenshotDirectory = String.fromEnvironment(
  'FESTENAO_DEMO_USER_SCREENSHOT_DIR',
);

/// The window the screens are rendered in.
const screenshotSize = Size(1100, 800);

/// The session of the run.
late ScreenshotSession _session;

/// Lets the really asynchronous backends settle, pumping between real delays.
Future<void> _settle(WidgetTester tester) => _session.settle();

/// Writes what is on screen as `NN_name.png`, in [userScreenshotDirectory]
/// for a [user] management screen when it is defined.
Future<void> _shot(
  WidgetTester tester,
  String name, {
  bool user = false,
}) async {
  var apart = user && userScreenshotDirectory.isNotEmpty;
  await _session.shot(
    name,
    directory: apart ? Directory(userScreenshotDirectory) : null,
  );
}

/// Taps [finder] and lets things settle.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

/// Scrolls the menu to [text], then taps it: the menu is taller than the
/// window.
Future<void> _tapMenu(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await _tap(tester, find.text(text));
}

/// Goes back one screen.
Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await _settle(tester);
}

void main() {
  runScreenshots(
    'every screen',
    (session) async {
      _session = session;
      var tester = session.tester;
      await session.setSize(screenshotSize);
      var data = await DemoData.create();
      var themes = demoThemes();
      var themeIndex = 0;
      late StateSetter setTheme;

      await tester.pumpWidget(
        session.wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setTheme = setState;
              return MaterialApp(
                title: 'Festenao explorers demo',
                debugShowCheckedModeBanner: false,
                theme: themes[themeIndex].build(),
                home: DemoHomePage(
                  data: data,
                  themes: themes,
                  themeIndex: themeIndex,
                  onThemeChanged: (index) => setTheme(() => themeIndex = index),
                ),
              );
            },
          ),
        ),
      );
      await _shot(tester, 'main_menu');

      /// Shows the same screen under another theme.
      Future<void> withTheme(int index, String name) async {
        setTheme(() => themeIndex = index);
        await _shot(tester, name);
      }

      // ---- firestore ----
      await _tap(tester, find.text('Firestore explorer'));
      await _shot(tester, 'firestore_collections');

      await _tap(tester, find.text('user'));
      await _shot(tester, 'firestore_documents');

      await _tap(tester, find.text('alice'));
      await _shot(tester, 'firestore_document_editor');

      // A row menu, showing what a value offers.
      await _tap(
        tester,
        find.descendant(
          of: find
              .ancestor(of: find.text('joinedAt'), matching: find.byType(Row))
              .last,
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await _shot(tester, 'firestore_value_menu');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      await _back(tester);
      await _back(tester);

      // The settings document holds every firestore type.
      await _tap(tester, find.text('settings'));
      await _tap(tester, find.text('main'));
      await _shot(tester, 'firestore_every_type');
      await _back(tester);
      await _back(tester);

      // The backup dialog.
      await _tap(
        tester,
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.backup_outlined),
        ),
      );
      await _shot(tester, 'firestore_backup_formats');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      await _back(tester);

      // ---- users ----
      await _tap(tester, find.text('Users explorer'));
      await _shot(tester, 'users_list', user: true);

      await _tap(tester, find.text('Alice'));
      await _shot(tester, 'user_fields', user: true);
      await _back(tester);

      await _tap(tester, find.byTooltip('New user'));
      await _shot(tester, 'user_new_dialog', user: true);
      await _tap(tester, find.text('Cancel'));
      await _back(tester);

      // ---- file system ----
      await _tap(tester, find.text('File system explorer'));
      await _shot(tester, 'file_system_listing');

      await _tap(tester, find.text('config.json'));
      await _shot(tester, 'json_editor');
      await _back(tester);

      await _tap(tester, find.text('settings.yaml'));
      await _shot(tester, 'yaml_editor');
      await _back(tester);

      await _tap(tester, find.text('notes.txt'));
      await _shot(tester, 'text_editor');
      await _back(tester);

      await _tap(tester, find.text('picture.bin'));
      await _shot(tester, 'hex_editor');
      await _back(tester);

      // What the + menu creates.
      await _tap(tester, find.byIcon(Icons.add));
      await _shot(tester, 'file_system_new_menu');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      await _back(tester);

      // ---- sdb ----
      await _tap(tester, find.text('Sdb explorer'));
      await _shot(tester, 'sdb_database_list');

      await _tap(tester, find.text('sdb_demo.db'));
      await _shot(tester, 'sdb_stores');

      await _tap(tester, find.text('note'));
      await _shot(tester, 'sdb_records');

      await _tap(tester, find.text('first'));
      await _shot(tester, 'sdb_record_editor');
      await _back(tester);
      await _back(tester);
      await _back(tester);
      await _back(tester);

      // ---- sembast ----
      await _tap(tester, find.text('Sembast explorer'));
      await _shot(tester, 'sembast_database_list');

      await _tap(tester, find.text('sembast_demo.db'));
      await _shot(tester, 'sembast_stores');

      await _tap(tester, find.text('settings'));
      await _tap(tester, find.text('main'));
      await _shot(tester, 'sembast_record_editor');
      await _back(tester);
      await _back(tester);
      await _back(tester);
      await _back(tester);

      // ---- cms: the pages ----
      await _tapMenu(tester, 'CMS pages');
      await _shot(tester, 'cms_pages');

      await _tap(tester, find.text('Opening night concert'));
      await _shot(tester, 'cms_page_preview');

      await _tap(tester, find.byTooltip('Edit'));
      await _shot(tester, 'cms_page_editor');
      await _back(tester);
      await _back(tester);
      await _back(tester);

      // ---- cms: the generated site ----
      await _tapMenu(tester, 'CMS site');
      await _shot(tester, 'cms_site_index');

      await _tap(tester, find.widgetWithText(TextButton, 'Program'));
      await _shot(tester, 'cms_site_program');

      await tester.tapOnText(
        find.textRange.ofSubstring('Opening night concert').first,
      );
      await _shot(tester, 'cms_site_event');

      await _tap(tester, find.text('Html'));
      await _shot(tester, 'cms_site_html_source');

      await _tap(tester, find.text('SEO'));
      await _shot(tester, 'cms_site_seo');
      await _tap(tester, find.text('Rendered'));

      await _tap(tester, find.byTooltip('Go to'));
      await _tap(tester, find.text('sitemap.xml'));
      await _shot(tester, 'cms_site_sitemap');

      // A draft, served once the drafts are.
      await tester.enterText(find.byType(TextField), '/page/line-up-2027');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _shot(tester, 'cms_site_draft_not_found');
      await _tap(tester, find.widgetWithText(FilterChip, 'Drafts'));
      await _shot(tester, 'cms_site_draft');
      await _back(tester);

      // ---- cms: the raw records ----
      await _tapMenu(tester, 'CMS database');
      await _tap(tester, find.text('cms_page'));
      await _shot(tester, 'cms_database_records');
      await _back(tester);
      await _back(tester);

      // ---- every database together ----
      await _tapMenu(tester, 'Every database');
      await _shot(tester, 'every_database');
      await _back(tester);

      // ---- editing a value in memory ----
      await _tapMenu(tester, 'Edit an object in memory');
      await _shot(tester, 'edit_object_in_memory');

      // The type selector, on the count field.
      await _tap(
        tester,
        find.descendant(
          of: find
              .ancestor(of: find.text('count'), matching: find.byType(Row))
              .last,
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await _tap(tester, find.text('Change type'));
      await _shot(tester, 'type_selector');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);

      // The menu under each theme: the explorers take no colour of their
      // own, so this is what the themes do to them.
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      // Back to the menu, and with nothing left hanging over it: the editor
      // says what it answered on the way out. The tap that dismissed the
      // dialog may have landed on the back button already, so this pops only
      // while the menu is still covered.
      while (find.byType(DemoHomePage).evaluate().isEmpty) {
        await _back(tester);
      }
      // From inside the app, where the messenger lives.
      ScaffoldMessenger.of(tester.element(find.byType(DemoHomePage)))
          .clearSnackBars();
      await _settle(tester);

      // The menu from its top.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await _settle(tester);

      for (var (index, demoTheme) in themes.indexed.skip(1)) {
        await withTheme(
          index,
          'theme_${demoTheme.name.toLowerCase().replaceAll(' ', '_')}',
        );
      }
      setTheme(() => themeIndex = 0);
    },
    directory: Directory(screenshotDirectory),
    clear: [
      if (userScreenshotDirectory.isNotEmpty)
        Directory(userScreenshotDirectory),
    ],
    settleRounds: 25,
  );
}
