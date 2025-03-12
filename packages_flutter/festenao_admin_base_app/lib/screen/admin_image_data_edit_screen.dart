import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import 'package:tekartik_app_flutter_bloc/bloc_provider.dart';
import 'package:tekartik_app_rx_bloc/state_base_bloc.dart';
import 'package:tekartik_app_rx_utils/app_rx_utils.dart';

class AdminImageDataEditScreenParam {
  final Uint8List bytes;
  final double? aspectRatio;

  AdminImageDataEditScreenParam({
    required this.bytes,
    this.aspectRatio = CropAspectRatios.custom,
  });
}

/// Crop result
class AdminImageDataEditScreenResult {
  final Rect? cropRect;

  AdminImageDataEditScreenResult({this.cropRect});
}

class AdminImageDataEditScreenBlocState {}

class AdminImageDataEditScreenBloc
    extends StateBaseBloc<AdminImageDataEditScreenBlocState> {
  final AdminImageDataEditScreenParam param;

  AdminImageDataEditScreenBloc({required this.param});
}

class AdminImageDataEditScreen extends StatefulWidget {
  const AdminImageDataEditScreen({super.key});

  @override
  State<AdminImageDataEditScreen> createState() =>
      _AdminImageDataEditScreenState();
}

class _AdminImageDataEditScreenState extends State<AdminImageDataEditScreen> {
  final editorKey = GlobalKey<ExtendedImageEditorState>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminImageDataEditScreenBloc>(context);
    return ValueStreamBuilder<AdminImageDataEditScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Image'),
            actions: [
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: () {
                  editorKey.currentState!.reset();
                },
              ),
            ],
          ),
          body: Builder(
            builder: (context) {
              return ExtendedImage.memory(
                bloc.param.bytes,
                fit: BoxFit.contain,
                mode: ExtendedImageMode.editor,
                extendedImageEditorKey: editorKey,
                initEditorConfigHandler: (state) {
                  return EditorConfig(
                    maxScale: 8.0,
                    cropRectPadding: const EdgeInsets.all(20.0),
                    hitTestSize: 20.0,
                    cropAspectRatio: bloc.param.aspectRatio,
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _onSave,
            child: const Icon(Icons.save),
          ),
        );
      },
    );
  }

  Future<void> _onSave() async {
    var result = AdminImageDataEditScreenResult(
      cropRect: editorKey.currentState!.getCropRect(),
    );
    Navigator.pop(context, result);
  }
}

Future<AdminImageDataEditScreenResult?> goToAdminImageDataEditScreen(
  BuildContext context, {
  required AdminImageDataEditScreenParam param,
}) async {
  return await Navigator.of(context).push<AdminImageDataEditScreenResult>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () => AdminImageDataEditScreenBloc(param: param),
          child: const AdminImageDataEditScreen(),
        );
      },
    ),
  );
}
