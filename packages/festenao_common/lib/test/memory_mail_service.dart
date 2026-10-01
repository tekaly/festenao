import 'package:tekartik_mail/mail_mixin.dart';

/// The result of an in memory send.
class MemorySendMailResult implements SendMailResult {
  @override
  final String? messageId;

  /// The result of an in memory send.
  MemorySendMailResult({this.messageId});
}

/// A mail service keeping the messages instead of sending them, for tests.
class MemoryMailService with MailServiceMixin {
  /// The messages sent so far.
  final messages = <MailMessage>[];

  /// When set, every send throws it instead of keeping the message.
  Exception? error;

  var _count = 0;

  @override
  Future<SendMailResult> sendMail(MailMessage message) async {
    var error = this.error;
    if (error != null) {
      throw error;
    }
    messages.add(message);
    return MemorySendMailResult(messageId: 'memory_${++_count}');
  }
}
