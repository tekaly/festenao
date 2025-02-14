import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/action_tile.dart';
import 'package:festenao_admin_base_app/view/attributes_tile.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_admin_base_app/view/menu.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/text/text.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_admin_app/view/body_container.dart';

import 'admin_article_screen_mixin.dart';
import 'admin_info_edit_screen.dart';

class AdminInfoScreenBlocState {
  final String? infoId;
  final DbInfo? info;

  AdminInfoScreenBlocState({this.infoId, this.info});
}

class AdminInfoScreenBloc
    extends AutoDisposeStateBaseBloc<AdminInfoScreenBlocState> {
  final FestenaoAdminAppProjectContext projectContext;
  final String? infoId;
  late final dbBloc = audiAddDisposable(
      AdminAppProjectContextDbBloc(projectContext: projectContext));
  AdminInfoScreenBloc({required this.infoId, required this.projectContext}) {
    () async {
      audiAddStreamSubscription(dbInfoStoreRef
          .record(infoId!)
          .onRecord(await dbBloc.grabDatabase())
          .listen((info) {
        add(AdminInfoScreenBlocState(infoId: infoId, info: info));
      }));
    }();
  }
}

class AdminInfoScreen extends StatefulWidget {
  const AdminInfoScreen({super.key});

  @override
  State<AdminInfoScreen> createState() => _AdminInfoScreenState();
}

class _AdminInfoScreenState extends State<AdminInfoScreen>
    with AdminArticleScreenMixin {
  AdminInfoScreenBloc get bloc => BlocProvider.of<AdminInfoScreenBloc>(context);
  @override
  AdminAppProjectContextDbBloc get dbBloc => bloc.dbBloc;
  @override
  FestenaoAdminAppProjectContext get projectContext => bloc.projectContext;
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;

    return ValueStreamBuilder<AdminInfoScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          return AdminScreenLayout(
            appBar: AppBar(
              title: Text(state?.info?.name.v ?? ''),
              actions: [
                [
                  MenuItem(
                      title: 'Duplicate',
                      onPressed: () {
                        // devPrint('Duplicate go to edit');
                        goToAdminInfoEditScreen(context,
                            infoId: null,
                            info: dbInfo,
                            projectContext: bloc.projectContext);
                      }),
                  MenuItem(
                      title: 'Edit',
                      onPressed: () {
                        goToAdminInfoEditScreen(context,
                            infoId: dbInfo?.idOrNull,
                            info: dbInfo,
                            projectContext: bloc.projectContext);
                      }),
                  SubMenuItem(
                      title: 'Images',
                      items: imagesMenuItems(
                          dbArticle: dbInfo, articleId: dbInfo?.id)),
                ].popupMenu(context),
                PopupMenuButton<MenuItem>(
                    onSelected: (item) {
                      // print('item: $item');
                      item.onPressed?.call();
                    },
                    itemBuilder: (_) => [
                          ...[
                            MenuItem(
                                title: 'Duplicate -legacy-',
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  goToAdminInfoEditScreen(context,
                                      infoId: null,
                                      info: dbInfo,
                                      projectContext: bloc.projectContext);
                                }),
                            MenuItem(title: 'Edit', onPressed: () {}),
                          ].map((e) => PopupMenuItem<MenuItem>(
                                onTap: e.onPressed,
                                child: Text(e.title),
                              )),
                          PopupSubMenuItem<MenuItem>(
                            title: 'Images',
                            items: [
                              ...imagesMenuItems(
                                  dbArticle: dbInfo, articleId: dbInfo?.id),
                            ],
                            onSelected: (sub) {
                              // print('legacy sub: $sub');
                              sub.onPressed?.call();
                            },
                          )
                        ]),
                if (state?.info != null) imagesPopupMenu(),
                if (bloc.infoId != null)
                  TextButton(
                      //style: style,
                      onPressed: () {
                        goToAdminInfoEditScreen(context,
                            infoId: null,
                            info: dbInfo,
                            projectContext: bloc.projectContext);
                      },
                      child: const Text('Dupliquer info')),
                if (state?.info != null) imagesPopupMenu()
              ],
            ),
            body: GestureDetector(
              onTap: () async {
                if (bloc.state.valueOrNull?.infoId != null) {
                  await goToAdminInfoEditScreen(context,
                      infoId: bloc.state.valueOrNull?.infoId,
                      projectContext: bloc.projectContext);
                }
              },
              child: ValueStreamBuilder<AdminInfoScreenBlocState>(
                stream: bloc.state,
                builder: (context, snapshot) {
                  var state = snapshot.data;
                  if (state == null) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  var info = state.info;
                  var article = info;
                  dbInfo ??= info;
                  return ListView(children: [
                    if (info == null)
                      const ListTile(
                        title: Text('Not found'),
                      )
                    else ...[
                      InfoTile(
                        label: textIdLabel,
                        value: info.id,
                      ),
                      getCommonTiles(article),
                      InfoTile(
                        label: textNameLabel,
                        value: info.name.v ?? '?',
                      ),
                      InfoTile(
                        label: textSubtitleLabel,
                        value: info.subtitle.v ?? '?',
                      ),
                      InfoTile(
                        label: textContentLabel,
                        value: info.content.v ?? '?',
                      ),
                      getMarkdownContentTile(article),
                      AttributesTile(
                        options: AttributesTileOptions(
                            attributes: ValueNotifier<List<CvAttribute>?>(
                                article!.attributes.v),
                            readOnly: true),
                        projectContext: bloc.projectContext,
                      ),
                      getThumbailPreviewTile(article),
                      getImagePreviewTile(article),
                      BodyContainer(
                          child: Column(
                        children: [
                          const Divider(),
                          ActionTile(
                              label: 'Dupliquer info',
                              onTap: () {
                                goToAdminInfoEditScreen(context,
                                    infoId: null,
                                    info: dbInfo,
                                    projectContext: bloc.projectContext);
                              }),
                        ],
                      )),
                    ]
                  ]);
                },
              ),
            ),
            floatingActionButton: ValueStreamBuilder<AdminInfoScreenBlocState>(
                stream: bloc.state,
                builder: (context, snapshot) {
                  var infoId = snapshot.data?.info?.id;
                  if (infoId == null) {
                    return Container();
                  }
                  return FloatingActionButton(
                    onPressed: () async {
                      var result = await goToAdminInfoEditScreen(context,
                          infoId: infoId, projectContext: bloc.projectContext);
                      if (result?.deleted ?? false) {
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: const Icon(Icons.edit),
                  );
                }),
          );
        });
  }

  @override
  String get articleKind => articleKindInfo;

  @override
  DbArticle? get dbArticle => dbInfo;

  DbInfo? dbInfo;
}

Future<void> goToAdminInfoScreen(BuildContext context,
    {required String? infoId,
    required FestenaoAdminAppProjectContext projectContext}) async {
  if (festenaoUseContentPathNavigation) {
    await ContentNavigator.of(context).pushPath<void>(ProjectInfoContentPath()
      ..project.value = projectContext.projectId
      ..sub.value = infoId);
  } else {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (context) {
      return BlocProvider(
          blocBuilder: () => AdminInfoScreenBloc(
              infoId: infoId, projectContext: projectContext),
          child: const AdminInfoScreen());
    }));
  }
}
