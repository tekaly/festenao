import 'package:festenao_common/form/src/fs_form_model.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/busy_indicator.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/screen/doc_entities_screen.dart';
import 'package:tkcms_admin_app/screen/pop_on_logged_out_mixin.dart';
//import 'package:tkcms_admin_app/src/import_common.dart';
import 'package:tkcms_admin_app/view/body_container.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';

import 'form_question_edit_screen.dart';
import 'form_question_view_screen.dart';

class AdminFormQuestionsScreen extends StatefulWidget {
  const AdminFormQuestionsScreen({super.key});

  @override
  State<AdminFormQuestionsScreen> createState() =>
      _AdminFormQuestionsScreenState();
}

class _AdminFormQuestionsScreenState
    extends AutoDisposeBaseState<AdminFormQuestionsScreen>
    with
        PopOnLoggedOutMixin<AdminFormQuestionsScreen>,
        AutoDisposedBusyScreenStateMixin<AdminFormQuestionsScreen> {
  @override
  void initState() {
    popOnLoggedOut();
    super.initState();
  }

  DocEntitiesScreenBloc<FsFormQuestion> get bloc =>
      BlocProvider.of<DocEntitiesScreenBloc<FsFormQuestion>>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    var selectMode = bloc.selectMode;
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        var dbEntities = state?.fsEntities;
        return Scaffold(
          appBar: AppBar(
            title: Text('${bloc.entityName} List'),
            actions: [
              IconButton(
                icon: const Icon(Icons.telegram_sharp),
                onPressed: () {
                  busyAction(() async {
                    await bloc.createTestEntity();
                  });
                },
              ),
            ],
          ),
          body:
              dbEntities == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                    children: [
                      ListView.builder(
                        itemCount: dbEntities.length,
                        itemBuilder: (context, index) {
                          var dbEntity = dbEntities[index];

                          Future<void> view() async {
                            await goToAdminFormQuestionViewScreen(
                              context,
                              entityAccess: bloc.entityAccess,
                              entityId: dbEntity.id,
                            );
                          }

                          return BodyContainer(
                            child: ListTile(
                              title: Text(
                                dbEntity.name.v ?? '[empty question]',
                              ),
                              subtitle: Text(dbEntity.id),
                              trailing:
                                  selectMode
                                      ? IconButton(
                                        onPressed: () {
                                          view();
                                        },
                                        icon: const Icon(Icons.more_horiz),
                                      )
                                      : null,
                              onTap: () async {
                                if (selectMode) {
                                  Navigator.of(context).pop(
                                    DocEntitiesSelectResult(
                                      entityId: dbEntity.id,
                                    ),
                                  );
                                } else {
                                  await view();
                                }
                              },
                            ),
                          );
                        },
                      ),
                      BusyIndicator(busy: busyStream),
                    ],
                  ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              await goToAdminFormQuestionEditScreen(
                context,
                entityAccess: bloc.entityAccess,
                entityId: null,
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

Future<void> goToAdminFormQuestionsScreen(
  BuildContext context, {
  required TkCmsFirestoreDatabaseServiceDocEntityAccessor<FsFormQuestion>
  entityAccess,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder:
              () => DocEntitiesScreenBloc<FsFormQuestion>(
                entityAccess: entityAccess,
              ),
          child: const AdminFormQuestionsScreen(),
        );
      },
    ),
  );
}

/// Select an entity
Future<DocEntitiesSelectResult?>
selectBasicEntity<T extends TkCmsFsBasicEntity>(
  BuildContext context, {
  required TkCmsFirestoreDatabaseServiceDocEntityAccessor<T> entityAccess,
}) async {
  var result = await Navigator.of(context).push<Object>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder:
              () => DocEntitiesScreenBloc<T>(
                entityAccess: entityAccess,
                selectMode: true,
              ),
          child: const AdminFormQuestionsScreen(),
        );
      },
    ),
  );
  if (result is DocEntitiesSelectResult) {
    return result;
  }
  return null;
}
