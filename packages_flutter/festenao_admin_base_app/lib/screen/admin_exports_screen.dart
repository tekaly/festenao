import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';

import 'admin_export_edit_screen.dart';
import 'admin_export_view_screen.dart';
import 'admin_exports_screen_bloc.dart';

class AdminExportsScreen extends StatefulWidget {
  const AdminExportsScreen({super.key});

  @override
  State<AdminExportsScreen> createState() => _AdminExportsScreenState();
}

class _AdminExportsScreenState extends State<AdminExportsScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminExportsScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('Exports V2')),
      body: ValueStreamBuilder<AdminExportsScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var list = snapshot.data?.list;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              var export = list[index];
              return ListTile(
                title: Text(export.changeId.v?.toString() ?? '?'),
                subtitle: Text(export.timestamp.v?.toIso8601String() ?? '?'),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (snapshot.data?.metaDev?.lastChangeId.v ==
                            export.changeId.v &&
                        snapshot.data?.metaDev?.sourceVersion.v ==
                            export.version.v)
                      const Text('DEV'),
                    if (snapshot.data?.metaProd?.lastChangeId.v ==
                            export.changeId.v &&
                        snapshot.data?.metaProd?.sourceVersion.v ==
                            export.version.v)
                      const Text('PROD'),
                  ],
                ),
                onTap: () async {
                  await goToAdminExportViewScreen(
                    context,
                    projectContext: bloc.projectContext,
                    exportId: export.id,
                  );

                  await bloc.refresh();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var bloc = BlocProvider.of<AdminExportsScreenBloc>(context);
          await goToAdminExportEditScreen(
            context,
            projectContext: bloc.projectContext,
            exportId: null,
          );
          await bloc.refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> goToAdminExportsScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
  TransitionDelegate? transitionDelegate,
}) async {
  if (festenaoUseContentPathNavigation) {
    await popAndGoToProjectSubScreen(
      context,
      projectContext: projectContext,
      contentPath: ProjectExportsContentPath(),
      transitionDelegate: transitionDelegate,
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () =>
                AdminExportsScreenBloc(projectContext: projectContext),
            child: const AdminExportsScreen(),
          );
        },
      ),
    );
  }
}
