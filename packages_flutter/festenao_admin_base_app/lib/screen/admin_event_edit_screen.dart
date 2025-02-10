import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/button_tile.dart';
import 'package:festenao_admin_base_app/view/calendar_edit_tile.dart';
import 'package:festenao_admin_base_app/view/linear_wait.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_common/data/calendar.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter/foundation.dart';
import 'package:tkcms_admin_app/view/body_container.dart';

import 'admin_article_edit_screen_bloc_mixin.dart';
import 'admin_article_edit_screen_mixin.dart';
import 'admin_artists_screen.dart';
import 'admin_event_edit_screen_bloc.dart';
import 'admin_infos_screen.dart';

class AdminEventEditScreen extends StatefulWidget {
  const AdminEventEditScreen({super.key});

  @override
  State<AdminEventEditScreen> createState() => _AdminEventEditScreenState();
}

class _AdminEventEditScreenState extends State<AdminEventEditScreen>
    with AdminArticleEditScreenMixin {
  TextEditingController? beginTimeController;
  TextEditingController? endTimeController;
  ValueNotifier<CalendarDay?>? day;
  @override
  void dispose() {
    articleMixinDispose();
    beginTimeController?.dispose();
    endTimeController?.dispose();
    day?.dispose();
    super.dispose();
  }

  void _addAttribute(CvAttribute attribute) {
    var vn = attributesValueNotifier!;
    vn.value = [...vn.value ?? <CvAttribute>[], attribute];
  }

  AdminEventEditScreenBloc get bloc =>
      BlocProvider.of<AdminEventEditScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return ValueStreamBuilder<AdminEventEditScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;

          var event = state?.event;
          var eventId = bloc.eventId;
          var canSave = eventId == null || event != null;
          var article = event;

          // For our mixin
          mainArticle = article;

          if (eventId == null) {
            event?.attributes.v?.forEach((attribute) {
              var info = attribute.getAttributeInfo();

              // find artist
              if (info.artistId != null) {
                eventId = info.artistId!;
              }
            });
          }
          return AdminScreenLayout(
            appBar: AppBar(
              actions: [
                if (bloc.eventId != null)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Supprimer',
                    onPressed: () {
                      _onDelete(context);
                    },
                  ),
              ],
              title: const Text('Event'),
            ),
            body: Builder(
              builder: (context) {
                if (!canSave) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                // devPrint('canSave $canSave $eventId $event');

                return Stack(
                  children: [
                    ListView(children: [
                      Form(
                        key: formKey,
                        child: BodyContainer(
                          child: Column(children: [
                            if (event == null && eventId != null)
                              const ListTile(
                                title: Text('Non trouvé'),
                              )
                            else ...[
                              ListTile(
                                title: Text(eventId ?? 'new'),
                              ),
                            ],
                            AppTextFieldTile(
                              controller: idController ??=
                                  TextEditingController(
                                      text: eventId ?? event?.idOrNull),
                              labelText: textIdLabel,
                            ),
                            getCommonWidgets(event),
                            AppTextFieldTile(
                              controller: nameController ??=
                                  TextEditingController(text: event?.name.v),
                              emptyAllowed: true,
                              labelText: textNameLabel,
                            ),
                            AppTextFieldTile(
                              controller: subtitleController ??=
                                  TextEditingController(
                                      text: event?.subtitle.v),
                              emptyAllowed: true,
                              labelText: textSubtitleLabel,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: CalendarFormFieldTile(
                                    context: context,
                                    labelText: textDayLabel,
                                    valueNotifier: day ??= ValueNotifier<
                                            CalendarDay?>(
                                        parseCalendarDayOrNull(event?.day.v)),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: AppTextFieldTile(
                                    controller: beginTimeController ??=
                                        TextEditingController(
                                            text: event?.beginTime.v),
                                    validator: (text) {
                                      try {
                                        CalendarTime(text: text);
                                        return null;
                                      } catch (_) {
                                        return 'Format heure invalid (00:00 => 47:59)';
                                      }
                                    },
                                    labelText: textBeginTimeLabel,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: AppTextFieldTile(
                                    controller: endTimeController ??=
                                        TextEditingController(
                                            text: event?.endTime.v),
                                    validator: (text) {
                                      try {
                                        CalendarTime(text: text);
                                        return null;
                                      } catch (_) {
                                        return 'Format heure invalid (00:00 => 47:59)';
                                      }
                                    },
                                    labelText: textEndTimeLabel,
                                  ),
                                ),
                              ],
                            ),
                            getBottomCommonWidgets(article),
                            getAttributesTile(article),
                            Row(
                              children: [
                                ButtonTile(
                                    child: TextButton(
                                  onPressed: () async {
                                    var result = await selectArtist(context,
                                        projectContext: projectContext);
                                    if (result?.artist != null) {
                                      _addAttribute(CvAttribute()
                                        ..value.v = attrMakeFromArtistId(
                                            result!.artist!.id));
                                    }
                                  },
                                  child: const Text('Add artist'),
                                )),
                              ],
                            ),
                            ButtonTile(
                                child: TextButton(
                              onPressed: () async {
                                var result = await selectInfo(context,
                                    infoType: infoTypeLocation,
                                    projectContext: projectContext);
                                if (result?.info != null) {
                                  _addAttribute(CvAttribute()
                                    ..value.v = attrMakeLocationFromInfoId(
                                        result!.info!.id));
                                }
                              },
                              child: const Text('Ajout lieu'),
                            )),
                            ButtonTile(
                                child: TextButton(
                              onPressed: () async {
                                var result = await selectInfo(context,
                                    projectContext: projectContext);
                                if (result?.info != null) {
                                  _addAttribute(CvAttribute()
                                    ..value.v =
                                        attrMakeFromInfoId(result!.info!.id));
                                }
                              },
                              child: const Text('Ajout info'),
                            )),
                            AppTextFieldTile(
                              controller: contentController ??=
                                  TextEditingController(text: event?.content.v),
                              maxLines: 10,
                              emptyAllowed: true,
                              labelText: 'Contenu',
                            ),
                            getThumbailNameWidget(article),
                            getThumbnailSelectorTile(article),
                            getThumbnailPreviewTile(article),
                            getSquareNameWidget(article),
                            getSquareSelectorTile(article),
                            getSquarePreviewTile(article),
                            getImageNameWidget(article),
                            getImageSelectorTile(article),
                            getImagePreviewTile(article),
                            const SizedBox(
                              height: 64,
                            ),
                          ]),
                        ),
                      )
                    ]),
                    LinearWait(
                      showNotifier: saving,
                    ),
                  ],
                );
              },
            ),
            floatingActionButton: canSave
                ? FloatingActionButton(
                    onPressed: () => _onSave(context),
                    child: const Icon(Icons.save),
                  )
                : null,
          );
        });
  }

  final _saveLock = Lock();

  Future<void> _onSave(BuildContext context) async {
    if (formKey.currentState!.validate() && !_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          var bloc = BlocProvider.of<AdminEventEditScreenBloc>(context);
          formKey.currentState!.save();
          var dbEvent = DbEvent()
            ..rawRef = dbEventStoreRef.record(idController!.text).rawRef
            ..day.v = day!.value!.toString()
            ..beginTime.v = beginTimeController!.text
            ..endTime.v = endTimeController!.text;
          articleFromForm(dbEvent);
          await bloc.save(
              AdminArticleEditData(article: dbEvent, imageData: newImageData));
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        } catch (e, st) {
          if (kDebugMode) {
            print(e);
            print(st);
          }
        } finally {
          saving.value = false;
        }
      });
    }
  }

  Future<void> _onDelete(BuildContext context) async {
    if (!_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          var bloc = BlocProvider.of<AdminEventEditScreenBloc>(context);
          await bloc.delete();
          if (context.mounted) {
            Navigator.of(context)
                .pop(AdminEventEditScreenResult(deleted: true));
          }
        } catch (e, st) {
          if (kDebugMode) {
            print(e);
            print(st);
          }
        } finally {
          saving.value = false;
        }
      });
    }
  }

  @override
  AdminArticleEditScreenInfo get info =>
      AdminArticleEditScreenInfo(articleKind: articleKindEvent);

  @override
  AdminAppProjectContextDbBloc get dbBloc => bloc.dbBloc;

  @override
  // TODO: implement projectContext
  FestenaoAdminAppProjectContext get projectContext => bloc.projectContext;
}

Future<AdminEventEditScreenResult?> goToAdminEventEditScreen(
    BuildContext context,
    {required String? eventId,
    AdminEventEditScreenParam? param,
    required FestenaoAdminAppProjectContext projectContext}) async {
  var result = await Navigator.of(context)
      .push<Object?>(MaterialPageRoute(builder: (context) {
    return BlocProvider(
        blocBuilder: () => AdminEventEditScreenBloc(
            eventId: eventId, param: param, projectContext: projectContext),
        child: const AdminEventEditScreen());
  }));
  if (result is AdminEventEditScreenResult) {
    return result;
  }
  return null;
}
