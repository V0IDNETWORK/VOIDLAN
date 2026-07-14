import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Owns the single SQLite database file backing every persisted table
/// in the app (messages, conversations, transfer history). Replaces
/// the earlier per-feature JSON-file persistence with one real
/// embedded database — proper indexing, no full-file rewrite on every
/// write, and a single schema to reason about.
///
/// `sqflite` only ships a native implementation for Android/iOS; on
/// Windows/Linux this uses `sqflite_common_ffi`, which loads the
/// platform's own `sqlite3` shared library through FFI. Both expose
/// the identical `Database` API, so every other service in this app
/// talks to `Database` and never needs to know which backend is active.
class DatabaseService {
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'void_lan.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            peer_id TEXT NOT NULL,
            peer_name TEXT NOT NULL,
            peer_ip TEXT NOT NULL,
            unread_count INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            is_outgoing INTEGER NOT NULL,
            type TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            text TEXT,
            file_path TEXT,
            file_name TEXT,
            file_size_bytes INTEGER,
            status TEXT NOT NULL,
            reply_to_id TEXT,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_messages_conversation ON messages(conversation_id)');

        await db.execute('''
          CREATE TABLE transfers (
            id TEXT PRIMARY KEY,
            file_name TEXT NOT NULL,
            total_bytes INTEGER NOT NULL,
            direction TEXT NOT NULL,
            peer_ip TEXT NOT NULL,
            peer_name TEXT NOT NULL,
            local_path TEXT,
            transferred_bytes INTEGER NOT NULL DEFAULT 0,
            state TEXT NOT NULL,
            started_at TEXT,
            error_message TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_transfers_state ON transfers(state)');
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
