@TestOn('vm')
library;

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_email_invite_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:test/test.dart';

/// The status of the apps (normal, read only, maintenance): the model, the
/// stream the apps follow and the commands the server refuses.
void main() {
  group('model', () {
    test('mode parse', () {
      expect(FestenaoAppStatusMode.parse(null), FestenaoAppStatusMode.normal);
      expect(FestenaoAppStatusMode.parse(''), FestenaoAppStatusMode.normal);
      expect(
        FestenaoAppStatusMode.parse('read_only'),
        FestenaoAppStatusMode.readOnly,
      );
      // Unknown: as strict as maintenance.
      expect(
        FestenaoAppStatusMode.parse('off'),
        FestenaoAppStatusMode.maintenance,
      );
      expect(
        FestenaoAppStatusMode.tryParse('read-only'),
        FestenaoAppStatusMode.readOnly,
      );
      expect(FestenaoAppStatusMode.tryParse('off'), isNull);
    });
    test('stricter', () {
      var readOnly = const FestenaoAppStatus(
        mode: FestenaoAppStatusMode.readOnly,
        message: 'ro',
      );
      var maintenance = const FestenaoAppStatus(
        mode: FestenaoAppStatusMode.maintenance,
        message: 'm',
      );
      expect(FestenaoAppStatus.normal.stricter(readOnly), readOnly);
      expect(readOnly.stricter(maintenance), maintenance);
      expect(maintenance.stricter(readOnly), maintenance);
      expect(readOnly.stricter(FestenaoAppStatus.normal), readOnly);
    });
    test('messageFor', () {
      var status = const FestenaoAppStatus(
        mode: FestenaoAppStatusMode.maintenance,
        message: 'Default',
        messages: {'fr': 'Maintenance en cours', 'en': 'Under maintenance'},
      );
      expect(status.messageFor('fr'), 'Maintenance en cours');
      expect(status.messageFor('de'), 'Default');
      expect(
        const FestenaoAppStatus(messages: {'en': 'Hi'}).messageFor('fr'),
        'Hi',
      );
      expect(FestenaoAppStatus.normal.messageFor('fr'), isNull);
    });
    test('read commands', () {
      for (var command in [
        'timestamp',
        'info',
        'auth/me',
        'user-plan/get',
        'entity/project/get-create-limit',
        'entity/project/get-user-info',
        'entity/project/list-email-invites',
        'custom-domain/list',
        'orga/registration/get',
      ]) {
        expect(
          festenaoAppStatusIsReadCommand(command),
          isTrue,
          reason: command,
        );
      }
      for (var command in [
        'entity/project/create',
        'user-plan/set',
        'events/publish',
        'app-user/seen',
        'custom-domain/add',
        'orga/registration/submit',
      ]) {
        expect(
          festenaoAppStatusIsReadCommand(command),
          isFalse,
          reason: command,
        );
      }
    });
    test('paths', () {
      expect(
        festenaoAppStatusDocument('my_app').path,
        'app/my_app/public/get/info/status',
      );
      expect(festenaoGlobalStatusDocument().path, 'public/get/info/status');
      expect(
        festenaoProjectStatusDocument('my_app', 'p1').path,
        'app/my_app/public/get/project_status/p1',
      );
    });
  });

  group('server', () {
    late FestenaoTestServerContext context;
    late FestenaoProjectsServerApp serverApp;
    late Firestore firestore;
    late String app;
    late FestenaoUserPlanApiClient planClient;
    late DateTime now;

    Future<void> setStatus(
      CvDocumentReference<FsFestenaoAppStatus> ref,
      FestenaoAppStatusMode? mode, {
      String? message,
    }) async {
      if (mode == null) {
        await ref.delete(firestore);
      } else {
        await ref.set(
          firestore,
          FsFestenaoAppStatus()
            ..mode.v = mode.value
            ..message.v = message,
        );
      }
    }

    Future<void> setAppStatus(FestenaoAppStatusMode? mode, {String? message}) =>
        setStatus(festenaoAppStatusDocument(app), mode, message: message);

    Future<void> expectRefused(
      Future<void> Function() action,
      FestenaoAppStatusMode mode, {
      String? message,
    }) => expectLater(
      action(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.error?.code.v, 'code', 'unavailable')
            .having((e) => festenaoApiErrorAppStatusMode(e.error), 'mode', mode)
            .having(
              (e) => e.error?.message.v,
              'message',
              message ?? isNotEmpty,
            ),
      ),
    );

    Future<String> create(String name) async =>
        (await context.projectApiClient.createEntity(
          entity: FsProject()..name.v = name,
        )).id;

    setUpAll(() async {
      context = await initFestenaoTestServerContextAllMemory();
      serverApp = context.ffContext.serverApp as FestenaoProjectsServerApp;
      firestore = context.fsDatabase.firestore;
      app = serverApp.app;
      now = DateTime(2026, 11, 9);
      serverApp.appStatusHandler = FestenaoAppStatusHandler(
        apps: [app],
        firestore: firestore,
        now: () => now,
      );
      serverApp.userPlanHandler = FestenaoUserPlanHandler(
        apps: [app],
        firestore: firestore,
      );
      planClient = FestenaoUserPlanApiClient(apiService: context.apiService);
    });
    tearDownAll(() async {
      await context.close();
    });
    setUp(() async {
      await setAppStatus(null);
      await setStatus(festenaoGlobalStatusDocument(), null);
      serverApp.appStatusHandler!.clearCache();
    });

    test('maintenance, read only, back to normal', () async {
      await festenaoLocalAuthSignInVerified(context, 'status@test.local');
      await create('Normal');

      await setAppStatus(
        FestenaoAppStatusMode.maintenance,
        message: 'Retour à 18 h',
      );
      // Seen once the cache expires.
      await create('Still cached');
      now = now.add(const Duration(seconds: 31));
      await expectRefused(
        () => create('Maintenance'),
        FestenaoAppStatusMode.maintenance,
        message: 'Retour à 18 h',
      );
      await expectRefused(
        () => planClient.get(),
        FestenaoAppStatusMode.maintenance,
      );
      // The server's own commands still answer.
      expect(await context.apiService.getTimestamp(), isNotNull);

      await setAppStatus(FestenaoAppStatusMode.readOnly);
      serverApp.appStatusHandler!.clearCache();
      expect((await planClient.get()).blocked.v, isNull);
      await expectRefused(
        () => create('Read only'),
        FestenaoAppStatusMode.readOnly,
      );

      await setAppStatus(FestenaoAppStatusMode.normal);
      serverApp.appStatusHandler!.clearCache();
      await create('Normal again');
    });

    test('the global status, every app', () async {
      await festenaoLocalAuthSignInVerified(context, 'global@test.local');
      await setStatus(
        festenaoGlobalStatusDocument(),
        FestenaoAppStatusMode.maintenance,
      );
      await expectRefused(
        () => create('Global'),
        FestenaoAppStatusMode.maintenance,
      );
      // The stricter one wins.
      await setAppStatus(FestenaoAppStatusMode.readOnly);
      serverApp.appStatusHandler!.clearCache();
      await expectRefused(
        () => planClient.get(),
        FestenaoAppStatusMode.maintenance,
      );
    });

    test('an app admin is always served', () async {
      var userId = await festenaoLocalAuthSignInVerified(
        context,
        'status-admin@test.local',
      );
      await context.fsDatabase.appDb.setEntityUserAccess(
        entityId: app,
        userId: userId,
        userAccess: TkCmsFsUserAccess()
          ..admin.v = true
          ..fixAccess(),
      );
      await setAppStatus(FestenaoAppStatusMode.maintenance);
      await create('By the admin');
    });

    test('the status of a project', () async {
      var handler = serverApp.appStatusHandler!;
      ApiRequest request(String? userId) => ApiRequest(command: 'some/write')
        ..app.v = app
        ..userId.v = userId;
      Future<void> require(String? userId, {bool write = true}) =>
          handler.requireProjectAvailable(
            request(userId),
            app: app,
            projectId: 'p1',
            write: write,
          );
      Future<void> expectProjectRefused(
        Future<void> Function() action,
        FestenaoAppStatusMode mode,
      ) => expectLater(
        action(),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => festenaoApiErrorAppStatusMode(e.error),
                'mode',
                mode,
              )
              .having(
                (e) => e.error?.message.v,
                'message',
                contains('This project'),
              ),
        ),
      );

      var projectRef = festenaoProjectStatusDocument(app, 'p1');
      await require('someone');

      await setStatus(projectRef, FestenaoAppStatusMode.readOnly);
      handler.clearCache();
      await require('someone', write: false);
      await expectProjectRefused(
        () => require('someone'),
        FestenaoAppStatusMode.readOnly,
      );
      // Another project is not concerned.
      await handler.requireProjectAvailable(
        request('someone'),
        app: app,
        projectId: 'p2',
      );

      await setStatus(projectRef, FestenaoAppStatusMode.maintenance);
      handler.clearCache();
      await expectProjectRefused(
        () => require('someone', write: false),
        FestenaoAppStatusMode.maintenance,
      );
      expect(
        (await festenaoProjectStatusGet(
          firestore,
          app: app,
          projectId: 'p1',
        )).isMaintenance,
        isTrue,
      );

      // The app status counts too.
      await setStatus(projectRef, null);
      await setAppStatus(FestenaoAppStatusMode.readOnly);
      handler.clearCache();
      await expectLater(
        require('someone'),
        throwsA(
          isA<ApiException>().having(
            (e) => festenaoApiErrorAppStatusMode(e.error),
            'mode',
            FestenaoAppStatusMode.readOnly,
          ),
        ),
      );
    });
  });

  test('festenaoAppStatusOnSnapshot', () async {
    var context = await initFestenaoTestServerContextAllMemory();
    try {
      var firestore = context.fsDatabase.firestore;
      var statuses = festenaoAppStatusOnSnapshot(
        firestore,
        app: 'snapshot_app',
      ).asBroadcastStream();
      // Listened before the change, so that its status is not missed.
      Future<FestenaoAppStatus> next(
        bool Function(FestenaoAppStatus status) test,
        Future<void> Function() change,
      ) async {
        var future = statuses.firstWhere(test);
        await change();
        return await future;
      }

      var keepListening = statuses.listen((_) {});
      expect(await statuses.first, FestenaoAppStatus.normal);

      var status = await next(
        (status) => status.isReadOnly,
        () => festenaoAppStatusDocument('snapshot_app').set(
          firestore,
          FsFestenaoAppStatus()
            ..mode.v = FestenaoAppStatusMode.readOnly.value
            ..messages.v = {'fr': 'Lecture seule'},
        ),
      );
      expect(status.messageFor('fr'), 'Lecture seule');

      await next(
        (status) => status.isMaintenance,
        () => festenaoGlobalStatusDocument().set(
          firestore,
          FsFestenaoAppStatus()
            ..mode.v = FestenaoAppStatusMode.maintenance.value,
        ),
      );
      expect(
        (await festenaoAppStatusGet(
          firestore,
          app: 'snapshot_app',
        )).isMaintenance,
        isTrue,
      );

      // Back to the app's own.
      await next(
        (status) => status.isReadOnly,
        () => festenaoGlobalStatusDocument().delete(firestore),
      );
      await keepListening.cancel();
    } finally {
      await context.close();
    }
  });
}
