import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/linear_wait.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter/foundation.dart';
import 'package:tkcms_admin_app/view/body_container.dart';

import 'admin_article_edit_screen_bloc_mixin.dart';
import 'admin_article_edit_screen_mixin.dart';
import 'admin_artist_edit_screen_bloc.dart';

class AdminArtistEditScreen extends StatefulWidget {
  const AdminArtistEditScreen({super.key});

  @override
  State<AdminArtistEditScreen> createState() => _AdminArtistEditScreenState();
}

class _AdminArtistEditScreenState extends State<AdminArtistEditScreen>
    with AdminArticleEditScreenMixin {
  @override
  void dispose() {
    articleMixinDispose();

    super.dispose();
  }

  AdminArtistEditScreenBloc get bloc =>
      BlocProvider.of<AdminArtistEditScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return ValueStreamBuilder<AdminArtistEditScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;

          var artist = state?.artist;
          var artistId = bloc.artistId;
          var canSave = artistId == null || artist != null;
          var article = artist;
          return AdminScreenLayout(
            appBar: AppBar(
              actions: [
                if (bloc.artistId != null)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Supprimer',
                    onPressed: () {
                      _onDelete(context);
                    },
                  ),
              ],
              title: const Text('Artiste'),
            ),
            body: Builder(
              builder: (context) {
                if (!canSave) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                // devPrint('canSave $canSave $artistId $artist');

                return Stack(
                  children: [
                    ListView(children: [
                      Form(
                        key: formKey,
                        child: BodyContainer(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (artist == null && artistId != null)
                                  const ListTile(
                                    title: Text('Non trouvé'),
                                  )
                                else ...[
                                  ListTile(
                                    title: Text(artist?.id ?? 'new'),
                                  ),
                                ],
                                AppTextFieldTile(
                                  controller: idController ??=
                                      TextEditingController(text: artistId),
                                  labelText: textIdLabel,
                                ),
                                getCommonWidgets(artist),
                                AppTextFieldTile(
                                  controller: nameController ??=
                                      TextEditingController(
                                          text: artist?.name.v),
                                  labelText: textNameLabel,
                                ),
                                AppTextFieldTile(
                                  emptyAllowed: true,
                                  controller: subtitleController ??=
                                      TextEditingController(
                                          text: artist?.subtitle.v),
                                  labelText: textSubtitleLabel,
                                ),
                                AppTextFieldTile(
                                  controller: contentController ??=
                                      TextEditingController(
                                          text: artist?.content.v),
                                  maxLines: 10,
                                  labelText: 'Contenu',
                                ),
                                getBottomCommonWidgets(article),
                                getImagesWidget(article, db: state!.db),
                                getAttributesTile(article),
                                getThumbailNameWidget(article),
                                getThumbnailSelectorTile(article),
                                getThumbnailPreviewTile(article),
                                getImageNameWidget(article),
                                getImageSelectorTile(article),
                                getImagePreviewTile(article),
                                const SizedBox(
                                  height: 64,
                                ),
                              ]),
                        ),
                      )
                    ]),
                    LinearWait(
                      showNotifier: saving,
                    ),
                  ],
                );
              },
            ),
            floatingActionButton: canSave
                ? FloatingActionButton(
                    onPressed: () => _onSave(context),
                    child: const Icon(Icons.save),
                  )
                : null,
          );
        });
  }

  final _saveLock = Lock();

  Future<void> _onSave(BuildContext context) async {
    if (formKey.currentState!.validate() && !_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          var bloc = BlocProvider.of<AdminArtistEditScreenBloc>(context);
          formKey.currentState!.save();
          var dbArtist = dbArtistStoreRef.record(idController!.text).cv();
          articleFromForm(dbArtist);

          await bloc.save(AdminArticleEditData(
              article: dbArtist,
              imageData: newImageData,
              thumbailData: newThumbnailImageData));
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        } catch (e, st) {
          // ignore: avoid_print
          print(e);
          // ignore: avoid_print
          print(st);
        } finally {
          saving.value = false;
        }
      });
    }
  }

  Future<void> _onDelete(BuildContext context) async {
    if (!_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          var bloc = BlocProvider.of<AdminArtistEditScreenBloc>(context);
          await bloc.delete();
          if (context.mounted) {
            Navigator.of(context)
                .pop(AdminArtistEditScreenResult(deleted: true));
          }
        } catch (e, st) {
          if (kDebugMode) {
            print(e);
            print(st);
          }
        } finally {
          saving.value = false;
        }
      });
    }
  }

  @override
  AdminArticleEditScreenInfo get info =>
      AdminArticleEditScreenInfo(articleKind: articleKindArtist);

  @override
  AdminAppProjectContextDbBloc get dbBloc => bloc.dbBloc;

  @override
  // TODO: implement projectContext
  FestenaoAdminAppProjectContext get projectContext => dbBloc.projectContext;
}

Future<AdminArtistEditScreenResult?> goToAdminArtistEditScreen(
    BuildContext context,
    {required FestenaoAdminAppProjectContext projectContext,
    required String? artistId,

    /// Only for artistId = null
    DbArtist? artist}) async {
  return await Navigator.of(context)
      .push<AdminArtistEditScreenResult?>(MaterialPageRoute(builder: (context) {
    return BlocProvider(
        blocBuilder: () => AdminArtistEditScreenBloc(
            artistId: artistId, artist: artist, projectContext: projectContext),
        child: const AdminArtistEditScreen());
  }));
}
