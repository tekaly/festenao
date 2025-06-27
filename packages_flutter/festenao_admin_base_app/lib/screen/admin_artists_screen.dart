import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_screen_bloc_mixin.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/admin_article_thumbnail.dart';
import 'package:festenao_common/data/festenao_db.dart';

import 'admin_artist_edit_screen.dart';
import 'admin_artist_screen.dart';
import 'project_root_screen.dart';

class AdminArtistsScreenParam {
  /// For selecting only
  final bool selectMode;

  AdminArtistsScreenParam({this.selectMode = false});
}

class AdminArtistScreenResult {
  final DbArtist? artist;

  AdminArtistScreenResult({this.artist});
}

class AdminArtistsScreenBlocState {
  final List<DbArtist> list;

  AdminArtistsScreenBlocState(this.list);
}

class AdminArtistsScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminArtistsScreenBlocState> {
  var _showHidden = false;

  bool get showHidden => _showHidden;

  set showHidden(bool on) {
    _showHidden = on;
    _refresh();
  }

  Future<void> _refresh() async {
    var db = await projectDb;
    audiAddStreamSubscription(
      dbArtistStoreRef.query().onRecords(db).listen((records) {
        add(
          AdminArtistsScreenBlocState(
            records.where((element) => _showHidden || !element.hidden).toList(),
          ),
        );
      }),
    );
  }

  AdminArtistsScreenBloc({required super.projectContext}) {
    _refresh();
  }
}

class AdminArtistsScreen extends StatefulWidget {
  final AdminArtistsScreenParam? param;

  const AdminArtistsScreen({super.key, this.param});

  @override
  State<AdminArtistsScreen> createState() => _AdminArtistsScreenState();
}

class _AdminArtistsScreenState extends State<AdminArtistsScreen>
    with AdminScreenMixin {
  AdminArtistsScreenBloc get bloc =>
      BlocProvider.of<AdminArtistsScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;

    return AdminScreenLayout(
      appBar: AppBar(
        title: const Text('Artistes'),
        actions: [
          PopupMenuButton(
            //offset: Offset(100, 100),
            elevation: 5.0,
            // child: _menuIcon,
            itemBuilder: (context) => [
              PopupMenuItem<bool>(
                child: StatefulBuilder(
                  builder: (builderContext, doSetState) => SwitchListTile(
                    //activeColor: kLeadingOrangeColor,
                    value: bloc.showHidden, // isShow,
                    onChanged: (value) => doSetState(() {
                      bloc.showHidden = value;
                    }),
                    title: const Text('Show hidden'),
                  ),
                ),
              ),
            ],
          ),
          /*SwitchListTile(value: true, onChanged: (_) {
          print('onChanged');
        }
        )*/
        ],
      ),
      body: ValueStreamBuilder<AdminArtistsScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var list = snapshot.data?.list;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              var artist = list[index];
              return ListTile(
                leading: AdminArticleThumbnail(
                  article: artist,
                  dbBloc: bloc.dbBloc,
                ),
                title: Text(artist.name.v ?? '?'),
                subtitle: Text(
                  '${artist.id}\n${(artist.subtitle.v?.isNotEmpty ?? false) ? artist.subtitle.v : 'null'}'
                  '\n${artist.tags.v?.join(', ') ?? ''}',
                ),
                //onTap: onTap,
                //  title: Text(artist.name.v ?? '?'),
                onTap: () {
                  if (widget.param?.selectMode ?? false) {
                    Navigator.of(
                      context,
                    ).pop(AdminArtistScreenResult(artist: artist));
                  } else {
                    goToAdminArtistScreen(
                      context,
                      artistId: artist.id,
                      projectContext: bloc.projectContext,
                    );
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          goToAdminArtistEditScreen(
            context,
            artistId: null,
            projectContext: bloc.projectContext,
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> goToAdminArtistsScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  if (festenaoUseContentPathNavigation) {
    await popAndGoToProjectSubScreen(
      context,
      projectContext: projectContext,
      contentPath: ProjectArtistsContentPath(),
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () =>
                AdminArtistsScreenBloc(projectContext: projectContext),
            child: const AdminArtistsScreen(),
          );
        },
      ),
    );
  }
}

Future<AdminArtistScreenResult?> selectArtist(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () =>
              AdminArtistsScreenBloc(projectContext: projectContext),
          child: AdminArtistsScreen(
            param: AdminArtistsScreenParam(selectMode: true),
          ),
        );
      },
    ),
  );
  if (result is AdminArtistScreenResult) {
    return result;
  }
  return null;
}
