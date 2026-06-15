import 'package:festenao_common/data/object_storage.dart';
import 'package:flutter/material.dart';
import 'folder_history_sdb.dart';
import 'object_storage_picker_screen.dart';

/// A helper screen that manages the flow of selecting a folder ID from history
/// or entering a URL/ID, then navigating to the file picker.
class ObjectStoragePickerFlowScreen extends StatefulWidget {
  /// The object storage implementation.
  final ObjectStorage storage;

  /// The history database manager.
  final FolderHistorySdb sdb;

  /// Optional list of allowed MIME types.
  final List<String>? allowedMimeTypes;

  /// Whether multi-selection is enabled.
  final bool allowMultiSelect;

  /// Whether developer mode is enabled.
  final bool developerMode;

  /// Constructor.
  const ObjectStoragePickerFlowScreen({
    super.key,
    required this.storage,
    required this.sdb,
    this.allowedMimeTypes,
    this.allowMultiSelect = false,
    this.developerMode = false,
  });

  /// Static helper to show the full flow in a pushed route.
  static Future<List<ObjectStorageMeta>?> show({
    required BuildContext context,
    required ObjectStorage storage,
    required FolderHistorySdb sdb,
    List<String>? allowedMimeTypes,
    bool allowMultiSelect = false,
    bool developerMode = false,
  }) {
    return Navigator.of(context).push<List<ObjectStorageMeta>>(
      MaterialPageRoute(
        builder: (context) => ObjectStoragePickerFlowScreen(
          storage: storage,
          sdb: sdb,
          allowedMimeTypes: allowedMimeTypes,
          allowMultiSelect: allowMultiSelect,
          developerMode: developerMode,
        ),
      ),
    );
  }

  @override
  State<ObjectStoragePickerFlowScreen> createState() =>
      _ObjectStoragePickerFlowScreenState();
}

class _ObjectStoragePickerFlowScreenState
    extends State<ObjectStoragePickerFlowScreen> {
  final _urlController = TextEditingController();
  String _parsedId = '';
  List<String> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    _loadHistory();
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });
    try {
      var list = await widget.sdb.getLatestFolderIds();
      setState(() {
        _history = list;
        _isLoadingHistory = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _onUrlChanged() {
    setState(() {
      _parsedId = parsePermissiveGDriveId(_urlController.text);
    });
  }

  /// Permissively parses the folder ID from Google Drive/Docs/Sheets/Slides URLs or raw inputs.
  static String parsePermissiveGDriveId(String input) {
    var trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // 1. Check for ?id=xxxx parameter
    if (trimmed.contains('id=')) {
      var parts = trimmed.split('id=');
      if (parts.length > 1) {
        var idPart = parts[1].split('&').first.split('#').first;
        if (idPart.isNotEmpty) return idPart;
      }
    }

    // 2. Check for /folders/xxxx
    if (trimmed.contains('/folders/')) {
      var parts = trimmed.split('/folders/');
      if (parts.length > 1) {
        var idPart = parts[1].split('?').first.split('/').first;
        if (idPart.isNotEmpty) return idPart;
      }
    }

    // 3. Check for /d/xxxx/ edit/view/etc patterns (Google Docs/Sheets/Slides/Files)
    if (trimmed.contains('/d/')) {
      var parts = trimmed.split('/d/');
      if (parts.length > 1) {
        var idPart = parts[1].split('?').first.split('/').first;
        if (idPart.isNotEmpty) return idPart;
      }
    }

    // 4. Check if it's a URL with slashes, take the last segment if nothing else matched
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        var uri = Uri.parse(trimmed);
        var segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          return segments.last;
        }
      } catch (_) {
        // Ignore URL parsing errors
      }
    }

    // 5. Fallback: return the trimmed input as a raw ID
    return trimmed;
  }

  Future<void> _openFolder(String folderId) async {
    if (folderId.isEmpty) return;

    // Save to history
    await widget.sdb.addFolderId(folderId);
    // Reload history list for display
    await _loadHistory();

    // Push the picker screen
    if (mounted) {
      final selected = await Navigator.of(context).push<List<ObjectStorageMeta>>(
        MaterialPageRoute(
          builder: (context) => ObjectStoragePickerScreen(
            title: 'Select Files',
            storage: widget.storage,
            parentPath: folderId,
            allowedMimeTypes: widget.allowedMimeTypes,
            allowMultiSelect: widget.allowMultiSelect,
            developerMode: widget.developerMode,
          ),
        ),
      );

      // If files were selected, pop and return them to the caller
      if (selected != null && mounted) {
        Navigator.of(context).pop(selected);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Google Drive Folder'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Folder URL or ID',
                hintText: 'Enter GDrive URL, Doc Link, or raw ID',
                border: const OutlineInputBorder(),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _urlController.clear(),
                      )
                    : null,
              ),
            ),
            if (_parsedId.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Parsed Folder ID: $_parsedId',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _parsedId.isEmpty ? null : () => _openFolder(_parsedId),
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Folder'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.history, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Recent Folders (Last 100)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _history.isEmpty
                      ? const Center(
                          child: Text(
                            'No folder history yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _history.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            var item = _history[index];
                            return ListTile(
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(
                                item,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openFolder(item),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
