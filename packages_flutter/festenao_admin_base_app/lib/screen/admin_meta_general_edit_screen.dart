import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
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
      AdminAppProjectContextDbBloc(projectContext: projectContext));

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
  var controllers = <TextEditingController>[];
  var controllerInitialized = false;
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
            appBar: AppBar(
              title: const Text('Meta General'),
            ),
            body: Builder(builder: (context) {
              if (state == null) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              var meta = state.meta;
              if (!controllerInitialized) {
                for (var field in meta.fields) {
                  controllers.add(audiAddTextEditingController(
                      TextEditingController(
                          text: field.valueOrNull?.toString() ?? '')));
                }
              }

              var children = <Widget>[];
              for (var i = 0; i < meta.fields.length; i++) {
                var field = meta.fields[i];
                children.add(AppTextFieldTile(
                  labelText: field.name,
                  controller: controllers[i],
                ));
              }
              return Stack(
                children: [
                  ListView(children: children),
                  BusyIndicator(
                    busy: busyStream,
                  )
                ],
              );
            }),
            floatingActionButton: FloatingActionButton(
              onPressed: state == null
                  ? null
                  : () async {
                      await busyAction(() async {
                        var meta = state.meta;
                        for (var i = 0; i < meta.fields.length; i++) {
                          var field = meta.fields[i];
                          var controller = controllers[i];
                          var text = stringNonEmpty(controller.text.trim());
                          if (field.type == String) {
                            field.setValue(stringNonEmpty(text));
                          } else {
                            throw UnsupportedError('$field type not supported');
                          }
                        }
                        await bloc.save(meta);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      });
                      //await goToAdminUserEditScreen(context, userId: null);
                      //await bloc.refresh();
                    },
              child: const Icon(Icons.save),
            ),
          );
        });
  }
}

Future<void> goToAdminMetaGeneralEditScreen(BuildContext context,
    {required FestenaoAdminAppProjectContext projectContext}) async {
  await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => BlocProvider(
          blocBuilder: () =>
              AdminMetaGeneralEditScreenBloc(projectContext: projectContext),
          child: const AdminMetaGeneralEditScreen())));
}
