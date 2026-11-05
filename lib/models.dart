import 'dart:convert';

enum MailProvider { gmail, outlook, custom }

class Account {
  Account({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.provider,
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
    this.oauth = false,
  });

  final String id;
  final String name;
  final String email;
  final String username;
  final MailProvider provider;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;

  /// true = prihlásenie cez OAuth2 (tokeny), false = heslo.
  final bool oauth;

  factory Account.preset({
    required MailProvider provider,
    required String name,
    required String email,
    String? username,
    String imapHost = '',
    int imapPort = 993,
    String smtpHost = '',
    int smtpPort = 465,
    bool oauth = false,
  }) {
    switch (provider) {
      case MailProvider.gmail:
        imapHost = 'imap.gmail.com';
        imapPort = 993;
        smtpHost = 'smtp.gmail.com';
        smtpPort = 465;
        break;
      case MailProvider.outlook:
        imapHost = 'outlook.office365.com';
        imapPort = 993;
        smtpHost = 'smtp.office365.com';
        smtpPort = 587;
        break;
      case MailProvider.custom:
        break;
    }
    return Account(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      email: email,
      username: (username == null || username.isEmpty) ? email : username,
      provider: provider,
      imapHost: imapHost,
      imapPort: imapPort,
      smtpHost: smtpHost,
      smtpPort: smtpPort,
      oauth: oauth,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'username': username,
        'provider': provider.name,
        'imapHost': imapHost,
        'imapPort': imapPort,
        'smtpHost': smtpHost,
        'smtpPort': smtpPort,
        'oauth': oauth,
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        username: j['username'] as String,
        provider: MailProvider.values.byName(j['provider'] as String),
        imapHost: j['imapHost'] as String,
        imapPort: j['imapPort'] as int,
        smtpHost: j['smtpHost'] as String,
        smtpPort: j['smtpPort'] as int,
        oauth: (j['oauth'] as bool?) ?? false,
      );

  static String encodeList(List<Account> list) =>
      jsonEncode(list.map((a) => a.toJson()).toList());
}

class MailMessage {
  MailMessage({
    required this.id,
    required this.accountId,
    required this.contactEmail,
    required this.contactName,
    required this.outgoing,
    required this.subject,
    required this.date,
    required this.text,
    this.html,
    this.seen = true,
    this.uid,
    this.box = 'I',
    this.attachments = const [],
  });

  final String id;
  final String accountId;
  final String contactEmail;
  final String contactName;
  final bool outgoing;
  final String subject;
  final DateTime date;
  final String text;
  final String? html;
  final bool seen;

  /// IMAP UID (null pri lokálne vytvorených správach).
  final int? uid;

  /// 'I' = doručená pošta, 'S' = odoslaná pošta.
  final String box;

  /// Názvy príloh (zatiaľ len na zobrazenie).
  final List<String> attachments;

  bool get isLocal => id.startsWith('local:');

  MailMessage copyWith({bool? seen}) => MailMessage(
        id: id,
        accountId: accountId,
        contactEmail: contactEmail,
        contactName: contactName,
        outgoing: outgoing,
        subject: subject,
        date: date,
        text: text,
        html: html,
        seen: seen ?? this.seen,
        uid: uid,
        box: box,
        attachments: attachments,
      );
}

class Conversation {
  Conversation(this.contactEmail, this.contactName, this.messages);

  final String contactEmail;
  final String contactName;
  final List<MailMessage> messages; // zoradené od najstaršej

  MailMessage get last => messages.last;
  int get unread => messages.where((m) => !m.outgoing && !m.seen).length;
}
