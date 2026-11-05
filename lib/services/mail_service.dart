import 'package:enough_mail/enough_mail.dart';

import '../models.dart';
import 'db.dart';

/// Výsledok synchronizácie jednej schránky (doručená / odoslaná).
class BoxSync {
  BoxSync({
    required this.box,
    required this.lastUid,
    required this.uidValidity,
    required this.reset,
    required this.messages,
    required this.seenFlags,
  });

  final String box;
  final int lastUid;
  final int? uidValidity;

  /// UIDVALIDITY sa zmenila, lokálnu kópiu schránky treba zahodiť.
  final bool reset;
  final List<MailMessage> messages;

  /// UID -> prečítané (stav zo servera pre nedávne správy).
  final Map<int, bool> seenFlags;
}

/// IMAP/SMTP vrstva. Prihlásenie heslom alebo OAuth2 (XOAUTH2).
class MailService {
  Future<void> _login(ImapClient client, Account a, String secret) async {
    await client.connectToServer(a.imapHost, a.imapPort, isSecure: true);
    if (a.oauth) {
      await client.authenticateWithOAuth2(a.username, secret);
    } else {
      await client.login(a.username, secret);
    }
  }

  Future<void> _close(ImapClient client) async {
    try {
      await client.logout();
    } catch (_) {}
    try {
      await client.disconnect();
    } catch (_) {}
  }

  /// Inkrementálna synchronizácia: pri prvom behu stiahne posledných [initial]
  /// správ, potom len nové (UID > posledné známe).
  Future<List<BoxSync>> sync(
    Account a,
    String secret,
    Map<String, SyncState> prior, {
    int initial = 150,
  }) async {
    final client = ImapClient(isLogEnabled: false);
    final out = <BoxSync>[];
    try {
      await _login(client, a, secret);
      final boxes = await client.listMailboxes();

      final inbox = await client.selectInbox();
      out.add(await _syncBox(client, a, inbox, 'I', prior['I'], initial));

      final sent = boxes.where((b) => b.isSent).toList();
      if (sent.isNotEmpty) {
        final box = await client.selectMailbox(sent.first);
        out.add(await _syncBox(client, a, box, 'S', prior['S'], initial));
      }
    } finally {
      await _close(client);
    }
    return out;
  }

  Future<BoxSync> _syncBox(
    ImapClient client,
    Account a,
    Mailbox box,
    String tag,
    SyncState? prior,
    int initial,
  ) async {
    final outgoing = tag == 'S';
    var lastUid = prior?.lastUid ?? 0;
    var reset = false;
    if (prior != null &&
        prior.validity != null &&
        box.uidValidity != null &&
        prior.validity != box.uidValidity) {
      reset = true;
      lastUid = 0;
    }

    final fetched = <MimeMessage>[];
    final flags = <int, bool>{};

    if (box.messagesExists > 0) {
      if (lastUid == 0) {
        final r = await client.fetchRecentMessages(
          messageCount: initial,
          criteria: 'BODY.PEEK[]',
        );
        fetched.addAll(r.messages);
      } else {
        final seq = MessageSequence.fromRangeToLast(lastUid + 1,
            isUidSequence: true);
        final r = await client.uidFetchMessages(seq, 'BODY.PEEK[]');
        // IMAP vráti pri "n:*" vždy aspoň poslednú správu, preto filter.
        fetched.addAll(r.messages.where((m) => (m.uid ?? 0) > lastUid));

        if (!outgoing) {
          try {
            final fr = await client.fetchRecentMessages(
              messageCount: 200,
              criteria: '(UID FLAGS)',
            );
            for (final m in fr.messages) {
              final uid = m.uid;
              if (uid != null) flags[uid] = m.isSeen;
            }
          } catch (_) {
            // stav „prečítané“ je nepovinný
          }
        }
      }
    }

    final messages = <MailMessage>[];
    var newLast = lastUid;
    for (final m in fetched) {
      final uid = m.uid;
      if (uid != null && uid > newLast) newLast = uid;
      final msg = _convert(m, a, outgoing, tag);
      if (msg != null) messages.add(msg);
    }

    return BoxSync(
      box: tag,
      lastUid: newLast,
      uidValidity: box.uidValidity,
      reset: reset,
      messages: messages,
      seenFlags: flags,
    );
  }

  MailMessage? _convert(MimeMessage m, Account a, bool outgoing, String tag) {
    final people = outgoing ? (m.to ?? const []) : (m.from ?? const []);
    if (people.isEmpty) return null;
    final p = people.first;
    final email = p.email.toLowerCase();
    if (email.isEmpty) return null;
    final name = (p.personalName != null && p.personalName!.trim().isNotEmpty)
        ? p.personalName!.trim()
        : email;
    List<String> attachments = const [];
    try {
      attachments = m
          .findContentInfo()
          .map((c) => c.fileName ?? 'príloha')
          .toList();
    } catch (_) {}
    return MailMessage(
      id: '${a.id}:$tag:${m.uid ?? m.sequenceId}',
      accountId: a.id,
      box: tag,
      uid: m.uid,
      contactEmail: email,
      contactName: name,
      outgoing: outgoing,
      subject: m.decodeSubject() ?? '',
      date: m.decodeDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      text: m.decodeTextPlainPart() ?? '',
      html: m.decodeTextHtmlPart(),
      seen: outgoing ? true : m.isSeen,
      attachments: attachments,
    );
  }

  /// Označí správy v doručenej pošte ako prečítané.
  Future<void> markSeen(Account a, String secret, List<int> uids) async {
    if (uids.isEmpty) return;
    final client = ImapClient(isLogEnabled: false);
    try {
      await _login(client, a, secret);
      await client.selectInbox();
      await client.uidMarkSeen(MessageSequence.fromIds(uids, isUid: true));
    } finally {
      await _close(client);
    }
  }

  Future<void> send(
    Account a,
    String secret, {
    required String to,
    required String subject,
    required String body,
  }) async {
    final message = MessageBuilder.buildSimpleTextMessage(
      MailAddress(a.name, a.email),
      [MailAddress(null, to)],
      body,
      subject: subject,
    );

    final client = SmtpClient(a.smtpHost, isLogEnabled: false);
    try {
      final implicitTls = a.smtpPort == 465;
      await client.connectToServer(a.smtpHost, a.smtpPort,
          isSecure: implicitTls);
      await client.ehlo();
      if (!implicitTls) {
        await client.startTls();
        await client.ehlo();
      }
      await client.authenticate(
        a.username,
        secret,
        a.oauth ? AuthMechanism.xoauth2 : AuthMechanism.plain,
      );
      await client.sendMessage(message);
    } finally {
      try {
        await client.quit();
      } catch (_) {}
    }

    // Gmail a Outlook ukladajú odoslané samy; ostatné servery zvyčajne nie.
    if (a.provider == MailProvider.custom) {
      try {
        await _appendToSent(a, secret, message);
      } catch (_) {}
    }
  }

  Future<void> _appendToSent(
      Account a, String secret, MimeMessage message) async {
    final client = ImapClient(isLogEnabled: false);
    try {
      await _login(client, a, secret);
      final boxes = await client.listMailboxes();
      final sent = boxes.where((b) => b.isSent).toList();
      if (sent.isEmpty) return;
      await client.appendMessage(
        message,
        targetMailbox: sent.first,
        flags: [r'\Seen'],
      );
    } finally {
      await _close(client);
    }
  }
}
