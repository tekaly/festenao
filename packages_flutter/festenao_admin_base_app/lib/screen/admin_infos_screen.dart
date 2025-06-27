import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

import 'admin_info_edit_screen.dart';
import 'admin_info_screen.dart';

class AdminInfosScreenParam {
  final String? infoType; // location,...
  /// For selecting only
  final bool selectMode;

  AdminInfosScreenParam({this.infoType, this.selectMode = false});
}

class AdminInfosScreenBlocState {
  final List<DbInfo> list;

  AdminInfosScreenBlocState(this.list);
}

class AdminInfoScreenResult {
  final DbInfo? info;
  AdminInfoScreenResult({this.info});
}

class AdminInfosScreenBloc
    extends AutoDisposeStateBaseBloc<AdminInfosScreenBlocState> {
  final FestenaoAdminAppProjectContext projectContext;
  late final _dbBloc = audiAddDisposable(
    AdminAppProjectContextDbBloc(projectContext: projectContext),
  );
  late StreamSubscription _infoSubscription;

  AdminInfosScreenBloc({required this.projectContext}) {
    () async {
      var db = await _dbBloc.grabDatabase();
      _infoSubscription = dbInfoStoreRef.query().onRecords(db).listen((
        records,
      ) {
        add(AdminInfosScreenBlocState(records));
      });
    }();
  }

  @override
  void dispose() {
    _infoSubscription.cancel();
    super.dispose();
  }
}

class AdminInfosScreen extends StatefulWidget {
  final AdminInfosScreenParam? param;

  const AdminInfosScreen({super.key, this.param});
  @override
  State<AdminInfosScreen> createState() => _AdminInfosScreenState();
}

class _AdminInfosScreenState extends State<AdminInfosScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminInfosScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('Infos')),
      body: ValueStreamBuilder<AdminInfosScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var list = snapshot.data?.list;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              var info = list[index];
              return ListTile(
                title: Text(info.nameOrId),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.type.v ?? ''),
                    Text(info.subtitle.v ?? ''),
                  ],
                ),
                onTap: () {
                  if (widget.param?.selectMode ?? false) {
                    Navigator.of(
                      context,
                    ).pop(AdminInfoScreenResult(info: info));
                  } else {
                    goToAdminInfoScreen(
                      context,
                      infoId: info.id,
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
          goToAdminInfoEditScreen(
            context,
            infoId: null,
            projectContext: bloc.projectContext,
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> goToAdminInfosScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  if (festenaoUseContentPathNavigation) {
    await popAndGoToProjectSubScreen(
      context,
      projectContext: projectContext,
      contentPath: ProjectInfosContentPath(),
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () =>
                AdminInfosScreenBloc(projectContext: projectContext),
            child: const AdminInfosScreen(),
          );
        },
      ),
    );
  }
}

Future<AdminInfoScreenResult?> selectInfo(
  BuildContext context, {
  String? infoType,
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () =>
              AdminInfosScreenBloc(projectContext: projectContext),
          child: AdminInfosScreen(
            param: AdminInfosScreenParam(selectMode: true, infoType: infoType),
          ),
        );
      },
    ),
  );
  if (result is AdminInfoScreenResult) {
    return result;
  }
  return null;
}
