import 'package:festenao_common/form/src/fs_form_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_indicator.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/screen/doc_entity_edit_screen.dart';
import 'package:tkcms_admin_app/screen/pop_on_logged_out_mixin.dart';
import 'package:tkcms_admin_app/view/body_container.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';
import 'package:tkcms_common/tkcms_sembast.dart';

typedef T = FsFormQuestion;

class AdminFormQuestionEditScreen<T extends TkCmsFsDocEntity>
    extends StatefulWidget {
  const AdminFormQuestionEditScreen({super.key});

  @override
  State<AdminFormQuestionEditScreen> createState() =>
      _AdminFormQuestionEditScreenState();
}

class _AdminFormQuestionEditScreenState
    extends AutoDisposeBaseState<AdminFormQuestionEditScreen>
    with
        PopOnLoggedOutMixin<AdminFormQuestionEditScreen>,
        AutoDisposedBusyScreenStateMixin<AdminFormQuestionEditScreen> {
  TextEditingController? _nameController;
  TextEditingController? _slugController;
  TextEditingController? _textController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    popOnLoggedOut();
    super.initState();
  }

  DocEntityEditScreenBloc<FsFormQuestion> get bloc =>
      BlocProvider.of<DocEntityEditScreenBloc<FsFormQuestion>>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return Form(
      key: _formKey,
      child: ValueStreamBuilder(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          var dbEntity = state?.fsEntity;
          //var dbUserAccess = state?.dbUserAccess;
          if (dbEntity != null) {
            _nameController ??= TextEditingController(
              text: dbEntity.name.v,
            ); //
            _textController ??= TextEditingController(
                text: dbEntity.text.v); // dbEntity.name.v);
            _slugController ??= TextEditingController(text: dbEntity.slug.v);
          }
          return Scaffold(
            appBar: AppBar(
              title: Text('${bloc.entityName} 2'),
            ),
            body: dbEntity == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      ListView(
                        children: [
                          const SizedBox(height: 16),
                          BodyContainer(
                            child: Column(
                              children: [
                                BodyHPadding(
                                  child: TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      hintText: 'Name',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                BodyHPadding(
                                  child: TextFormField(
                                    controller: _slugController,
                                    decoration: const InputDecoration(
                                      labelText: 'Slug',
                                      hintText: 'slug',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                BodyHPadding(
                                  child: TextFormField(
                                    controller: _textController,
                                    decoration: const InputDecoration(
                                      labelText: 'Texte',
                                      hintText: 'Texte',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      BusyIndicator(busy: busyStream),
                    ],
                  ),
            floatingActionButton: (dbEntity != null)
                ? FloatingActionButton(
                    onPressed: () {
                      _saveAndClose(dbEntity);
                    },
                    child: const Icon(Icons.save),
                  )
                : null,
          );
        },
      ),
    );
  }

  Future<void> _saveAndClose(T dbEntity) async {
    var busyResult = await busyAction(() async {
      if (_formKey.currentState!.validate()) {
        var bloc = this.bloc;

        var newEntity = cvNewModel<FsFormQuestion>()..copyFrom(dbEntity);

        newEntity.slug.setValue(_slugController!.text.trimmedNonEmpty());
        newEntity.text.setValue(_textController!.text.trimmedNonEmpty());
        newEntity.name.setValue(_nameController!.text.trimmedNonEmpty());

        await bloc.save(newEntity);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
    if (!busyResult.busy) {
      if (busyResult.error != null) {
        if (mounted) {
          if (kDebugMode) {
            print('error: ${busyResult.error}');
            print('st: ${busyResult.errorStackTrace}');
          }
          await muiSnack(context, '${busyResult.error}');
        }
      }
    }
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

Future<void> goToAdminFormQuestionEditScreen<T extends TkCmsFsDocEntity>(
  BuildContext context, {
  required TkCmsFirestoreDatabaseServiceEntityAccessor<FsFormQuestion>
      entityAccess,
  required String? entityId,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () => DocEntityEditScreenBloc<FsFormQuestion>(
            entityAccess: entityAccess,
            entityId: entityId,
          ),
          child: const AdminFormQuestionEditScreen(),
        );
      },
    ),
  );
}
