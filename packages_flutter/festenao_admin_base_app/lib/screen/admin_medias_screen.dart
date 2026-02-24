import 'dart:async';

import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_media_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/festenao_media_db.dart';

import 'package:flutter/material.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

import 'admin_media_screen.dart';
import 'project_root_screen.dart';

class AdminMediaScreenBlocState {
  final List<DbFestenaoMediaFile> list;

  AdminMediaScreenBlocState(this.list);
}

class AdminMediasScreenBloc
    extends AutoDisposeStateBaseBloc<AdminMediaScreenBlocState> {
  late final _dbBloc = audiAddDisposable(
    AdminAppProjectContextDbBloc(projectContext: projectContext),
  );
  final FestenaoAdminAppProjectContext projectContext;
  AdminMediasScreenBloc({required this.projectContext}) {
    () async {
      var db = await _dbBloc.grabDatabase();
      audiAddStreamSubscription(
        dbMediaStoreRef.query().onRecords(db).listen((records) {
          add(AdminMediaScreenBlocState(records));
        }),
      );
    }();
  }
}

class AdminMediasScreen extends StatefulWidget {
  const AdminMediasScreen({super.key});

  @override
  State<AdminMediasScreen> createState() => _AdminMediasScreenState();
}

class _AdminMediasScreenState extends State<AdminMediasScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminMediasScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('Medias')),
      body: ValueStreamBuilder<AdminMediaScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var list = snapshot.data?.list;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              var image = list[index];

              return ListTile(
                title: Text(image.id),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(image.originalFilename.v ?? ''),
                    Text(image.path.v ?? '?'),
                    Text(image.type.v ?? '?'),
                    Text(image.size.v?.toString() ?? '?'),
                  ],
                ),
                onTap: () {
                  goToAdminMediaScreen(
                    context,
                    mediaId: image.id,
                    projectContext: bloc.projectContext,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var result = await goToAdminMediaEditScreen(
            context,

            projectContext: bloc.projectContext,
            mediaId: null,
          );
          if (result != null) {}
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> goToAdminMediasScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
  TransitionDelegate? transitionDelegate,
}) async {
  if (festenaoUseContentPathNavigation) {
    await popAndGoToProjectSubScreen(
      context,
      projectContext: projectContext,
      contentPath: ProjectMediasContentPath(),
      transitionDelegate: transitionDelegate,
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () =>
                AdminMediasScreenBloc(projectContext: projectContext),
            child: const AdminMediasScreen(),
          );
        },
      ),
    );
  }
}
