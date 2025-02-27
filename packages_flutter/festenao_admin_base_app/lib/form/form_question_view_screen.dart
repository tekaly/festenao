import 'package:festenao_admin_base_app/form/form_question_edit_screen.dart';
import 'package:festenao_common/form/src/fs_form_model.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/busy_indicator.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_app_flutter_widget/view/cv_ui.dart';
import 'package:tekartik_app_flutter_widget/view/tile_padding.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/screen/doc_entity_view_screen.dart';
import 'package:tkcms_admin_app/screen/pop_on_logged_out_mixin.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';
import 'package:tkcms_common/tkcms_sembast.dart';

class DocEntityScreen extends StatefulWidget {
  const DocEntityScreen({super.key});

  @override
  State<DocEntityScreen> createState() => _DocEntityScreenState();
}

class _DocEntityScreenState extends AutoDisposeBaseState<DocEntityScreen>
    with
        PopOnLoggedOutMixin<DocEntityScreen>,
        AutoDisposedBusyScreenStateMixin<DocEntityScreen> {
  @override
  void initState() {
    popOnLoggedOut();
    super.initState();
  }

  DocEntityScreenBloc<FsFormQuestion> get bloc =>
      BlocProvider.of<DocEntityScreenBloc<FsFormQuestion>>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        var fsEntity = state?.fsDocEntity;

        return Scaffold(
          appBar: AppBar(
            title: Text('${bloc.entityName} 2'),
            actions: [
              if (fsEntity?.exists ?? false)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    busyAction(() async {
                      if (await muiConfirm(context)) {
                        await bloc.entityAccess.deleteEntity(bloc.entityId);
                        if (context.mounted) {
                          Navigator.of(context).pop(
                            DocEntityScreenResult(
                              entityId: bloc.entityId,
                              deleted: true,
                            ),
                          );
                        }
                      }
                    });
                  },
                ),
            ],
          ),
          body: fsEntity == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    ListView(
                      children: [
                        ListTile(
                          //title: Text(fsEntity.name.v ?? ''),
                          title: Text(fsEntity.id),
                          onTap: () {
                            // TODO
                          },
                        ),
                        TilePadding(child: CvUiModelValue(model: fsEntity)),
                      ],
                    ),
                    BusyIndicator(busy: busyStream),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              await goToAdminFormQuestionEditScreen(
                context,
                entityAccess: bloc.entityAccess,
                entityId: bloc.entityId,
              );
            },
            child: const Icon(Icons.edit),
          ),
        );
      },
    );
  }
}

class _Property extends StatelessWidget {
  final String name;
  const _Property({required this.name});

  @override
  Widget build(BuildContext context) {
    return Text(name.toUpperCase());
  }
}

class DbUserAccessWidget extends StatelessWidget {
  const DbUserAccessWidget({super.key, required this.dbUserAccess});

  final TkCmsDbUserAccess dbUserAccess;

  @override
  Widget build(BuildContext context) {
    var text = dbUserAccess.isAdmin
        ? 'admin'
        : (dbUserAccess.isWrite
            ? 'write'
            : (dbUserAccess.isRead ? 'read' : ''));
    if (text.isEmpty) {
      return const SizedBox();
    }
    var role = dbUserAccess.role.v;
    return ListTile(
      title: _Property(name: text),
      subtitle: role == null ? null : Text(role),
    );
  }
}

Future<void> goToAdminFormQuestionViewScreen(
  BuildContext context, {
  required TkCmsFirestoreDatabaseServiceDocEntityAccessor<FsFormQuestion>
      entityAccess,
  required String entityId,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () => DocEntityScreenBloc<FsFormQuestion>(
            entityAccess: entityAccess,
            entityId: entityId,
          ),
          child: const DocEntityScreen(),
        );
      },
    ),
  );
}
