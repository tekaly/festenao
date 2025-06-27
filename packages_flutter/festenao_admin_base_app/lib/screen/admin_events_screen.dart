import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/view/admin_article_thumbnail.dart';
import 'package:tekartik_common_utils/string_utils.dart';

import 'admin_event_edit_screen.dart';
import 'admin_event_screen.dart';
import 'project_root_screen.dart';
import 'screen_bloc_import.dart';
import 'screen_import.dart';

class AdminEventsScreenBlocState {
  final List<DbEvent> list;

  AdminEventsScreenBlocState(this.list);
}

class AdminEventsScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminEventsScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _eventSubscription;
  var _showHidden = false;
  bool get showHidden => _showHidden;
  set showHidden(bool on) {
    _showHidden = on;
    _refresh();
  }

  Future<void> _refresh() async {
    var model = DbEvent();
    var db = await projectDb;
    audiDispose(_eventSubscription);
    _eventSubscription = audiAddStreamSubscription(
      dbEventStoreRef
          .query(
            finder: Finder(
              sortOrders: [
                SortOrder(model.day.name),
                SortOrder(model.beginTime.name),
              ],
            ),
          )
          .onRecords(db)
          .listen((records) {
            add(
              AdminEventsScreenBlocState(
                records
                    .where(
                      (element) =>
                          _showHidden || !element.hasTag(articleTagHidden),
                    )
                    .toList(),
              ),
            );
          }),
    );
  }

  AdminEventsScreenBloc({required super.projectContext}) {
    _refresh();
  }
}

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen>
    with AdminAppProjectScreenStateMixin {
  AdminEventsScreenBloc get bloc =>
      BlocProvider.of<AdminEventsScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return AdminScreenLayout(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          PopupMenuButton(
            //offset: Offset(100, 100),
            elevation: 5.0,
            // child: _menuIcon,
            itemBuilder: (context) => [
              PopupMenuItem<bool>(
                child: StatefulBuilder(
                  builder: (bulderContext, doSetState) => SwitchListTile(
                    //activeColor: kLeadingOrangeColor,
                    value: bloc.showHidden, // isShow,
                    onChanged: (value) => doSetState(() {
                      bloc.showHidden = value;
                    }),
                    title: const Text('Show hidden'),
                  ),
                ),
              ),
            ],
          ),
          /*SwitchListTile(value: true, onChanged: (_) {
          print('onChanged');
        }
        )*/
        ],
      ),
      body: ValueStreamBuilder<AdminEventsScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var list = snapshot.data?.list;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              var event = list[index];
              var tags = event.tags.v?.join(', ');
              var attributes = event.attributes.value
                  ?.map(
                    (e) =>
                        '${stringIsEmpty(e.type.v) ? '' : '${e.type.v}:'}${stringNonEmpty(e.value.v) ?? stringNonEmpty(e.name.v)}',
                  )
                  .join(', ');
              return ListTile(
                leading: AdminArticleThumbnail(article: event, dbBloc: dbBloc),
                title: Text(event.nameOrId),
                subtitle: Text(
                  '${event.day.v} ${event.beginTime.v}-${event.endTime.v}'
                  '\n$tags'
                  '\n$attributes',
                ),
                onTap: () {
                  goToAdminEventScreen(
                    context,
                    eventId: event.id,
                    projectContext: projectContext,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          goToAdminEventEditScreen(
            context,
            eventId: null,
            projectContext: projectContext,
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  // TODO: implement dbBloc
  AdminAppProjectContextDbBloc get dbBloc => bloc.dbBloc;
}

Future<void> goToAdminEventsScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  if (festenaoUseContentPathNavigation) {
    await popAndGoToProjectSubScreen(
      context,
      projectContext: projectContext,
      contentPath: ProjectEventsContentPath(),
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () =>
                AdminEventsScreenBloc(projectContext: projectContext),
            child: const AdminEventsScreen(),
          );
        },
      ),
    );
  }
}
