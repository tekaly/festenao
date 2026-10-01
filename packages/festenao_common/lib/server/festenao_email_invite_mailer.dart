import 'package:tekartik_mail/mail.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

export 'package:tekartik_mail/mail.dart' show MailRecipient, MailService;

/// What the mail of an addressed email invite is built from.
class FestenaoEmailInviteMail {
  /// The invite: its email, the entity name, the access granted.
  final TkCmsCvEmailInvite invite;

  /// The display name (or the email) of the inviter, when known.
  final String? inviterName;

  /// What the mail of an addressed email invite is built from.
  FestenaoEmailInviteMail({required this.invite, this.inviterName});
}

/// Sends the mail of an addressed email invite to its address (festenao
/// `doc/invite_by_email.md`): the invite exists whether the mail goes or not,
/// the invitee also finds it in the app once signed in with that email.
///
/// Set on the entity handler (`FestenaoEntityHandlerOptions.emailInviteMailer`),
/// typically a [FestenaoMailServiceEmailInviteMailer] on the mail service of
/// the app (the tkmail AWS SES one).
abstract class FestenaoEmailInviteMailer {
  /// Const constructor for subclasses.
  const FestenaoEmailInviteMailer();

  /// False when nothing can be sent yet: the handler then sends nothing and
  /// reports the mail as not sent.
  bool get enabled => true;

  /// Sends the mail of [mail].
  Future<void> sendEmailInvite(FestenaoEmailInviteMail mail);
}

/// A mailer delegating to [mailer], set later (a test server, an app whose
/// mail service is configured after its handlers): nothing is sent until then.
class FestenaoEmailInviteMailerDelegate extends FestenaoEmailInviteMailer {
  /// The mailer the invites go through, none until set.
  FestenaoEmailInviteMailer? mailer;

  /// A mailer delegating to [mailer].
  FestenaoEmailInviteMailerDelegate({this.mailer});

  @override
  bool get enabled => mailer?.enabled ?? false;

  @override
  Future<void> sendEmailInvite(FestenaoEmailInviteMail mail) async {
    var mailer = this.mailer;
    if (mailer == null) {
      throw StateError('No email invite mailer');
    }
    await mailer.sendEmailInvite(mail);
  }
}

/// The French texts of the invite mail.
const festenaoEmailInviteMailLanguageFr = 'fr';

/// The English texts of the invite mail.
const festenaoEmailInviteMailLanguageEn = 'en';

/// How the invite mails are written: the app, where to open it, the sender.
class FestenaoEmailInviteMailOptions {
  /// The app name, in the subject and the text.
  final String appName;

  /// The url the invitee opens: the app, where the pending invites show once
  /// signed in.
  final String appUrl;

  /// The sender (an address the mail service may send from).
  final MailRecipient from;

  /// Where a reply goes, none by default.
  final List<MailRecipient>? replyTo;

  /// [festenaoEmailInviteMailLanguageFr] (the default) or
  /// [festenaoEmailInviteMailLanguageEn].
  final String language;

  /// How the invite mails are written.
  const FestenaoEmailInviteMailOptions({
    required this.appName,
    required this.appUrl,
    required this.from,
    this.replyTo,
    this.language = festenaoEmailInviteMailLanguageFr,
  });
}

/// The access granted by [invite], in the mail language.
String festenaoEmailInviteAccessLabel(
  TkCmsCvEmailInvite invite, {
  required String language,
}) {
  var en = language == festenaoEmailInviteMailLanguageEn;
  if (invite.isAdmin) {
    return en ? 'admin access' : 'accès administrateur';
  }
  if (invite.isWrite) {
    return en ? 'write access' : 'accès éditeur';
  }
  return en ? 'read access' : 'accès lecteur';
}

/// The invite mail (subject and text) of [mail], written per [options].
MailMessage festenaoEmailInviteMailMessage(
  FestenaoEmailInviteMail mail,
  FestenaoEmailInviteMailOptions options,
) {
  var invite = mail.invite;
  var entity = invite.entityName.v ?? invite.entityId.v ?? '';
  var email = invite.email.v ?? '';
  var appName = options.appName;
  var appUrl = options.appUrl;
  var en = options.language == festenaoEmailInviteMailLanguageEn;
  var access = festenaoEmailInviteAccessLabel(
    invite,
    language: options.language,
  );
  var inviter = mail.inviterName;
  if (inviter == null || inviter.trim().isEmpty) {
    inviter = en ? 'Someone' : 'Quelqu\'un';
  }
  String subject;
  String text;
  if (en) {
    subject = '[$appName] Invitation: $entity';
    text =
        'Hello,\n'
        '\n'
        '$inviter invites you to join "$entity" on $appName ($access).\n'
        '\n'
        'Open $appUrl and sign in with this email address ($email) to accept '
        'or decline the invite. The address must be verified.\n'
        '\n'
        'If you were not expecting this invite, ignore this message.\n';
  } else {
    subject = '[$appName] Invitation : $entity';
    text =
        'Bonjour,\n'
        '\n'
        '$inviter vous invite à rejoindre « $entity » sur $appName ($access).\n'
        '\n'
        'Ouvrez $appUrl et connectez-vous avec cette adresse e-mail ($email) '
        'pour accepter ou refuser l\'invitation. L\'adresse doit être '
        'vérifiée.\n'
        '\n'
        'Si vous n\'attendiez pas cette invitation, ignorez ce message.\n';
  }
  return MailMessage(
    from: options.from,
    to: [MailRecipient(email: email)],
    replyTo: options.replyTo,
    subject: subject,
    text: text,
  );
}

/// A mailer on any tekartik_mail [MailService]: the tkmail AWS SES one, an
/// SMTP one... The texts come from [festenaoEmailInviteMailMessage].
class FestenaoMailServiceEmailInviteMailer extends FestenaoEmailInviteMailer {
  /// The mail service the invites go through.
  final MailService mailService;

  /// How the mails are written.
  final FestenaoEmailInviteMailOptions options;

  /// A mailer on [mailService].
  const FestenaoMailServiceEmailInviteMailer({
    required this.mailService,
    required this.options,
  });

  @override
  Future<void> sendEmailInvite(FestenaoEmailInviteMail mail) async {
    await mailService.sendMail(festenaoEmailInviteMailMessage(mail, options));
  }
}
