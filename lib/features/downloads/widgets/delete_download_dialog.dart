import 'dart:io';
import 'package:flutter/material.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';

/// Modal dialog confirming download task deletion with optional file purge.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class DeleteDownloadDialog extends StatefulWidget {
  final DownloadTask task;
  final DownloadService service;
  final VoidCallback? onDeleted;

  const DeleteDownloadDialog({
    super.key,
    required this.task,
    required this.service,
    this.onDeleted,
  });

  static Future<bool?> show(
    BuildContext context, {
    required DownloadTask task,
    required DownloadService service,
    VoidCallback? onDeleted,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DeleteDownloadDialog(
        task: task,
        service: service,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<DeleteDownloadDialog> createState() => _DeleteDownloadDialogState();
}

class _DeleteDownloadDialogState extends State<DeleteDownloadDialog> {
  bool _deleteFromStorage = false;

  String _getFileName() {
    final raw = widget.task.destinationPath.isNotEmpty ? widget.task.destinationPath : widget.task.url;
    return raw.split(Platform.pathSeparator).last.split('/').last;
  }

  Future<void> _handleConfirm() async {
    final willPurge = _deleteFromStorage;
    final path = widget.task.destinationPath;

    await widget.service.deleteDownload(widget.task.id, deleteFile: willPurge);

    if (willPurge && path.isNotEmpty) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
        final part = File('$path.part');
        if (part.existsSync()) part.deleteSync();
      } catch (_) {}
    }

    if (!mounted) return;
    widget.onDeleted?.call();
    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(willPurge ? 'Download and file deleted' : 'Download removed from list'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _getFileName();

    return AlertDialog(
      title: const Text('Delete download?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to remove "$fileName" from downloads?'),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _deleteFromStorage = !_deleteFromStorage),
            child: Row(
              children: [
                Checkbox(
                  value: _deleteFromStorage,
                  onChanged: (val) => setState(() => _deleteFromStorage = val ?? false),
                ),
                const Expanded(
                  child: Text('Also delete file from storage', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _handleConfirm,
          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}
