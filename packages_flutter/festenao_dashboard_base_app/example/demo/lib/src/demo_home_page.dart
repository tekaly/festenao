import 'package:festenao_cms_flutter/festenao_cms_flutter.dart'
    show cmsHtmlFrameSupported;
import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_common_flutter/firestore_explorer_flutter.dart';
import 'package:flutter/material.dart';

import 'demo_cms_navigation.dart';
import 'demo_data.dart';
import 'demo_theme.dart';

/// The main menu: one entry per explorer, in the order they are worth trying.
///
/// Everything is read write — the demo is there to be edited — and everything
/// is in memory, so a restart brings the content back as it was.
class DemoHomePage extends StatelessWidget {
  /// What the explorers run on.
  final DemoData data;

  /// The themes offered, [demoThemes] by default.
  final List<DemoTheme> themes;

  /// Which one is on.
  final int themeIndex;

  /// Picks another one.
  final ValueChanged<int>? onThemeChanged;

  /// Home page on [data].
  const DemoHomePage({
    super.key,
    required this.data,
    this.themes = const [],
    this.themeIndex = 0,
    this.onThemeChanged,
  });

  /// The theme picker: the explorers take no colour of their own, so swapping
  /// the theme is how to see that they follow it.
  Widget _buildThemePicker(BuildContext context) {
    var theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExplorerSectionHeader(label: 'Theme'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var (index, demoTheme) in themes.indexed)
                ChoiceChip(
                  label: Text(demoTheme.name),
                  selected: index == themeIndex,
                  onSelected: (_) => onThemeChanged?.call(index),
                ),
            ],
          ),
        ),
        if (themes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              themes[themeIndex].description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Festenao explorers & cms demo'),
      actions: [
        if (themes.isNotEmpty)
          ExplorerChip(
            label: themes[themeIndex].name,
            icon: Icons.palette_outlined,
            tone: ExplorerChipTone.accent,
          ),
        const SizedBox(width: 12),
      ],
    ),
    body: ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Everything below is in memory and fully editable. '
            'Nothing is written to the disk, and a restart brings the demo '
            'content back as it was.',
          ),
        ),
        if (themes.isNotEmpty) ...[
          _buildThemePicker(context),
          const SizedBox(height: 8),
        ],
        const ExplorerSectionHeader(label: 'Explorers'),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Firestore explorer'),
          subtitle: const Text(
            'Collections, a sub collection, and every firestore type',
          ),
          onTap: () => goToFirestoreExplorerScreen(
            context,
            firestore: data.firestore,
            backupExplorer: data.explorer,
            title: 'Firestore (memory)',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.folder_open_outlined),
          title: const Text('File system explorer'),
          subtitle: const Text(
            'Json, yaml, text, binary, and the databases below',
          ),
          onTap: () =>
              goToFileSystemExplorerScreen(context, explorer: data.explorer),
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('Sdb explorer'),
          subtitle: const Text('The sdb databases of the demo file system'),
          onTap: () => goToFileSystemDatabaseListScreen(
            context,
            explorer: data.explorer,
            kind: FileSystemDatabaseKind.sdb,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Sembast explorer'),
          subtitle: const Text('The sembast databases of the demo file system'),
          onTap: () => goToFileSystemDatabaseListScreen(
            context,
            explorer: data.explorer,
            kind: FileSystemDatabaseKind.sembast,
          ),
        ),
        const ExplorerSectionHeader(label: 'CMS'),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('CMS pages'),
          subtitle: const Text(
            'Manage the pages: publish, create, edit, preview',
          ),
          onTap: () => data.cms.openPages(context),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('CMS site'),
          subtitle: const Text(
            'The generated html, navigated like the web site: rendered, '
            'source or SEO view',
          ),
          onTap: () => data.cms.browseSite(context),
        ),
        if (cmsHtmlFrameSupported)
          ListTile(
            leading: const Icon(Icons.open_in_browser),
            title: const Text('CMS site, browser rendering'),
            subtitle: const Text(
              'The same html drawn by the browser itself, css included, '
              'in a sandboxed frame (web only)',
            ),
            onTap: () => data.cms.browseSiteInBrowser(context),
          ),
        ListTile(
          leading: const Icon(Icons.table_rows_outlined),
          title: const Text('CMS database'),
          subtitle: const Text('The raw page records, in the object explorer'),
          onTap: () => data.cms.exploreDatabase(context),
        ),
        const ExplorerSectionHeader(label: 'More'),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Every database'),
          subtitle: const Text(
            'Sembast and sdb together, told apart by what '
            'each file holds',
          ),
          onTap: () => goToFileSystemDatabaseListScreen(
            context,
            explorer: data.explorer,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: const Text('Edit an object in memory'),
          subtitle: const Text(
            'The editor on a value, answering what it became',
          ),
          onTap: () async {
            var edited = await editObject(context, {
              'name': 'in memory',
              'count': 1,
              'when': DateTime.now().toUtc(),
              'tags': ['one', 'two'],
            }, title: 'An object');
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      edited == null
                          ? 'Left without saving'
                          : 'Edited: $edited',
                    ),
                  ),
                );
            }
          },
        ),
      ],
    ),
  );
}
