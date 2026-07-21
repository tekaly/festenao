import 'dart:io';
import 'dart:typed_data';

import 'package:festenao_admin_base_app/file_picker/file_picker.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContentMediaEditScreen extends ConsumerStatefulWidget {
  static const editRouteName = 'content_media_edit';
  static const createRouteName = 'content_media_create';
  static const editRouteLocation =
      '/project/:project_id/data/:data_id/media_edit/:media_id';
  static const createRouteLocation =
      '/project/:project_id/data/:data_id/media_create';
  static const projectIdPathParameter = 'project_id';
  static const dataIdPathParameter = 'data_id';
  static const mediaIdPathParameter = 'media_id';

  static String location(String projectId, String dataId, {String? mediaId}) {
    var baseLoc = '/project/$projectId/data/$dataId';
    return mediaId == null
        ? '$baseLoc/media_create'
        : '$baseLoc/media_edit/$mediaId';
  }

  final String projectId;
  final String dataId;

  /// null means creating a new media file
  final String? mediaId;

  const ContentMediaEditScreen({
    super.key,
    required this.projectId,
    required this.dataId,
    this.mediaId,
  });

  @override
  ConsumerState<ContentMediaEditScreen> createState() =>
      _ContentMediaEditScreenState();
}

class _ContentMediaEditScreenState
    extends ConsumerState<ContentMediaEditScreen> {
  final _filenameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;

  FestenaoMediaFile? _pickedMediaFile;
  Uint8List? _pickedBytes;
  String? _pickedType;

  @override
  void dispose() {
    _filenameCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.mediaId == null;

    final mediaAsync = isNew
        ? const AsyncData<SdbFestenaoMediaFile?>(null)
        : ref.watch(
            mediaEntryProvider(
              widget.projectId,
              widget.dataId,
              widget.mediaId!,
            ),
          );

    final contentSdbAsync = ref.watch(
      contentSdbProvider(widget.projectId, widget.dataId),
    );

    // Initialize form fields from existing media on first load
    if (!isNew) {
      ref.listen(
        mediaEntryProvider(widget.projectId, widget.dataId, widget.mediaId!),
        (_, next) {
          next.whenData((media) {
            if (media != null && !_initialized) {
              _initialized = true;
              _filenameCtrl.text = media.originalFilename.v ?? '';
              _typeCtrl.text = media.type.v ?? '';
            }
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Media' : 'Edit Media'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: contentSdbAsync.hasValue && !_isSaving
                  ? () => _onDelete(context, contentSdbAsync.value!)
                  : null,
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isNew && mediaAsync.value == null && mediaAsync.hasValue)
                const ListTile(title: Text('Not found')),
              TextField(
                controller: _filenameCtrl,
                decoration: const InputDecoration(labelText: 'Filename'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _typeCtrl,
                decoration: const InputDecoration(labelText: 'Mime Type'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: const Text('Pick File'),
              ),
              const SizedBox(height: 80),
            ],
          ),
          if (_isSaving)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: contentSdbAsync.hasValue && !_isSaving
            ? () => _onSave(context, contentSdbAsync.value!)
            : null,
        child: const Icon(Icons.save),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await pickAnyFile(context);
    if (result == null) return;
    //print('result: $result');
    final file = result.files.firstOrNull;
    if (file == null) return;

    var fileName = file.name;
    if (fileName.trim().isEmpty) {
      return;
    }
    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    if (mounted) {
      setState(() {
        _pickedBytes = bytes;

        final mediaFile = FestenaoMediaFile.from(
          filename: fileName,
          size: _pickedBytes!.length,
        );
        _pickedMediaFile = mediaFile;
        //_pickedType = lookupMimeType(file.name);
        _filenameCtrl.text = file.name;
        _typeCtrl.text = mediaFile.type;
      });
    }
  }

  Future<void> _onSave(BuildContext context, SdfContentSdb sdb) async {
    if (_isSaving) return;
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      final filename = _filenameCtrl.text.trim();
      final type = _typeCtrl.text.trim();

      if (widget.mediaId == null) {
        if (_pickedBytes == null) {
          _showError(context, 'Please pick a file first.');
          return;
        }
        final mediaFile = FestenaoMediaFile.from(
          filename: filename.isNotEmpty
              ? filename
              : _pickedMediaFile!.originalFilename,
          size: _pickedBytes!.length,
          type: type.isNotEmpty ? type : _pickedType,
        );
        await sdb.mediaDb.addMediaFile(file: mediaFile, bytes: _pickedBytes!);
      } else {
        if (_pickedBytes != null) {
          final mediaFile = _mediaFileForId(
            widget.mediaId!,
            filename.isNotEmpty ? filename : _pickedMediaFile!.originalFilename,
            _pickedBytes!.length,
            type: type.isNotEmpty ? type : _pickedType,
          );
          await sdb.mediaDb.addMediaFile(file: mediaFile, bytes: _pickedBytes!);
        } else {
          // Update metadata only
          var record = await sdb.mediaDb.getMediaFileRecord(widget.mediaId!);
          if (record != null) {
            if (filename.isNotEmpty) record.originalFilename.v = filename;
            if (type.isNotEmpty) record.type.v = type;
            await sdb.db.inScvStoresTransaction(
              [sdbMediaStore],
              SdbTransactionMode.readWrite,
              (txn) => record.put(txn),
            );
          }
        }
      }

      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _showError(context, 'Save failed: $e');
    } finally {
      if (context.mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onDelete(BuildContext context, SdfContentSdb sdb) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Media'),
        content: const Text('Delete this media file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await sdb.mediaDb.deleteMediaFile(widget.mediaId!);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) _showError(context, 'Delete failed: $e');
    } finally {
      if (context.mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

FestenaoMediaFile _mediaFileForId(
  String uid,
  String filename,
  int size, {
  String? type,
}) {
  final baseName = FestenaoMediaFile.buildOriginalFilename(filename);
  final ext = baseName.contains('.')
      ? baseName.split('.').last.toLowerCase()
      : 'bin';
  final path = [
    uid.substring(0, 2).toLowerCase(),
    uid.substring(2, 4).toLowerCase(),
    uid.substring(4, 6).toLowerCase(),
    '$uid.$ext',
  ].join('/');
  return FestenaoMediaFile(
    uid: uid,
    type: filenameMimeType(baseName),
    originalFilename: baseName,
    path: path,
    size: size,
  );
}

Future<void> goToContentMediaEditScreen(
  BuildContext context, {
  required String projectId,
  required String dataId,
  required String? mediaId,
}) async {
  await context.push<void>(
    ContentMediaEditScreen.location(projectId, dataId, mediaId: mediaId),
  );
}
