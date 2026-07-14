import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/transfer_task_model.dart';
import '../../data/services/file_transfer_service.dart';
import 'service_providers.dart';

/// Keeps the live list of every transfer task (sends and receives) in
/// sync with [FileTransferService.taskUpdates], seeded from persisted
/// history so completed/failed transfers survive an app restart.
class TransferListNotifier extends StateNotifier<List<TransferTaskModel>> {
  TransferListNotifier(this._ref) : super([]) {
    _loadHistory();
    _ref.read(fileTransferServiceProvider).taskUpdates.listen(_upsert);
  }

  final Ref _ref;
  final Set<String> _notifiedComplete = {};
  static const _terminalStates = {
    TransferState.completed,
    TransferState.failed,
    TransferState.cancelled,
  };

  Future<void> _loadHistory() async {
    final history = await _ref.read(transferHistoryServiceProvider).load();
    state = [...history, ...state];
  }

  void _upsert(TransferTaskModel task) {
    final index = state.indexWhere((t) => t.id == task.id);
    if (index == -1) {
      state = [task, ...state];
    } else {
      final updated = [...state];
      updated[index] = task;
      state = updated;
    }
    if (_terminalStates.contains(task.state)) {
      _ref.read(transferHistoryServiceProvider).record(task);
    }
    if (task.state == TransferState.completed &&
        _notifiedComplete.add(task.id)) {
      _ref.read(notificationServiceProvider).showTransferCompleteNotification(
            fileName: task.fileName,
            incoming: task.direction == TransferDirection.receive,
          );
    }
  }

  void cancel(String transferId) {
    _ref.read(fileTransferServiceProvider).cancelTransfer(transferId);
  }
}

final transferListProvider =
    StateNotifierProvider<TransferListNotifier, List<TransferTaskModel>>(
        (ref) => TransferListNotifier(ref));

final activeTransfersProvider = Provider<List<TransferTaskModel>>((ref) {
  return ref.watch(transferListProvider).where((t) =>
      t.state == TransferState.transferring ||
      t.state == TransferState.connecting ||
      t.state == TransferState.queued).toList();
});

/// Incoming transfer offers awaiting the confirmation dialog required by
/// the security requirements before any bytes are written to disk.
class IncomingTransferNotifier
    extends StateNotifier<List<IncomingTransferRequest>> {
  IncomingTransferNotifier(this._ref) : super([]) {
    _ref.read(fileTransferServiceProvider).incomingRequests.listen((request) {
      state = [...state, request];
    });
  }

  final Ref _ref;

  Future<void> accept(String transferId) async {
    await _ref.read(fileTransferServiceProvider).acceptIncoming(transferId);
    _remove(transferId);
  }

  Future<void> reject(String transferId) async {
    await _ref.read(fileTransferServiceProvider).rejectIncoming(transferId);
    _remove(transferId);
  }

  void _remove(String transferId) {
    state = state.where((r) => r.transferId != transferId).toList();
  }
}

final incomingTransferProvider = StateNotifierProvider<IncomingTransferNotifier,
    List<IncomingTransferRequest>>((ref) => IncomingTransferNotifier(ref));
