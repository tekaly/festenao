import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festenao_email_invite_mailer.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/memory_mail_service.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The mail of an email invite, sent by the memory server through a memory
/// mail service, and the texts.
void main() {
  group('email invite mail', () {
    late FestenaoTestServerContext context;
    late FestenaoServerAppTest serverApp;
    late MemoryMailService mailService;

    setUpAll(() async {
      context = await initFestenaoTestServerContextAllMemory();
      // Only the memory server is at hand to set the mailer on.
      serverApp = context.ffContext.serverApp as FestenaoServerAppTest;
      mailService = MemoryMailService();
      serverApp
          .projectEmailInviteMailer
          .mailer = FestenaoMailServiceEmailInviteMailer(
        mailService: mailService,
        options: FestenaoEmailInviteMailOptions(
          appName: 'Festenao test',
          appUrl: 'https://festenao.test/app',
          from: MailRecipient(email: 'noreply@festenao.test', name: 'Festenao'),
          language: festenaoEmailInviteMailLanguageEn,
        ),
      );
    });
    tearDownAll(() async {
      await context.close();
    });

    test('sent on create, the invite stays when it fails', () async {
      var client = context.projectApiClient;
      var entityId = (await client.createEntity(
        entity: FsProject()..name.v = 'Mail test',
      )).id;

      var result = await client.sendEntityEmailInvite(
        entityId: entityId,
        email: 'Invitee@Test.Local',
        fsUserAccess: TkCmsFsUserAccess()..write.v = true,
      );
      expect(result.mailSent.v, isTrue);
      expect(result.email.v, 'invitee@test.local');
      var message = mailService.messages.single;
      expect(message.to!.single.email, 'invitee@test.local');
      expect(message.from!.email, 'noreply@festenao.test');
      expect(message.subject, '[Festenao test] Invitation: Mail test');
      var text = message.text!;
      expect(text, contains('"Mail test"'));
      expect(text, contains('write access'));
      expect(text, contains('https://festenao.test/app'));
      expect(text, contains('(invitee@test.local)'));
      // The owner of the memory context has no display name: its email.
      expect(text, contains('test invites you'));

      // Inviting again sends again.
      await client.createEntityEmailInvite(
        entityId: entityId,
        email: 'invitee@test.local',
        fsUserAccess: TkCmsFsUserAccess()..read.v = true,
      );
      expect(mailService.messages.length, 2);
      expect(mailService.messages.last.text, contains('read access'));

      // The mail service fails: the invite exists, the mail is reported as
      // not sent.
      mailService.error = Exception('mail service down');
      var result2 = await client.sendEntityEmailInvite(
        entityId: entityId,
        email: 'other@test.local',
        fsUserAccess: TkCmsFsUserAccess()..read.v = true,
      );
      expect(result2.mailSent.v, isFalse);
      expect(result2.inviteId.v, isNotNull);
      expect(mailService.messages.length, 2);
      expect(
        (await client.listEntityEmailInvites(
          entityId: entityId,
        )).map((e) => e.email.v).toSet(),
        {'invitee@test.local', 'other@test.local'},
      );
      mailService.error = null;

      for (var invite in await client.listEntityEmailInvites(
        entityId: entityId,
      )) {
        await client.deleteEntityEmailInvite(
          entityId: entityId,
          inviteId: invite.inviteId.v!,
        );
      }
      await client.deleteEntity(entityId: entityId);
      await client.purgeEntity(entityId: entityId);
    });

    test('no mailer: not sent', () async {
      var mailer = serverApp.projectEmailInviteMailer.mailer;
      serverApp.projectEmailInviteMailer.mailer = null;
      mailService.messages.clear();
      try {
        var client = context.projectApiClient;
        var entityId = (await client.createEntity(
          entity: FsProject()..name.v = 'No mail test',
        )).id;
        var result = await client.sendEntityEmailInvite(
          entityId: entityId,
          email: 'nomail@test.local',
          fsUserAccess: TkCmsFsUserAccess()..read.v = true,
        );
        expect(result.mailSent.v, isFalse);
        expect(mailService.messages, isEmpty);
        await client.deleteEntityEmailInvite(
          entityId: entityId,
          inviteId: result.inviteId.v!,
        );
        await client.deleteEntity(entityId: entityId);
        await client.purgeEntity(entityId: entityId);
      } finally {
        serverApp.projectEmailInviteMailer.mailer = mailer;
      }
    });
  });

  group('texts', () {
    final invite = TkCmsCvEmailInvite()
      ..inviteId.v = 'i1'
      ..entityId.v = 'e1'
      ..entityName.v = 'Fête 2027'
      ..email.v = 'a@b.c'
      ..admin.v = true
      ..write.v = true
      ..read.v = true;

    test('french by default', () {
      var message = festenaoEmailInviteMailMessage(
        FestenaoEmailInviteMail(invite: invite, inviterName: 'Alex'),
        FestenaoEmailInviteMailOptions(
          appName: 'Festenao',
          appUrl: 'https://festenao.example/app',
          from: MailRecipient(email: 'noreply@festenao.example'),
          replyTo: [MailRecipient(email: 'contact@festenao.example')],
        ),
      );
      expect(message.subject, '[Festenao] Invitation : Fête 2027');
      expect(message.to!.single.email, 'a@b.c');
      expect(message.replyTo!.single.email, 'contact@festenao.example');
      var text = message.text!;
      expect(text, startsWith('Bonjour,\n'));
      expect(text, contains('Alex vous invite à rejoindre « Fête 2027 »'));
      expect(text, contains('(accès administrateur)'));
      expect(text, contains('https://festenao.example/app'));
      expect(text, contains('(a@b.c)'));
    });

    test('english, no inviter name, read access', () {
      var message = festenaoEmailInviteMailMessage(
        FestenaoEmailInviteMail(
          invite: TkCmsCvEmailInvite()
            ..inviteId.v = 'i2'
            ..entityId.v = 'e2'
            ..email.v = 'r@b.c'
            ..read.v = true,
        ),
        FestenaoEmailInviteMailOptions(
          appName: 'Playelio',
          appUrl: 'https://playelio.example',
          from: MailRecipient(email: 'noreply@playelio.example'),
          language: festenaoEmailInviteMailLanguageEn,
        ),
      );
      // No entity name: its id.
      expect(message.subject, '[Playelio] Invitation: e2');
      var text = message.text!;
      expect(text, startsWith('Hello,\n'));
      expect(text, contains('Someone invites you to join "e2" on Playelio'));
      expect(text, contains('(read access)'));
      expect(message.replyTo, isNull);
    });
  });
}
