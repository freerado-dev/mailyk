import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services/db.dart';
import 'services/mail_service.dart';
import 'services/oauth_service.dart';

class AppState extends ChangeNotifier {
  final MailService _mail = MailService();
  final OAuthService _oauth = OAuthService();
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );
  LocalDb? _db;

  List<Account> accounts = [];
  List<MailMessage> _messages = []; // synchronizované (z databázy)
  List<MailMessage> _local = []; // práve odoslané, ešte nie sú na serveri
  bool loading = false;
  bool initialised = false;
  String? error;

  String? selectedContact;
  String query = '';
  String? accountFilter;
  bool unreadOnly = false;
  double listWidth = 360;

  final Map<String, String> _drafts = {};
  final FocusNode searchFocus = FocusNode();

  // ---------------------------------------------------------------- init

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('accounts');
    if (raw != null) {
      accounts = (jsonDecode(raw) as List)
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    listWidth = p.getDouble('listWidth') ?? 360;
    try {
      _db = await LocalDb.open();
      _messages = await _db!.loadAll();
    } catch (e) {
      error = 'Lokálna databáza sa nedá otvoriť: $e';
    }
    initialised = true;
    notifyListeners();
    if (accounts.isNotEmpty) await refresh();
  }

  Future<void> _saveAccounts() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('accounts', Account.encodeList(accounts));
  }

  // ------------------------------------------------------------- účty

  Future<String> _secretFor(Account a) async {
    if (!a.oauth) return await _secure.read(key: 'pw_${a.id}') ?? '';
    final raw = await _secure.read(key: 'tok_${a.id}');
    if (raw == null) {
      throw StateError('Chýbajú prihlasovacie údaje, pridaj účet znova.');
    }
    var t = OAuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (t.expired) {
      t = await _oauth.refresh(a.provider, t);
      await _secure.write(key: 'tok_${a.id}', value: jsonEncode(t.toJson()));
    }
    return t.access;
  }

  /// Heslo (alebo heslo aplikácie). Vyhodí výnimku, ak sa nepodarí prihlásiť.
  Future<void> addPasswordAccount(Account a, String password) async {
    await _mail.sync(a, password, const {}, initial: 1); // test pripojenia
    await _secure.write(key: 'pw_${a.id}', value: password);
    await _register(a);
  }

  /// Prihlásenie cez Google / Microsoft (OAuth2 + PKCE).
  Future<void> addOAuthAccount(MailProvider provider, {String? email}) async {
    final res = await _oauth.signIn(provider);
    final address = res.email ?? email;
    if (address == null || address.isEmpty) {
      throw StateError(
          'Poskytovateľ nevrátil emailovú adresu. Zadaj ju ručne a skús znova.');
    }
    final a = Account.preset(
      provider: provider,
      name: res.name ?? address,
      email: address,
      oauth: true,
    );
    await _secure.write(
        key: 'tok_${a.id}', value: jsonEncode(res.tokens.toJson()));
    await _mail.sync(a, res.tokens.access, const {}, initial: 1);
    await _register(a);
  }

  Future<void> _register(Account a) async {
    accounts = [...accounts, a];
    await _saveAccounts();
    notifyListeners();
    await refresh();
  }

  Future<void> removeAccount(Account a) async {
    await _secure.delete(key: 'pw_${a.id}');
    await _secure.delete(key: 'tok_${a.id}');
    await _db?.deleteAccount(a.id);
    accounts = accounts.where((x) => x.id != a.id).toList();
    _messages = _messages.where((m) => m.accountId != a.id).toList();
    _local = _local.where((m) => m.accountId != a.id).toList();
    if (accountFilter == a.id) accountFilter = null;
    await _saveAccounts();
    notifyListeners();
  }

  // --------------------------------------------------------- synchronizácia

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    final errors = <String>[];
    for (final a in accounts) {
      try {
        final secret = await _secretFor(a);
        final db = _db;
        final prior = db != null ? await db.syncStates(a.id) : const <String, SyncState>{};
        final results = await _mail.sync(a, secret, prior);
        if (db != null) {
          for (final r in results) {
            if (r.reset) await db.clearBox(a.id, r.box);
            await db.upsert(r.messages);
            await db.setSync(a.id, r.box, r.lastUid, r.uidValidity);
            if (r.seenFlags.isNotEmpty) {
              await db.applySeen(a.id, r.box, r.seenFlags);
            }
          }
        } else {
          // bez databázy aspoň zlúčime v pamäti
          final ids = results.expand((r) => r.messages).map((m) => m.id).toSet();
          _messages = [
            ..._messages.where((m) => !ids.contains(m.id)),
            ...results.expand((r) => r.messages),
          ];
        }
        // odoslané správy sú už na serveri, lokálne kópie netreba
        _local = _local.where((m) => m.accountId != a.id).toList();
      } catch (e) {
        errors.add('${a.email}: $e');
      }
    }
    if (_db != null) {
      try {
        _messages = await _db!.loadAll();
      } catch (_) {}
    }
    if (errors.isNotEmpty) error = errors.join('\n');
    loading = false;
    notifyListeners();
  }

  // ------------------------------------------------------ konverzácie

  List<MailMessage> get _all => [..._messages, ..._local];

  List<Conversation> _group(Iterable<MailMessage> msgs) {
    final map = <String, List<MailMessage>>{};
    for (final m in msgs) {
      map.putIfAbsent(m.contactEmail, () => []).add(m);
    }
    final list = <Conversation>[];
    map.forEach((email, items) {
      items.sort((a, b) => a.date.compareTo(b.date));
      final incoming = items.where((m) => !m.outgoing);
      final name = incoming.isNotEmpty
          ? incoming.last.contactName
          : items.last.contactName;
      list.add(Conversation(email, name, items));
    });
    list.sort((a, b) => b.last.date.compareTo(a.last.date));
    return list;
  }

  /// Konverzácie po aplikovaní filtra účtu, „neprečítané“ a vyhľadávania.
  List<Conversation> get conversations {
    final base = accountFilter == null
        ? _all
        : _all.where((m) => m.accountId == accountFilter);
    var list = _group(base);
    if (unreadOnly) list = list.where((c) => c.unread > 0).toList();
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((c) =>
              c.contactName.toLowerCase().contains(q) ||
              c.contactEmail.contains(q) ||
              c.messages.any((m) => m.subject.toLowerCase().contains(q)))
          .toList();
    }
    return list;
  }

  /// Vybraná konverzácia (nezávisle od filtrov, aby výber prežil ich zmenu).
  Conversation? get selected {
    final email = selectedContact;
    if (email == null) return null;
    final msgs = _all.where((m) => m.contactEmail == email).toList();
    if (msgs.isEmpty) return null;
    return _group(msgs).first;
  }

  int unreadFor(String? accountId) => _all
      .where((m) =>
          !m.outgoing &&
          !m.seen &&
          (accountId == null || m.accountId == accountId))
      .length;

  List<String> get knownContacts {
    final seen = <String>{};
    for (final c in _group(_all)) {
      seen.add(c.contactEmail);
    }
    return seen.toList();
  }

  void select(String? email) {
    selectedContact = email;
    notifyListeners();
    if (email != null) unawaited(_markRead(email));
  }

  void moveSelection(int delta) {
    final list = conversations;
    if (list.isEmpty) return;
    var idx = list.indexWhereSafe(selectedContact);
    idx = idx < 0 ? 0 : (idx + delta).clamp(0, list.length - 1);
    select(list[idx].contactEmail);
  }

  void setQuery(String v) {
    query = v;
    notifyListeners();
  }

  void setFilter({String? accountId, bool unread = false}) {
    accountFilter = accountId;
    unreadOnly = unread;
    notifyListeners();
  }

  void setListWidth(double w) {
    listWidth = w.clamp(300.0, 520.0);
    notifyListeners();
  }

  Future<void> saveListWidth() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('listWidth', listWidth);
  }

  // ------------------------------------------------------------ koncepty

  String draftFor(String contact) => _drafts[contact] ?? '';

  /// Koncepty prežijú preskladanie/rozloženie telefónu, preto sú tu a nie vo widgete.
  void setDraft(String contact, String text) {
    if (text.isEmpty) {
      _drafts.remove(contact);
    } else {
      _drafts[contact] = text;
    }
  }

  // ------------------------------------------------- označenie prečítané

  Future<void> _markRead(String email) async {
    final unread = _all
        .where((m) => m.contactEmail == email && !m.outgoing && !m.seen)
        .toList();
    if (unread.isEmpty) return;
    final ids = unread.map((m) => m.id).toSet();
    _messages =
        _messages.map((m) => ids.contains(m.id) ? m.copyWith(seen: true) : m).toList();
    _local =
        _local.map((m) => ids.contains(m.id) ? m.copyWith(seen: true) : m).toList();
    notifyListeners();
    try {
      await _db?.setSeen(ids, true);
    } catch (_) {}

    final byAccount = <String, List<int>>{};
    for (final m in unread) {
      if (m.uid != null && m.box == 'I') {
        byAccount.putIfAbsent(m.accountId, () => []).add(m.uid!);
      }
    }
    for (final entry in byAccount.entries) {
      final account = accounts.where((a) => a.id == entry.key);
      if (account.isEmpty) continue;
      try {
        final secret = await _secretFor(account.first);
        await _mail.markSeen(account.first, secret, entry.value);
      } catch (_) {
        // lokálny stav ostáva, server sa zosúladí pri ďalšej synchronizácii
      }
    }
  }

  // ----------------------------------------------------------- odosielanie

  Future<void> reply(Conversation c, String body) async {
    final last = c.last;
    final account = accounts.firstWhere(
      (a) => a.id == last.accountId,
      orElse: () => accounts.first,
    );
    final base = last.subject.trim();
    final subject = base.isEmpty
        ? ''
        : (base.toLowerCase().startsWith('re:') ? base : 'Re: $base');
    await _send(account,
        to: c.contactEmail, name: c.contactName, subject: subject, body: body);
  }

  Future<void> sendNew({
    required Account account,
    required String to,
    required String subject,
    required String body,
  }) async {
    final email = to.trim().toLowerCase();
    await _send(account, to: email, name: email, subject: subject, body: body);
    select(email);
  }

  Future<void> _send(
    Account account, {
    required String to,
    required String name,
    required String subject,
    required String body,
  }) async {
    final secret = await _secretFor(account);
    await _mail.send(account, secret, to: to, subject: subject, body: body);
    _local = [
      ..._local,
      MailMessage(
        id: 'local:${DateTime.now().microsecondsSinceEpoch}',
        accountId: account.id,
        contactEmail: to,
        contactName: name,
        outgoing: true,
        subject: subject,
        date: DateTime.now(),
        text: body,
      ),
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    searchFocus.dispose();
    super.dispose();
  }
}

extension on List<Conversation> {
  int indexWhereSafe(String? email) =>
      email == null ? -1 : indexWhere((c) => c.contactEmail == email);
}
