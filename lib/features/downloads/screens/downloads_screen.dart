import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';
import '../widgets/add_download_dialog.dart';
import '../widgets/download_speed_dial_fab.dart';
import '../widgets/download_task_card.dart';

/// Material 3 Expressive Download Manager screen with 1DM+-style Speed Dial.
/// Adheres strictly to rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DownloadService _service = DownloadService();
  final Map<String, DownloadTask> _tasks = {};
  StreamSubscription<DownloadTask>? _sub;
  bool _isLoading = true;
  bool _isSpeedDialOpen = false;

  @override
  void initState() {
    super.initState();
    _loadInitialTasks();
    _sub = _service.downloadUpdates.listen((task) {
      if (mounted) {
        setState(() {
          _tasks[task.id] = task;
        });
      }
    });
  }

  Future<void> _loadInitialTasks() async {
    final tasks = await _service.getActiveTasks();
    if (mounted) {
      setState(() {
        for (final t in tasks) {
          _tasks[t.id] = t;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleAddLink() {
    setState(() => _isSpeedDialOpen = false);
    AddDownloadDialog.show(context);
  }

  Future<void> _handleFromClipboard() async {
    setState(() => _isSpeedDialOpen = false);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';

    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }

    final isLink = text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.startsWith('magnet:?');

    if (!isLink) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid download link found on clipboard')),
        );
      }
      return;
    }

    if (mounted) {
      unawaited(AddDownloadDialog.show(context, initialUrl: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final taskList = _tasks.values.toList().reversed.toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Downloads',
          style: AppTypography.displaySm.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Pause All',
            icon: Icon(PhosphorIcons.pauseCircle, color: colorScheme.onSurface),
            onPressed: () => _service.pauseAll(),
          ),
          IconButton(
            tooltip: 'Resume All',
            icon: Icon(PhosphorIcons.playCircle, color: colorScheme.primary),
            onPressed: () => _service.resumeAll(),
          ),
          const SizedBox(width: AppSpacing.x1),
        ],
      ),
      body: Stack(
        children: [
          // 1. Download tasks list view or empty state
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : taskList.isEmpty
                  ? _buildEmptyState(colorScheme)
                  : ListView.separated(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.x4,
                        right: AppSpacing.x4,
                        top: AppSpacing.x4,
                        bottom: 88, // Clear space for the bottom FAB
                      ),
                      itemCount: taskList.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x2),
                      itemBuilder: (context, index) {
                        final task = taskList[index];
                        return DownloadTaskCard(
                          task: task,
                          onDelete: () {
                            _service.cancelDownload(task.id);
                            setState(() => _tasks.remove(task.id));
                          },
                        );
                      },
                    ),

          // 2. Full-screen scrim overlay when speed dial is open
          if (_isSpeedDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isSpeedDialOpen = false),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),

          // 3. Speed Dial FAB anchored firmly in bottom-right corner
          Positioned(
            right: 16,
            bottom: 16,
            child: DownloadSpeedDialFab(
              isOpen: _isSpeedDialOpen,
              onToggle: () => setState(() => _isSpeedDialOpen = !_isSpeedDialOpen),
              onAddLink: _handleAddLink,
              onFromClipboard: _handleFromClipboard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.tray, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'No downloads yet',
            style: AppTypography.displaySm.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Tap + to add a link or copy from clipboard',
            style: AppTypography.bodySm.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
