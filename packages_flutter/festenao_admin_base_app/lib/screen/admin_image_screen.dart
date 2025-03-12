import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';

import 'package:festenao_common/data/festenao_storage.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:path/path.dart';

import 'admin_image_edit_screen.dart';

class AdminImageScreenResult {}

class AdminImageScreenBlocState {
  final String? imageId;
  final DbImage? image;

  AdminImageScreenBlocState({this.imageId, this.image});
}

class AdminImageScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminImageScreenBlocState> {
  final String? imageId;

  StreamSubscription? _imageSubscription;

  AdminImageScreenBloc({required this.imageId, required super.projectContext}) {
    () async {
      if (imageId != null) {
        var db = await dbBloc.grabDatabase();
        _imageSubscription = dbImageStoreRef
            .record(imageId!)
            .onRecord(db)
            .listen((image) {
              add(AdminImageScreenBlocState(imageId: imageId, image: image));
            });
      } else {
        add(AdminImageScreenBlocState());
      }
    }();
  }

  @override
  void dispose() {
    _imageSubscription?.cancel();

    super.dispose();
  }
}

class AdminImageScreen extends StatefulWidget {
  const AdminImageScreen({super.key});

  @override
  State<AdminImageScreen> createState() => _AdminImageScreenState();
}

class _AdminImageScreenState extends State<AdminImageScreen>
    with AdminScreenMixin {
  AdminImageScreenBloc get bloc =>
      BlocProvider.of<AdminImageScreenBloc>(this.context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('Image')),
      body: GestureDetector(
        onTap: () async {
          if (bloc.state.valueOrNull?.imageId != null) {
            snack(context, 'TODO');
            /*
            await goToAdminImageEditScreen(context,
                imageId: bloc.state.valueOrNull?.imageId);

             */
          }
        },
        child: ValueStreamBuilder<AdminImageScreenBlocState>(
          stream: bloc.state,
          builder: (context, snapshot) {
            var state = snapshot.data;
            if (state == null) {
              return const Center(child: CircularProgressIndicator());
            }
            var image = state.image;
            var imageUrl =
                image == null
                    ? null
                    : getUnauthenticatedStorageApi(
                      storageBucket: bloc.projectContext.storageBucket,
                    ).getMediaUrl(
                      url.join(
                        globalFestenaoAppFirebaseContext.storageRootPath,
                        'image',
                        image.name.v!,
                      ),
                    );
            // print('imageUrl: $imageUrl');
            return ListView(
              children: [
                if (image == null)
                  const ListTile(title: Text('Not found'))
                else ...[
                  InfoTile(label: textIdLabel, value: image.id),
                  InfoTile(label: textNameLabel, value: image.name.v ?? '?'),
                  InfoTile(
                    label: textCopyrightLabel,
                    value: image.copyright.v ?? '?',
                  ),
                  InfoTile(
                    label: textSizeLabel,
                    value: '${image.width.v}x${image.height.v}',
                  ),
                  InfoTile(label: 'Blurhash', value: image.blurHash.v ?? '?'),
                  if (image.blurHash.v != null)
                    SizedBox(
                      height: 128,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: image.aspectRatio,
                          child: BlurHash(hash: image.blurHash.v!),
                        ),
                      ),
                    ),
                  if (imageUrl != null)
                    SizedBox(
                      height: 340,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: image.aspectRatio,
                          child: Image.network(imageUrl),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: ValueStreamBuilder<AdminImageScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var imageId = snapshot.data?.image?.id;
          if (imageId == null) {
            return Container();
          }
          return FloatingActionButton(
            onPressed: () async {
              await goToAdminImageEditScreen(
                context,
                imageId: imageId,
                param: null,
                projectContext: bloc.projectContext,
              );
            },
            child: const Icon(Icons.edit),
          );
        },
      ),
    );
  }
}

Future<void> goToAdminImageScreen(
  BuildContext context, {
  required String? imageId,
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  if (festenaoUseContentPathNavigation) {
    await ContentNavigator.of(context).pushPath<void>(
      ProjectImageContentPath()
        ..project.value = projectContext.projectId
        ..sub.value = imageId,
    );
  } else {
    await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder:
                () => AdminImageScreenBloc(
                  imageId: imageId,
                  projectContext: projectContext,
                ),
            child: const AdminImageScreen(),
          );
        },
      ),
    );
  }
}
