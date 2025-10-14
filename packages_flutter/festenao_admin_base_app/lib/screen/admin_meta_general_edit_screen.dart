import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_base_app/import/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_widget/view/busy_indicator.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

class AdminMetaGeneralEditScreenBlocState {
  final DbMetaGeneral meta;

  AdminMetaGeneralEditScreenBlocState(this.meta);
}

class AdminMetaGeneralEditScreenBloc
    extends AutoDisposeStateBaseBloc<AdminMetaGeneralEditScreenBlocState> {
  final FestenaoAdminAppProjectContext projectContext;
  late final _dbBloc = audiAddDisposable(
    AdminAppProjectContextDbBloc(projectContext: projectContext),
  );

  AdminMetaGeneralEditScreenBloc({required this.projectContext}) {
    () async {
      var db = await _dbBloc.grabDatabase();
      var meta = (await dbMetaGeneralRecordRef.get(db)) ?? DbMetaGeneral();
      add(AdminMetaGeneralEditScreenBlocState(meta));
    }();
  }

  Future<void> save(DbMetaGeneral meta) async {
    var db = await _dbBloc.grabDatabase();
    await dbMetaGeneralRecordRef.put(db, meta);
  }
}

class AdminMetaGeneralEditScreen extends StatefulWidget {
  const AdminMetaGeneralEditScreen({super.key});

  @override
  State<AdminMetaGeneralEditScreen> createState() =>
      _AdminMetaGeneralEditScreenState();
}

class _AdminMetaGeneralEditScreenState
    extends AutoDisposeBaseState<AdminMetaGeneralEditScreen>
    with AutoDisposedBusyScreenStateMixin {
  //var controllers = <TextEditingController>[];
  var controllerInitialized = false;
  late TextEditingController tagsController;
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  DbMeta? lastMeta;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<AdminMetaGeneralEditScreenBloc>(context);

    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        return AdminScreenLayout(
          appBar: AppBar(title: const Text('Meta General')),
          body: Builder(
            builder: (context) {
              if (state == null) {
                return const Center(child: CircularProgressIndicator());
              }
              var meta = state.meta;

              if (!controllerInitialized) {
                tagsController = audiAddTextEditingController(
                  TextEditingController(text: meta.tags.v?.join(', ')),
                );
                nameController = audiAddTextEditingController(
                  TextEditingController(text: meta.name.v),
                );
                descriptionController = audiAddTextEditingController(
                  TextEditingController(text: meta.description.v),
                );
              }

              var children = <Widget>[
                AppTextFieldTile(
                  labelText: meta.name.key,
                  controller: nameController,
                ),
                AppTextFieldTile(
                  labelText: meta.description.key,
                  controller: descriptionController,
                ),
              ];

              children.add(
                AppTextFieldTile(
                  labelText: meta.tags.name,
                  controller: tagsController,
                ),
              );
              return Stack(
                children: [
                  ListView(children: children),
                  BusyIndicator(busy: busyStream),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: state == null
                ? null
                : () async {
                    var result = await busyAction(() async {
                      var meta = state.meta;
                      var name = nameController.text.trimmedNonEmpty();
                      var description = descriptionController.text
                          .trimmedNonEmpty();
                      meta.name.setValue(name);
                      meta.description.setValue(description);

                      var tags = tagsController.text
                          .trimmedNonEmpty()
                          ?.split(',')
                          .map((e) => e.trim())
                          .toList();
                      meta.tags.setValue(tags);

                      await bloc.save(meta);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    });
                    if (result.error != null) {
                      if (kDebugMode) {
                        print(result.errorStackTrace);
                      }
                      if (context.mounted) {
                        muiSnackSync(context, result.error.toString());
                      }
                    }

                    //await goToAdminUserEditScreen(context, userId: null);
                    //await bloc.refresh();
                  },
            child: const Icon(Icons.save),
          ),
        );
      },
    );
  }
}

Future<void> goToAdminMetaGeneralEditScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        blocBuilder: () =>
            AdminMetaGeneralEditScreenBloc(projectContext: projectContext),
        child: const AdminMetaGeneralEditScreen(),
      ),
    ),
  );
}
