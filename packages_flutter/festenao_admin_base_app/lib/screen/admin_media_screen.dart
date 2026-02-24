import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_common/data/festenao_media_db.dart';

import 'package:festenao_common/data/festenao_storage.dart';
import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/text/text.dart';
import 'package:path/path.dart';
import 'package:tkcms_admin_app/utils/web_launch_uri.dart';

import 'admin_media_edit_screen.dart';

class AdminMediaScreenResult {}

class AdminMediaScreenBlocState {
  final String? mediaId;
  final DbFestenaoMediaFile? media;
  final DbFestenaoMediaStatusFile? status;

  AdminMediaScreenBlocState({this.mediaId, this.media, this.status});
}

class AdminMediaScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminMediaScreenBlocState> {
  final String mediaId;

  StreamSubscription? _mediaSubscription;

  AdminMediaScreenBloc({required this.mediaId, required super.projectContext}) {
    () async {
      var db = await dbBloc.grabDatabase();
      _mediaSubscription =
          streamJoin2(
            dbMediaStoreRef.record(mediaId).onRecord(db),
            dbMediaLocalStoreRef.record(mediaId).onRecord(db),
          ).listen((join) {
            var media = join.$1;
            var status = join.$2;
            add(
              AdminMediaScreenBlocState(
                mediaId: mediaId,
                media: media,
                status: status,
              ),
            );
          });
    }();
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();

    super.dispose();
  }
}

class AdminMediaScreen extends StatefulWidget {
  const AdminMediaScreen({super.key});

  @override
  State<AdminMediaScreen> createState() => _AdminMediaScreenState();
}

class _AdminMediaScreenState extends State<AdminMediaScreen>
    with AdminScreenMixin {
  AdminMediaScreenBloc get bloc =>
      BlocProvider.of<AdminMediaScreenBloc>(this.context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('Media')),
      body: GestureDetector(
        onTap: () async {
          if (bloc.state.valueOrNull?.mediaId != null) {
            snack(context, 'TODO');
            /*
            await goToAdminMediaEditScreen(context,
                mediaId: bloc.state.valueOrNull?.mediaId);

             */
          }
        },
        child: ValueStreamBuilder<AdminMediaScreenBlocState>(
          stream: bloc.state,
          builder: (context, snapshot) {
            var state = snapshot.data;
            if (state == null) {
              return const Center(child: CircularProgressIndicator());
            }
            var media = state.media;
            var status = state.status;
            var mediaUrl = media == null
                ? null
                : getUnauthenticatedStorageApi(
                    storageBucket: bloc.projectContext.storageBucket,
                  ).getMediaUrl(
                    url.joinAll([
                      globalFestenaoAppFirebaseContext.storageRootPath,
                      ...FestenaoMediaDb.projectStorageParts(
                        bloc.projectContext.projectId,
                      ),
                      FestenaoMediaDb.mediaPart,
                      media.path.v!,
                    ]),
                  );
            // print('mediaUrl: $mediaUrl');
            return ListView(
              children: [
                if (media == null)
                  const ListTile(title: Text('Not found'))
                else ...[
                  InfoTile(label: textIdLabel, value: media.id),
                  InfoTile(
                    label: textNameLabel,
                    value: media.originalFilename.v ?? '?',
                  ),
                  InfoTile(label: 'Path', value: media.path.v ?? '?'),
                  if (mediaUrl != null)
                    InfoTile(
                      label: 'URL',
                      value: mediaUrl,
                      onTap: () {
                        webLaunchUri(Uri.parse(mediaUrl));
                      },
                    ),
                  InfoTile(
                    label: 'Uploaded',
                    value: media.uploaded.v?.toString() ?? '?',
                  ),
                  InfoTile(
                    label: 'Deleted',
                    value: media.deleted.v?.toString() ?? '?',
                  ),
                  InfoTile(
                    label: 'Local',
                    value: status?.local.v?.toString() ?? '?',
                  ),
                  InfoTile(
                    label: 'Remote',
                    value: status?.remote.v?.toString() ?? '?',
                  ),
                  InfoTile(
                    label: 'Deleted local',
                    value: status?.deletedLocal.v?.toString() ?? '?',
                  ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: ValueStreamBuilder<AdminMediaScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var mediaId = snapshot.data?.media?.id;
          if (mediaId == null) {
            return Container();
          }
          return FloatingActionButton(
            onPressed: () async {
              await goToAdminMediaEditScreen(
                context,
                mediaId: mediaId,
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

Future<void> goToAdminMediaScreen(
  BuildContext context, {
  required String mediaId,
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  if (festenaoUseContentPathNavigation) {
    await ContentNavigator.of(context).pushPath<void>(
      ProjectMediaContentPath()
        ..project.value = projectContext.projectId
        ..sub.value = mediaId,
    );
  } else {
    await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () => AdminMediaScreenBloc(
              mediaId: mediaId,
              projectContext: projectContext,
            ),
            child: const AdminMediaScreen(),
          );
        },
      ),
    );
  }
}
