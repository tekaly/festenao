import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_common_flutter/firestore_explorer_flutter.dart';
import 'package:flutter/material.dart';

import 'demo_data.dart';

/// The main menu: one entry per explorer, in the order they are worth trying.
///
/// Everything is read write — the demo is there to be edited — and everything
/// is in memory, so a restart brings the content back as it was.
class DemoHomePage extends StatelessWidget {
  /// What the explorers run on.
  final DemoData data;

  /// Home page on [data].
  const DemoHomePage({super.key, required this.data});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Festenao explorers demo')),
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
        const Divider(),
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
        const Divider(),
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
