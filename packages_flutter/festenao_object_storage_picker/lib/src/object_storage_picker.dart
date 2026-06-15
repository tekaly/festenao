import 'package:festenao_common/data/object_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Callback when files are selected.
typedef ObjectStoragePickerOnSelect =
    void Function(List<ObjectStorageMeta> selected);

/// A widget that allows browsing an [ObjectStorage] and picking files.
class ObjectStoragePicker extends StatefulWidget {
  /// The object storage implementation.
  final ObjectStorage storage;

  /// The root/parent folder path to browse.
  final String parentPath;

  /// Optional list of allowed MIME types (e.g. ['image/*', 'application/pdf']).
  /// If null or empty, all MIME types are allowed.
  final List<String>? allowedMimeTypes;

  /// Callback when files are chosen.
  final ObjectStoragePickerOnSelect onSelect;

  /// Whether multi-selection is enabled.
  final bool allowMultiSelect;

  /// Whether developer mode is enabled.
  final bool developerMode;

  /// Create a new [ObjectStoragePicker] widget.
  const ObjectStoragePicker({
    super.key,
    required this.storage,
    required this.parentPath,
    this.allowedMimeTypes,
    required this.onSelect,
    this.allowMultiSelect = false,
    this.developerMode = false,
  });

  @override
  State<ObjectStoragePicker> createState() => _ObjectStoragePickerState();
}

class _ObjectStoragePickerState extends State<ObjectStoragePicker> {
  late String _currentPath;
  final List<String> _pathStack = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<ObjectStorageMeta> _items = [];
  final Set<ObjectStorageMeta> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _currentPath = widget.parentPath;
    _pathStack.add(_currentPath);
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _items = [];
    });

    try {
      var response = await widget.storage.list(_currentPath);
      setState(() {
        _items = response.items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load files: $e';
        _isLoading = false;
      });
    }
  }

  bool _isMimeTypeAllowed(String? mimeType) {
    if (widget.allowedMimeTypes == null || widget.allowedMimeTypes!.isEmpty) {
      return true;
    }
    if (mimeType == null) {
      return false;
    }
    for (var pattern in widget.allowedMimeTypes!) {
      if (pattern == mimeType) {
        return true;
      }
      if (pattern.endsWith('/*')) {
        var prefix = pattern.substring(0, pattern.length - 2);
        if (mimeType.startsWith(prefix)) {
          return true;
        }
      }
    }
    return false;
  }

  void _navigateInto(String path) {
    print('Navigating into $path');
    setState(() {
      _currentPath = path;
      _pathStack.add(path);
    });
    _loadItems();
  }

  void _navigateBack() {
    if (_pathStack.length > 1) {
      setState(() {
        _pathStack.removeLast();
        _currentPath = _pathStack.last;
      });
      _loadItems();
    }
  }

  void _navigateToIndex(int index) {
    if (index >= 0 && index < _pathStack.length) {
      setState(() {
        _pathStack.removeRange(index + 1, _pathStack.length);
        _currentPath = _pathStack.last;
      });
      _loadItems();
    }
  }

  void _toggleSelection(ObjectStorageMeta item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        if (!widget.allowMultiSelect) {
          _selectedItems.clear();
        }
        _selectedItems.add(item);
      }
    });
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.movie;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType.startsWith('text/')) return Icons.description;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  Future<void> _openInBrowser(ObjectStorageMeta item) async {
    String urlString;
    if (item.path.startsWith('http://') || item.path.startsWith('https://')) {
      urlString = item.path;
    } else {
      urlString = 'https://drive.google.com/open?id=${item.path}';
    }
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch browser for $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error launching browser: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter items: show all directories, and only allowed files
    var displayItems = _items.where((item) {
      return item.isLocation || _isMimeTypeAllowed(item.mimeType);
    }).toList();

    return Column(
      children: [
        // Path navigation/Breadcrumb bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Row(
            children: [
              if (_pathStack.length > 1)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateBack,
                  tooltip: 'Go up',
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_pathStack.length, (index) {
                      var path = _pathStack[index];
                      var name = path == widget.parentPath
                          ? 'Root'
                          : path
                                .split('/')
                                .lastWhere(
                                  (p) => p.isNotEmpty,
                                  orElse: () => 'Folder',
                                );
                      var isLast = index == _pathStack.length - 1;

                      return Row(
                        children: [
                          if (index > 0)
                            const Icon(Icons.chevron_right, size: 16),
                          TextButton(
                            onPressed: isLast
                                ? null
                                : () => _navigateToIndex(index),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: isLast
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isLast
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of items
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadItems,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : displayItems.isEmpty
              ? const Center(child: Text('This folder is empty.'))
              : ListView.separated(
                  itemCount: displayItems.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    var item = displayItems[index];
                    var isSelected = _selectedItems.contains(item);

                    if (item.isLocation) {
                      return ListTile(
                        leading: const Icon(Icons.folder, color: Colors.amber),
                        title: Text(item.name),
                        subtitle: widget.developerMode
                            ? Text(
                                'ID: ${item.path}',
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.developerMode)
                              IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () => _openInBrowser(item),
                                tooltip: 'Open in browser',
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _navigateInto(item.path),
                      );
                    } else {
                      return ListTile(
                        leading: Icon(
                          _getFileIcon(item.mimeType),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.blueGrey,
                        ),
                        title: Text(item.name),
                        subtitle: widget.developerMode
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.size != null)
                                    Text(
                                      '${(item.size! / 1024).toStringAsFixed(1)} KB',
                                    ),
                                  Text(
                                    'ID: ${item.path}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              )
                            : (item.size != null
                                  ? Text(
                                      '${(item.size! / 1024).toStringAsFixed(1)} KB',
                                    )
                                  : null),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.developerMode)
                              IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () => _openInBrowser(item),
                                tooltip: 'Open in browser',
                              ),
                            if (widget.allowMultiSelect)
                              Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(item),
                              )
                            else if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                        selected: isSelected,
                        onTap: () {
                          if (widget.allowMultiSelect) {
                            _toggleSelection(item);
                          } else {
                            widget.onSelect([item]);
                          }
                        },
                      );
                    }
                  },
                ),
        ),

        // Multi-select actions bar
        if (widget.allowMultiSelect)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Text('${_selectedItems.length} items selected'),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _selectedItems.isEmpty
                        ? null
                        : () => widget.onSelect(_selectedItems.toList()),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
