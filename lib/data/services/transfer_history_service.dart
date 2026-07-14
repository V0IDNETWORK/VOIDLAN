import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

import '../models/transfer_task_model.dart';
import 'database_service.dart';

/// Persists completed/failed/cancelled transfers to the shared SQLite
/// database (see [DatabaseService]) so transfer history survives an
/// app restart, replacing the previous single-JSON-file design.
class TransferHistoryService {
  TransferHistoryService(this._db, {Logger? logger}) : _logger = logger ?? Logger();

  final DatabaseService _db;
  final Logger _logger;
  static const _maxEntries = 500;

  Future<List<TransferTaskModel>> load() async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'transfers',
        orderBy: 'started_at DESC',
        limit: _maxEntries,
      );
      return rows.map(_fromRow).toList();
    } catch (e) {
      _logger.w('Failed to load transfer history: $e');
      return [];
    }
  }

  /// Upserts [task] into the transfers table — a transfer that failed
  /// and was retried under the same id updates its existing row rather
  /// than duplicating it.
  Future<void> record(TransferTaskModel task) async {
    try {
      final db = await _db.database;
      await db.insert('transfers', {
        'id': task.id,
        'file_name': task.fileName,
        'total_bytes': task.totalBytes,
        'direction': task.direction.name,
        'peer_ip': task.peerIp,
        'peer_name': task.peerName,
        'local_path': task.localPath,
        'transferred_bytes': task.transferredBytes,
        'state': task.state.name,
        'started_at': task.startedAt?.toIso8601String(),
        'error_message': task.errorMessage,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      _logger.w('Failed to persist transfer history entry: $e');
    }
  }

  Future<void> clear() async {
    try {
      final db = await _db.database;
      await db.delete('transfers');
    } catch (e) {
      _logger.w('Failed to clear transfer history: $e');
    }
  }

  TransferTaskModel _fromRow(Map<String, Object?> row) {
    return TransferTaskModel(
      id: row['id'] as String,
      fileName: row['file_name'] as String,
      totalBytes: row['total_bytes'] as int,
      direction: TransferDirection.values.firstWhere((d) => d.name == row['direction']),
      peerIp: row['peer_ip'] as String,
      peerName: row['peer_name'] as String,
      localPath: row['local_path'] as String?,
      transferredBytes: row['transferred_bytes'] as int? ?? 0,
      state: TransferState.values.firstWhere((s) => s.name == row['state'],
          orElse: () => TransferState.failed),
      startedAt:
          row['started_at'] != null ? DateTime.parse(row['started_at'] as String) : null,
      errorMessage: row['error_message'] as String?,
    );
  }
}
