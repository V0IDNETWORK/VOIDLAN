import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/transfer_task_model.dart';
import '../providers/transfer_providers.dart';
import '../shared/glass_app_bar.dart';

class TransferHistoryScreen extends ConsumerStatefulWidget {
  const TransferHistoryScreen({super.key});

  @override
  ConsumerState<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends ConsumerState<TransferHistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(transferListProvider);
    final filtered = _query.isEmpty
        ? tasks
        : tasks.where((t) => t.fileName.toLowerCase().contains(_query.toLowerCase())).toList();

    final active = filtered
        .where((t) => [TransferState.transferring, TransferState.connecting, TransferState.queued, TransferState.paused]
            .contains(t.state))
        .toList();
    final completed = filtered.where((t) => t.state == TransferState.completed).toList();
    final failed =
        filtered.where((t) => [TransferState.failed, TransferState.cancelled].contains(t.state)).toList();

    return Scaffold(
      appBar: GlassAppBar(title: const Text('Transfers')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(hintText: 'Search transfers…', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('No transfers yet')),
            ),
          if (active.isNotEmpty) _Section(title: 'Current', tasks: active),
          if (completed.isNotEmpty) _Section(title: 'Completed', tasks: completed),
          if (failed.isNotEmpty) _Section(title: 'Failed / cancelled', tasks: failed, showRetryHint: true),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tasks, this.showRetryHint = false});

  final String title;
  final List<TransferTaskModel> tasks;
  final bool showRetryHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final task in tasks) _TransferHistoryTile(task: task, showRetryHint: showRetryHint),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TransferHistoryTile extends ConsumerWidget {
  const _TransferHistoryTile({required this.task, required this.showRetryHint});

  final TransferTaskModel task;
  final bool showRetryHint;

  IconData get _statusIcon {
    switch (task.state) {
      case TransferState.completed:
        return Icons.check_circle_outline;
      case TransferState.failed:
        return Icons.error_outline;
      case TransferState.cancelled:
        return Icons.cancel_outlined;
      case TransferState.paused:
        return Icons.pause_circle_outline;
      default:
        return Icons.sync;
    }
  }

  Future<void> _openLocation(BuildContext context) async {
    final path = task.localPath;
    if (path == null) return;
    if (Platform.isAndroid) {
      await Share.shareXFiles([XFile(path)]);
      return;
    }
    final dir = File(path).parent.path;
    final uri = Uri.directory(dir);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_statusIcon,
            color: task.state == TransferState.failed ? theme.colorScheme.error : null),
        title: Text(task.fileName, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${task.direction == TransferDirection.send ? 'Sent to' : 'Received from'} '
          '${task.peerName} · ${_formatBytes(task.totalBytes)}'
          '${task.errorMessage != null ? ' · ${task.errorMessage}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: task.state == TransferState.completed && task.localPath != null
            ? IconButton(
                tooltip: Platform.isAndroid ? 'Share' : 'Open containing folder',
                icon: Icon(Platform.isAndroid ? Icons.share_outlined : Icons.folder_open_outlined),
                onPressed: () => _openLocation(context),
              )
            : (task.state == TransferState.transferring || task.state == TransferState.connecting)
                ? IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close),
                    onPressed: () => ref.read(transferListProvider.notifier).cancel(task.id),
                  )
                : null,
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
