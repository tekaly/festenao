import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:festenao_admin_base_app/file_picker/file_picker.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_blog_demo_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_router.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ContentImageEditScreen extends StatefulHookConsumerWidget {
  static const editRouteName = 'content_image_edit';
  static const createRouteName = 'content_image_create';
  static const editRouteLocationPart = 'edit';
  static const createRouteLocationPart = 'image_create';
  static const editRouteLocation =
      '/project/:${DashboardRouter.projectIdParam}'
      '/data/:${DashboardRouter.dataIdParam}'
      '/image/:${DashboardRouter.imageIdParam}'
      'edit';
  static const createRouteLocation =
      '/project/:${DashboardRouter.projectIdParam}'
      '/data/:${DashboardRouter.dataIdParam}'
      'image_create';

  static String location(String projectId, String dataId, {String? imageId}) {
    var baseLoc = '/project/$projectId/data/$dataId';
    var loc = imageId == null
        ? '$baseLoc/image_create'
        : '$baseLoc/image/$imageId/edit';
    return loc;
  }

  final String projectId;
  final String dataId;

  /// null means creating a new image
  final String? imageId;

  const ContentImageEditScreen({
    super.key,
    required this.projectId,
    required this.dataId,
    this.imageId,
  });

  @override
  ConsumerState<ContentImageEditScreen> createState() =>
      _ContentImageEditScreenState();
}

class _ContentImageEditScreenState
    extends ConsumerState<ContentImageEditScreen> {
  final _nameCtrl = TextEditingController();
  final _copyrightCtrl = TextEditingController();
  final imageIdCtrl = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  var _formInitialized = false;

  Uint8List? _pickedBytes;
  String? _pickedFilename;
  int? _pickedWidth;
  int? _pickedHeight;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _copyrightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.imageId == null;

    final imageAsync = isNew
        ? const AsyncData<SdfImage?>(null)
        : ref.watch(
            imageEntryProvider(
              widget.projectId,
              widget.dataId,
              widget.imageId!,
            ),
          );

    final contentSdbAsync = ref.watch(
      contentSdbProvider(widget.projectId, widget.dataId),
    );
    if (!_formInitialized) {
      if (isNew) {
        _formInitialized = true;
      } else {
        if (imageIdCtrl.text.isEmpty && !isNew) {
          imageIdCtrl.text = widget.imageId!;
        }
      }
    }

    // Initialize form fields from existing image on first load
    if (!isNew) {
      ref.listen(
        imageEntryProvider(widget.projectId, widget.dataId, widget.imageId!),
        (_, next) {
          next.whenData((img) {
            if (img != null && !_initialized) {
              _nameCtrl.text = img.name.v ?? '';
              _copyrightCtrl.text = img.copyright.v ?? '';
              imageIdCtrl.text = img.id;
              setState(() {
                _initialized = true;
              });
            }
          });
        },
      );
    } else {
      _initialized = true;
    }

    final currentImage = imageAsync.value;
    final effectiveWidth = _pickedWidth ?? currentImage?.width.v;
    final effectiveHeight = _pickedHeight ?? currentImage?.height.v;

    var isValid = _initialized;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Image' : 'Edit Image'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: isValid && contentSdbAsync.hasValue && !_isSaving
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
              if (!isNew && currentImage == null && imageAsync.hasValue)
                const ListTile(title: Text('Not found')),
              if (isValid) ...[
                TextField(
                  controller: imageIdCtrl,
                  enabled: isNew,
                  decoration: const InputDecoration(labelText: 'Image ID'),
                ),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _copyrightCtrl,
                  decoration: const InputDecoration(labelText: 'Copyright'),
                ),
                const SizedBox(height: 12),
                if (effectiveWidth != null && effectiveHeight != null)
                  ListTile(
                    dense: true,
                    title: const Text('Size'),
                    subtitle: Text('${effectiveWidth}x$effectiveHeight'),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick Image'),
                ),
                const SizedBox(height: 12),
                _buildPreview(contentSdbAsync.value),
                const SizedBox(height: 80),
              ],
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

  Widget _buildPreview(SdfContentSdb? sdb) {
    if (_pickedBytes != null) {
      return _imagePreview(_pickedBytes!);
    }
    if (sdb == null || widget.imageId == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Uint8List?>(
      future: _loadMediaBytes(sdb, widget.imageId!),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return const SizedBox.shrink();
        return _imagePreview(bytes);
      },
    );
  }

  Widget _imagePreview(Uint8List bytes) => SizedBox(
    height: 240,
    child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
  );

  Future<void> _pickImage() async {
    final result = await pickImageFile(context);
    if (result == null) return;
    final file = result.files.firstOrNull;
    if (file == null) return;

    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    final dims = await _decodeImageDimensions(bytes);

    if (mounted) {
      setState(() {
        _pickedBytes = bytes;
        _pickedFilename = file.name;
        _pickedWidth = dims.$1;
        _pickedHeight = dims.$2;
        if (_nameCtrl.text.isEmpty) _nameCtrl.text = file.name;
      });
    }
  }

  Future<void> _onSave(BuildContext context, SdfContentSdb sdb) async {
    if (_isSaving) return;
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      final name = _nameCtrl.text.trim();
      final copyright = _copyrightCtrl.text.trim();
      final imageId = imageIdCtrl.text.trim();
      if (imageId.isEmpty) {
        _showError(context, 'Please enter an image id.');
        return;
      }
      final isNew = widget.imageId == null;

      final currentImage = widget.imageId != null
          ? ref
                .read(
                  imageEntryProvider(
                    widget.projectId,
                    widget.dataId,
                    widget.imageId!,
                  ),
                )
                .value
          : null;

      if (isNew) {
        if (_pickedBytes == null) {
          _showError(context, 'Please pick an image file first.');
          return;
        }
        var existingImage = await sdb.getImage(imageId);
        if (existingImage != null) {
          if (context.mounted) {
            _showError(context, 'Image with id $imageId already exists.');
          }
          return;
        }

        // New image: media file uid becomes the image record ID
        final mediaFile = FestenaoMediaFile.from(
          filename: _pickedFilename!,
          size: _pickedBytes!.length,
        );
        final image = SdfImage()
          ..name.v = name.isNotEmpty ? name : null
          ..copyright.v = copyright.isNotEmpty ? copyright : null
          ..width.v = _pickedWidth
          ..height.v = _pickedHeight;
        var mediaId = await sdb.mediaDb.addMediaFile(
          file: mediaFile,
          bytes: _pickedBytes!,
        );
        image.mediaId.v = mediaId;
        await sdb.putImage(imageId, image);
      } else {
        var mediaId = currentImage?.mediaId.v;
        if (_pickedBytes != null) {
          final mediaFile = FestenaoMediaFile.from(
            filename: _pickedFilename!,
            size: _pickedBytes!.length,
          );
          mediaId = await sdb.mediaDb.addMediaFile(
            file: mediaFile,
            bytes: _pickedBytes!,
          );
        }
        // Update existing metadata
        final image = SdfImage()
          ..name.v = name.isNotEmpty ? name : null
          ..copyright.v = copyright.isNotEmpty ? copyright : null
          ..width.v = _pickedWidth ?? currentImage?.width.v
          ..height.v = _pickedHeight ?? currentImage?.height.v
          ..blurHash.v = currentImage?.blurHash.v
          ..mediaId.v = mediaId;
        await sdb.putImage(widget.imageId!, image);
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
        title: const Text('Delete Image'),
        content: const Text('Delete this image?'),
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
      await sdb.deleteImage(widget.imageId!);
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

Future<Uint8List?> _loadMediaBytes(SdfContentSdb sdb, String imageId) async {
  try {
    return await sdb.mediaDb.readMediaFileBytes(imageId);
  } catch (_) {
    return null;
  }
}

Future<(int, int)> _decodeImageDimensions(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  return (image.width, image.height);
}

Future<void> goToContentImageEditScreen(
  BuildContext context, {
  required String projectId,
  required String dataId,
  required String? imageId,
}) async {
  await context.push<void>(
    ContentImageEditScreen.location(projectId, dataId, imageId: imageId),
  );
}
