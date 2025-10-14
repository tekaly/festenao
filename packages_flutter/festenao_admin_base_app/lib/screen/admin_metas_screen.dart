import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_meta_general_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/entry_tile.dart';
import 'package:festenao_common/text/text.dart';

import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

import 'project_root_screen.dart';

class AdminMetaScreenBlocState {
  AdminMetaScreenBlocState();
}

class AdminMetasScreenBloc
    extends AutoDisposeStateBaseBloc<AdminMetaScreenBlocState> {
  final FestenaoAdminAppProjectContext projectContext;
  AdminMetasScreenBloc({required this.projectContext});
}

class AdminMetasScreen extends StatefulWidget {
  const AdminMetasScreen({super.key});

  @override
  State<AdminMetasScreen> createState() => _AdminMetasScreenState();
}

class _AdminMetasScreenState extends State<AdminMetasScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminMetasScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('Metas')),
      body: ValueStreamBuilder<AdminMetaScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          return ListView(
            children: [
              EntryTile(
                label: textMetaGeneral,
                onTap: () {
                  goToAdminMetaGeneralEditScreen(
                    context,
                    projectContext: bloc.projectContext,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> goToAdminMetasScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
  TransitionDelegate? transitionDelegate,
}) async {
  if (festenaoUseContentPathNavigation) {
    await popAndGoToProjectSubScreen(
      context,
      projectContext: projectContext,
      contentPath: ProjectMetasContentPath(),
      transitionDelegate: transitionDelegate,
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          blocBuilder: () =>
              AdminMetasScreenBloc(projectContext: projectContext),
          child: const AdminMetasScreen(),
        ),
      ),
    );
  }
}
