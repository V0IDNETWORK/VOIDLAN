import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/transfer_task_model.dart';

class TransferHistoryService {
  TransferHistoryService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  static const _fileName = 'transfer_history.json';
  static const _maxEntries = 500;

  Future<File> _historyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<TransferTaskModel>> load() async {
    try {
      final file = await _historyFile();
      if (!await file.exists()) return [];
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      return raw.map((e) => TransferTaskModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _logger.w('Failed to load transfer history: $e');
      return [];
    }
  }

  /// Prepends [task] to the history (most-recent-first), replacing any
  /// earlier entry with the same id — a transfer that failed and was
  /// then retried under the same id should show its latest outcome,
  /// not a duplicate row.
  Future<void> record(TransferTaskModel task) async {
    try {
      final file = await _historyFile();
      final existing = await load();
      final withoutDuplicate = existing.where((t) => t.id != task.id).toList();
      final updated = [task, ...withoutDuplicate].take(_maxEntries).toList();
      await file.writeAsString(jsonEncode(updated.map((t) => t.toJson()).toList()));
    } catch (e) {
      _logger.w('Failed to persist transfer history entry: $e');
    }
  }

  Future<void> clear() async {
    try {
      final file = await _historyFile();
      if (await file.exists()) await file.delete();
    } catch (e) {
      _logger.w('Failed to clear transfer history: $e');
    }
  }
}
