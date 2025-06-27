import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/view/attributes_tile.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_admin_base_app/view/menu.dart';
import 'package:festenao_common/text/text.dart';

import 'admin_article_screen_mixin.dart';
import 'admin_event_edit_screen.dart';
import 'admin_event_edit_screen_bloc.dart';

import 'screen_bloc_import.dart';
import 'screen_import.dart';

class AdminEventScreenBlocState {
  final String? eventId;
  final DbEvent? event;

  AdminEventScreenBlocState({this.eventId, this.event});
}

class AdminEventScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminEventScreenBlocState> {
  final String? eventId;

  AdminEventScreenBloc({required this.eventId, required super.projectContext}) {
    () async {
      var db = await projectDb;
      audiAddStreamSubscription(
        dbEventStoreRef.record(eventId!).onRecord(db).listen((event) {
          add(AdminEventScreenBlocState(eventId: eventId, event: event));
        }),
      );
    }();
  }
}

class AdminEventScreen extends StatefulWidget {
  const AdminEventScreen({super.key});

  @override
  State<AdminEventScreen> createState() => _AdminEventScreenState();
}

class _AdminEventScreenState extends State<AdminEventScreen>
    with AdminArticleScreenMixin, AdminAppProjectScreenStateMixin {
  AdminEventScreenBloc get bloc =>
      BlocProvider.of<AdminEventScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return ValueStreamBuilder<AdminEventScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        return AdminScreenLayout(
          appBar: AppBar(
            title: const Text('Event'),
            actions: [
              [
                MenuItem(
                  title: 'Duplicate',
                  onPressed: () {
                    goToAdminEventEditScreen(
                      context,
                      eventId: null,
                      param: AdminEventEditScreenParam(event: dbEvent),
                      projectContext: projectContext,
                    );
                  },
                ),
                MenuItem(title: 'Edit', onPressed: () {}),
                SubMenuItem(
                  title: 'Images',
                  items: imagesMenuItems(
                    dbArticle: dbEvent,
                    articleId: dbArticle?.id,
                  ),
                ),
              ].popupMenu(context),
              if (bloc.eventId != null)
                ValueStreamBuilder<AdminEventScreenBlocState>(
                  stream: bloc.state,
                  builder: (context, snapshot) {
                    var event = snapshot.data?.event;
                    if (event == null) {
                      return Container();
                    }
                    return IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Duplicate',
                      onPressed: () {
                        goToAdminEventEditScreen(
                          context,
                          eventId: null,
                          param: AdminEventEditScreenParam(event: event),
                          projectContext: projectContext,
                        );
                      },
                    );
                  },
                ),
              if (bloc.eventId != null)
                imagesPopupMenu(articleId: bloc.eventId),
            ],
          ),
          body: GestureDetector(
            onTap: () async {
              if (bloc.state.valueOrNull?.eventId != null) {
                await goToAdminEventEditScreen(
                  context,
                  eventId: bloc.state.valueOrNull?.eventId,
                  projectContext: projectContext,
                );
              }
            },
            child: ValueStreamBuilder<AdminEventScreenBlocState>(
              stream: bloc.state,
              builder: (context, snapshot) {
                var state = snapshot.data;
                if (state == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                var event = state.event;
                dbEvent ??= event;
                var article = event;
                var artistId = event?.getUniqueArtistId();

                return ListView(
                  children: [
                    if (event == null)
                      const ListTile(title: Text('Not found'))
                    else ...[
                      InfoTile(label: textIdLabel, value: event.id),
                      getCommonTiles(event),
                      InfoTile(
                        label: textNameLabel,
                        value: event.name.v ?? '?',
                      ),
                      InfoTile(
                        label: textSubtitleLabel,
                        value: event.subtitle.v ?? '?',
                      ),
                      InfoTile(
                        label: textDayLabel,
                        value:
                            '${event.day.v} ${event.beginTime.v}-${event.endTime.v}',
                      ),
                      InfoTile(
                        label: textContentLabel,
                        value: event.content.v ?? '?',
                      ),
                      getMarkdownContentTile(article),
                      AttributesTile(
                        options: AttributesTileOptions(
                          attributes: ValueNotifier<List<CvAttribute>?>(
                            article!.attributes.v,
                          ),
                          readOnly: true,
                        ),
                        projectContext: projectContext,
                      ),
                      getThumbailPreviewTile(article),
                      getImagePreviewTile(article),
                      getImagesPreview(articleId: article.id),
                      if (artistId != null)
                        getImagesPreview(
                          articleKind: articleKindArtist,
                          articleId: artistId,
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
          floatingActionButton: ValueStreamBuilder<AdminEventScreenBlocState>(
            stream: bloc.state,
            builder: (context, snapshot) {
              var eventId = snapshot.data?.event?.id;
              if (eventId == null) {
                return Container();
              }
              return FloatingActionButton(
                onPressed: () async {
                  var result = await goToAdminEventEditScreen(
                    context,
                    eventId: eventId,
                    projectContext: projectContext,
                  );
                  if (result?.deleted ?? false) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Icon(Icons.edit),
              );
            },
          ),
        );
      },
    );
  }

  @override
  String get articleKind => articleKindEvent;

  @override
  DbArticle? get dbArticle => dbEvent;
  DbEvent? dbEvent;

  @override
  AdminAppProjectContextDbBloc get dbBloc => bloc.dbBloc;
}

Future<void> goToAdminEventScreen(
  BuildContext context, {
  required String? eventId,
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  if (festenaoUseContentPathNavigation) {
    await ContentNavigator.of(context).pushPath<void>(
      ProjectEventContentPath()
        ..project.value = projectContext.projectId
        ..sub.value = eventId,
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () => AdminEventScreenBloc(
              eventId: eventId,
              projectContext: projectContext,
            ),
            child: const AdminEventScreen(),
          );
        },
      ),
    );
  }
}
