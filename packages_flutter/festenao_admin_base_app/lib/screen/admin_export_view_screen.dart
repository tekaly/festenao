import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_export_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/text/text.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_admin_app/view/body_container.dart';

import 'admin_export_edit_screen.dart';

class AdminExportViewScreenBlocState {
  String? get exportId => fsExport?.idOrNull;
  final FsExport? fsExport;

  AdminExportViewScreenBlocState({this.fsExport});
}

class AdminExportViewScreenBloc
    extends AutoDisposeStateBaseBloc<AdminExportViewScreenBlocState>
    with AdminExportBlocMixin {
  @override
  final FestenaoAdminAppProjectContext projectContext;
  final String exportId;

  // ignore: cancel_subscriptions
  StreamSubscription? _exportSubscription;
  var firestore = globalFestenaoAdminAppFirebaseContext.firestore;

  AdminExportViewScreenBloc({
    required this.exportId,
    required this.projectContext,
  }) {
    refresh();
  }

  Future<void> refresh() async {
    if (!firestore.service.supportsTrackChanges) {
      audiDispose(_exportSubscription);
      _exportSubscription = null;
    }
    _exportSubscription ??= audiAddStreamSubscription(
      firestore
          .collection(firestoreExportCollectionPath)
          .doc(exportId)
          .onSnapshotSupport()
          .listen((snapshot) {
            add(
              AdminExportViewScreenBlocState(fsExport: snapshot.cv<FsExport>()),
            );
          }),
    );
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
          appBar: AppBar(title: const Text('Export V2')),
          body: ValueStreamBuilder<AdminExportViewScreenBlocState>(
            stream: bloc.state,
            builder: (context, snapshot) {
              var state = snapshot.data;
              if (!canView) {
                return const Center(child: CircularProgressIndicator());
              }

              var export = state!.fsExport;
              var exportId = state.exportId;
              return ListView(
                children: [
                  BodyContainer(
                    child: Column(
                      children: [
                        if (export == null)
                          const InfoTile(value: 'Not found')
                        else ...[
                          InfoTile(label: textIdLabel, value: exportId ?? ''),
                          InfoTile(
                            label: textVersion,
                            value: export.version.v?.toString() ?? '',
                          ),
                          InfoTile(
                            label: textChangeId,
                            value: export.changeId.v?.toString() ?? '',
                          ),
                          InfoTile(
                            label: textTimestamp,
                            value: export.timestamp.v?.toIso8601String() ?? '',
                          ),
                          InfoTile(
                            label: textSize,
                            value: export.size.v?.toString() ?? '',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
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
      },
    );
  }

  Future<void> _onEdit(BuildContext context, String exportId) async {
    var bloc = BlocProvider.of<AdminExportViewScreenBloc>(context);
    await goToAdminExportEditScreen(
      context,
      projectContext: bloc.projectContext,
      exportId: exportId,
    );
    if (context.mounted) {
      await bloc.refresh();
    }
  }
}

Future<void> goToAdminExportViewScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
  required String exportId,
}) async {
  if (festenaoUseContentPathNavigation) {
    await ContentNavigator.of(context).pushPath<void>(
      ProjectExportContentPath()
        ..project.value = projectContext.projectId
        ..sub.value = exportId,
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () => AdminExportViewScreenBloc(
              projectContext: projectContext,
              exportId: exportId,
            ),
            child: const AdminExportViewScreen(),
          );
        },
      ),
    );
  }
}
