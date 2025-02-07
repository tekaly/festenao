import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/text/text.dart';
import 'package:path/path.dart';
import 'package:tkcms_admin_app/view/body_container.dart';

import 'admin_export_edit_screen.dart';

class AdminExportViewScreenBlocState {
  String? get exportId => fsExport?.idOrNull;
  final FsExport? fsExport;

  AdminExportViewScreenBlocState({this.fsExport});
}

class AdminExportViewScreenBloc extends BaseBloc {
  final FestenaoAdminAppProjectContext projectContext;
  final String exportId;
  final _state = BehaviorSubject<AdminExportViewScreenBlocState>();
  StreamSubscription? _exportSubscription;
  var firestore = globalFestenaoAdminAppFirebaseContext.firestore;

  ValueStream<AdminExportViewScreenBlocState> get state => _state;

  AdminExportViewScreenBloc(
      {required this.exportId, required this.projectContext}) {
    refresh();
  }

  Future<void> refresh() async {
    var path = url.join(globalFestenaoAppFirebaseContext.firestoreRootPath,
        getExportPath(exportId));
    if (!firestore.service.supportsTrackChanges) {
      _exportSubscription = null;
    }
    _exportSubscription ??=
        firestore.doc(path).onSnapshotSupport().listen((snapshot) {
      _state.add(
          AdminExportViewScreenBlocState(fsExport: snapshot.cv<FsExport>()));
    });
  }

  @override
  void dispose() {
    _exportSubscription?.cancel();
    _state.close();
    super.dispose();
  }
}

class AdminExportViewScreen extends StatefulWidget {
  const AdminExportViewScreen({super.key});

  @override
  State<AdminExportViewScreen> createState() => _AdminExportViewScreenState();
}

class _AdminExportViewScreenState extends State<AdminExportViewScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminExportViewScreenBloc>(context);
    return ValueStreamBuilder<AdminExportViewScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;

          var export = state?.fsExport;

          var canView = state != null;
          return AdminScreenLayout(
            appBar: AppBar(
              title: const Text('Export V2'),
            ),
            body: ValueStreamBuilder<AdminExportViewScreenBlocState>(
              stream: bloc.state,
              builder: (context, snapshot) {
                var state = snapshot.data;
                if (!canView) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                var export = state!.fsExport;
                var exportId = state.exportId;
                return ListView(children: [
                  BodyContainer(
                    child: Column(children: [
                      if (export == null)
                        const InfoTile(
                          value: 'Not found',
                        )
                      else ...[
                        InfoTile(label: textIdLabel, value: exportId ?? ''),
                        InfoTile(
                            label: textVersion,
                            value: export.version.v?.toString() ?? ''),
                        InfoTile(
                            label: textChangeId,
                            value: export.changeId.v?.toString() ?? ''),
                        InfoTile(
                            label: textTimestamp,
                            value: export.timestamp.v?.toIso8601String() ?? ''),
                        InfoTile(
                            label: textSize,
                            value: export.size.v?.toString() ?? ''),
                      ],
                    ]),
                  )
                ]);
              },
            ),
            floatingActionButton: export != null
                ? FloatingActionButton(
                    onPressed: () {
                      _onEdit(context, export.id);
                    },
                    child: const Icon(Icons.edit),
                  )
                : null,
          );
        });
  }

  Future<void> _onEdit(BuildContext context, String exportId) async {
    var bloc = BlocProvider.of<AdminExportViewScreenBloc>(context);
    await goToAdminExportEditScreen(context,
        projectContext: bloc.projectContext, exportId: exportId);
    if (context.mounted) {
      await bloc.refresh();
    }
  }
}

Future<void> goToAdminExportViewScreen(BuildContext context,
    {required FestenaoAdminAppProjectContext projectContext,
    required String exportId}) async {
  await Navigator.of(context).push<void>(MaterialPageRoute(builder: (context) {
    return BlocProvider(
        blocBuilder: () => AdminExportViewScreenBloc(
            projectContext: projectContext, exportId: exportId),
        child: const AdminExportViewScreen());
  }));
}
