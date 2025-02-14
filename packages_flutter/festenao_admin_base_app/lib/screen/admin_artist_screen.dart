import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_artist_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_screen_bloc_mixin.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/attributes_tile.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/text/text.dart';

import 'admin_article_screen_mixin.dart';
import 'admin_event_edit_screen.dart';
import 'admin_event_edit_screen_bloc.dart';

class AdminArtistScreenBlocState {
  final String? artistId;
  final DbArtist? dbArtist;

  AdminArtistScreenBlocState({this.artistId, this.dbArtist});
}

class AdminArtistScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminArtistScreenBlocState> {
  final String? artistId;

  AdminArtistScreenBloc(
      {required this.artistId, required super.projectContext}) {
    () async {
      var db = await projectDb;
      audiAddStreamSubscription(
          dbArtistStoreRef.record(artistId!).onRecord(db).listen((artist) {
        add(AdminArtistScreenBlocState(artistId: artistId, dbArtist: artist));
      }));
    }();
  }
}

class AdminArtistScreen extends StatefulWidget {
  const AdminArtistScreen({super.key});

  @override
  State<AdminArtistScreen> createState() => _AdminArtistScreenState();
}

class _AdminArtistScreenState extends State<AdminArtistScreen>
    with AdminArticleScreenMixin {
  DbArtist? dbArtist;
  @override
  DbArticle? get dbArticle => dbArtist;

  AdminArtistScreenBloc get bloc =>
      BlocProvider.of<AdminArtistScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    var style = TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onPrimary);
    return ValueStreamBuilder<AdminArtistScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          var artist = state?.dbArtist;
          dbArtist = artist;
          return AdminScreenLayout(
            appBar: AppBar(
              title: const Text('Artiste'),
              actions: [
                if (bloc.artistId != null)
                  TextButton(
                      style: style,
                      onPressed: () {
                        goToAdminEventEditScreen(context,
                            eventId: null,
                            param: AdminEventEditScreenParam(
                                event: DbEvent()
                                  ..attributes.v = [
                                    CvAttribute()
                                      ..value.v =
                                          attrMakeFromArtistId(bloc.artistId!)
                                  ]),
                            projectContext: projectContext);
                      },
                      child: const Text('Créer event')),
                if (bloc.artistId != null)
                  TextButton(
                      style: style,
                      onPressed: () {
                        goToAdminArtistEditScreen(context,
                            artistId: null,
                            artist: dbArtist,
                            projectContext: projectContext);
                      },
                      child: const Text('Dupliquer artist')),
                if (dbArticle != null) imagesPopupMenu(dbArticle: dbArticle)
              ],
            ),
            body: GestureDetector(
              onTap: () async {
                if (bloc.state.valueOrNull?.artistId != null) {
                  var result = await goToAdminArtistEditScreen(context,
                      artistId: bloc.state.valueOrNull?.artistId,
                      projectContext: projectContext);
                  if (result?.deleted ?? false) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                }
              },
              child: ValueStreamBuilder<AdminArtistScreenBlocState>(
                stream: bloc.state,
                builder: (context, snapshot) {
                  if (state == null) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  var artist = state.dbArtist;
                  var article = artist;
                  dbArtist = artist;
                  return ListView(children: [
                    if (artist == null)
                      const ListTile(
                        title: Text('Not found'),
                      )
                    else ...[
                      InfoTile(
                        label: textIdLabel,
                        value: artist.id,
                      ),
                      InfoTile(
                        label: textNameLabel,
                        value: artist.name.v ?? '?',
                      ),
                      getCommonTiles(artist),
                      InfoTile(
                        label: textSubtitleLabel,
                        value: artist.subtitle.v ?? '?',
                      ),
                      InfoTile(
                        label: textContentLabel,
                        value: artist.content.v ?? '?',
                      ),
                      InfoTile(
                        label: textContentSort,
                        value: artist.sort.v ?? '?',
                      ),
                      getMarkdownContentTile(article),
                      AttributesTile(
                        options: AttributesTileOptions(
                            attributes: ValueNotifier<List<CvAttribute>?>(
                                article!.attributes.v),
                            readOnly: true),
                        projectContext: projectContext,
                      ),
                      getThumbailPreviewTile(article),
                      getImagePreviewTile(article),
                      getImagesPreview(articleId: article.id),
                    ]
                  ]);
                },
              ),
            ),
            floatingActionButton:
                ValueStreamBuilder<AdminArtistScreenBlocState>(
                    stream: bloc.state,
                    builder: (context, snapshot) {
                      var artistId = snapshot.data?.dbArtist?.id;
                      if (artistId == null) {
                        return Container();
                      }
                      return FloatingActionButton(
                        onPressed: () async {
                          await goToAdminArtistEditScreen(context,
                              artistId: artistId,
                              projectContext: projectContext);
                        },
                        child: const Icon(Icons.edit),
                      );
                    }),
          );
        });
  }

  @override
  String get articleKind => articleKindArtist;

  @override
  // TODO: implement dbBloc
  AdminAppProjectContextDbBloc get dbBloc => bloc.dbBloc;

  @override
  // TODO: implement projectContext
  FestenaoAdminAppProjectContext get projectContext => dbBloc.projectContext;
}

Future<void> goToAdminArtistScreen(BuildContext context,
    {required String? artistId,
    required FestenaoAdminAppProjectContext projectContext}) async {
  if (festenaoUseContentPathNavigation) {
    await ContentNavigator.of(context).pushPath<void>(ProjectArtistContentPath()
      ..project.value = projectContext.projectId
      ..sub.value = artistId);
  } else {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (context) {
      return BlocProvider(
          blocBuilder: () => AdminArtistScreenBloc(
              artistId: artistId, projectContext: projectContext),
          child: const AdminArtistScreen());
    }));
  }
}
