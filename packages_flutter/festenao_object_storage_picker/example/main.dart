import 'dart:convert';

import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_object_storage_picker/festenao_object_storage_picker.dart';
import 'package:material_ui/material_ui.dart';

/// Picks files of an in memory storage (a memory sdb + file system): a few
/// files in `docs`, a sub folder.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var storage = ObjectStorageSdb.inMemory();
  for (var name in ['readme.txt', 'notes.txt']) {
    await storage.upload(
      'docs',
      name: name,
      data: Uint8List.fromList(utf8.encode('$name content')),
      mimeType: 'text/plain',
    );
  }
  await storage.upload(
    'docs/images',
    name: 'logo.png',
    data: Uint8List(4),
    mimeType: 'image/png',
  );
  runApp(MaterialApp(home: _HomeScreen(storage: storage)));
}

class _HomeScreen extends StatefulWidget {
  final ObjectStorage storage;

  const _HomeScreen({required this.storage});

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  var _picked = <ObjectStorageMeta>[];

  Future<void> _pick() async {
    var selected = await Navigator.of(context).push<List<ObjectStorageMeta>>(
      MaterialPageRoute(
        builder: (_) => ObjectStoragePickerScreen(
          storage: widget.storage,
          parentPath: 'docs',
          allowMultiSelect: true,
        ),
      ),
    );
    if (selected != null) {
      setState(() => _picked = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Object storage picker')),
      body: ListView(
        children: [
          for (var item in _picked)
            ListTile(title: Text(item.name), subtitle: Text(item.path)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pick,
        tooltip: 'Pick files',
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
