import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';

class SyncState {
  const SyncState(this.lastUid, this.validity);

  final int lastUid;
  final int? validity;
}

/// Lokálna SQLite cache správ (offline režim, rýchly štart, inkrementálna synchronizácia).
class LocalDb {
  LocalDb._(this._db);

  final Database _db;

  static Future<LocalDb> open() async {
    final path = p.join(await getDatabasesPath(), 'konverzo_mail.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            box TEXT NOT NULL,
            uid INTEGER,
            contact_email TEXT NOT NULL,
            contact_name TEXT NOT NULL,
            outgoing INTEGER NOT NULL,
            subject TEXT NOT NULL,
            date INTEGER NOT NULL,
            body TEXT NOT NULL,
            html TEXT,
            seen INTEGER NOT NULL,
            attachments TEXT NOT NULL DEFAULT ''
          )''');
        await db.execute(
            'CREATE INDEX idx_msg_contact ON messages(contact_email)');
        await db.execute(
            'CREATE INDEX idx_msg_account ON messages(account_id, box, uid)');
        await db.execute('''
          CREATE TABLE sync_state(
            account_id TEXT NOT NULL,
            box TEXT NOT NULL,
            last_uid INTEGER NOT NULL,
            uid_validity INTEGER,
            PRIMARY KEY(account_id, box)
          )''');
      },
    );
    return LocalDb._(db);
  }

  Map<String, Object?> _toRow(MailMessage m) => {
        'id': m.id,
        'account_id': m.accountId,
        'box': m.box,
        'uid': m.uid,
        'contact_email': m.contactEmail,
        'contact_name': m.contactName,
        'outgoing': m.outgoing ? 1 : 0,
        'subject': m.subject,
        'date': m.date.millisecondsSinceEpoch,
        'body': m.text,
        'html': m.html,
        'seen': m.seen ? 1 : 0,
        'attachments': m.attachments.join('\n'),
      };

  MailMessage _fromRow(Map<String, Object?> r) => MailMessage(
        id: r['id'] as String,
        accountId: r['account_id'] as String,
        box: r['box'] as String,
        uid: r['uid'] as int?,
        contactEmail: r['contact_email'] as String,
        contactName: r['contact_name'] as String,
        outgoing: (r['outgoing'] as int) == 1,
        subject: r['subject'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(r['date'] as int),
        text: r['body'] as String,
        html: r['html'] as String?,
        seen: (r['seen'] as int) == 1,
        attachments: (r['attachments'] as String).isEmpty
            ? const []
            : (r['attachments'] as String).split('\n'),
      );

  Future<List<MailMessage>> loadAll() async {
    final rows = await _db.query('messages', orderBy: 'date ASC');
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(List<MailMessage> messages) async {
    if (messages.isEmpty) return;
    final batch = _db.batch();
    for (final m in messages) {
      batch.insert('messages', _toRow(m),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setSeen(Iterable<String> ids, bool seen) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update('messages', {'seen': seen ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Aktualizuje príznak „prečítané“ podľa UID zo servera.
  Future<void> applySeen(String accountId, String box, Map<int, bool> flags) async {
    final batch = _db.batch();
    flags.forEach((uid, seen) {
      batch.update('messages', {'seen': seen ? 1 : 0},
          where: 'account_id = ? AND box = ? AND uid = ?',
          whereArgs: [accountId, box, uid]);
    });
    await batch.commit(noResult: true);
  }

  Future<void> deleteAccount(String accountId) async {
    await _db.delete('messages', where: 'account_id = ?', whereArgs: [accountId]);
    await _db
        .delete('sync_state', where: 'account_id = ?', whereArgs: [accountId]);
  }

  Future<void> clearBox(String accountId, String box) async {
    await _db.delete('messages',
        where: 'account_id = ? AND box = ?', whereArgs: [accountId, box]);
  }

  Future<Map<String, SyncState>> syncStates(String accountId) async {
    final rows = await _db
        .query('sync_state', where: 'account_id = ?', whereArgs: [accountId]);
    return {
      for (final r in rows)
        r['box'] as String:
            SyncState(r['last_uid'] as int, r['uid_validity'] as int?),
    };
  }

  Future<void> setSync(
      String accountId, String box, int lastUid, int? validity) async {
    await _db.insert(
      'sync_state',
      {
        'account_id': accountId,
        'box': box,
        'last_uid': lastUid,
        'uid_validity': validity,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
