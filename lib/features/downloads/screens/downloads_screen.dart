import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../../browser/widgets/browser_bottom_bar.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';
import '../utils/url_metadata_helper.dart';
import '../widgets/add_download_dialog.dart';
import '../widgets/download_speed_dial_fab.dart';
import '../widgets/download_storage_card.dart';
import '../widgets/download_task_card.dart';

enum DownloadFilter { all, media, documents, archives }

/// Revamped B&W 1DM+ download manager displaying only real user downloads.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
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
  DownloadFilter _selectedFilter = DownloadFilter.all;

  @override
  void initState() {
    super.initState();
    _loadInitialTasks();
    _sub = _service.downloadUpdates.listen(_onTaskUpdate);
  }

  void _onTaskUpdate(DownloadTask task) {
    if (!mounted) return;
    setState(() => _tasks[task.id] = task);
    _ensureTaskMetadata(task);
  }

  void _ensureTaskMetadata(DownloadTask task) {
    final name = (task.destinationPath.isNotEmpty ? task.destinationPath : task.url).split('/').last;
    final needsName = name.startsWith('download_') || name.startsWith('Resolving') || !name.contains('.');
    final needsSize = task.totalBytes <= 0;
    if (!needsName && !needsSize) return;

    UrlMetadataHelper.resolve(task.url).then((meta) {
      if (!mounted) return;
      final current = _tasks[task.id];
      if (current != null) {
        final curName = (current.destinationPath.isNotEmpty ? current.destinationPath : current.url).split('/').last;
        final shouldName = curName.startsWith('download_') || curName.startsWith('Resolving') || !curName.contains('.');
        final shouldSize = current.totalBytes <= 0 && meta.totalBytes > 0;
        if (shouldName || shouldSize) {
          setState(() {
            _tasks[task.id] = current.copyWith(
              totalBytes: shouldSize ? meta.totalBytes : current.totalBytes,
              destinationPath: shouldName ? meta.fileName : current.destinationPath,
            );
          });
        }
      }
    });
  }

  Future<void> _loadInitialTasks() async {
    final nativeTasks = await _service.getActiveTasks();
    if (mounted) {
      setState(() {
        for (final t in nativeTasks) {
          _tasks[t.id] = t;
          _ensureTaskMetadata(t);
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
    final isValid = text.startsWith('http://') || text.startsWith('https://') || text.startsWith('magnet:?');
    if (text.isEmpty || !isValid) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid download link on clipboard')));
      return;
    }
    if (mounted) unawaited(AddDownloadDialog.show(context, initialUrl: text));
  }

  List<DownloadTask> _getFilteredTasks() {
    final list = _tasks.values.toList();
    switch (_selectedFilter) {
      case DownloadFilter.all: return list;
      case DownloadFilter.media:
        return list.where((t) {
          final l = (t.destinationPath.isNotEmpty ? t.destinationPath : t.url).toLowerCase();
          return l.endsWith('.mp3') || l.endsWith('.flac') || l.endsWith('.wav') || l.endsWith('.mp4') || l.endsWith('.mkv');
        }).toList();
      case DownloadFilter.documents:
        return list.where((t) {
          final l = (t.destinationPath.isNotEmpty ? t.destinationPath : t.url).toLowerCase();
          return l.endsWith('.pdf') || l.endsWith('.doc') || l.endsWith('.docx') || l.endsWith('.txt');
        }).toList();
      case DownloadFilter.archives:
        return list.where((t) {
          final l = (t.destinationPath.isNotEmpty ? t.destinationPath : t.url).toLowerCase();
          return l.endsWith('.iso') || l.endsWith('.zip') || l.endsWith('.rar') || l.endsWith('.tar');
        }).toList();
    }
  }

  Widget _buildCircleButton(IconData icon, Color fg, bool isDark, VoidCallback onTap) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF131722) : Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0F5)),
    ),
    child: IconButton(padding: EdgeInsets.zero, icon: Icon(icon, size: 20, color: fg), onPressed: onTap),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0E14) : const Color(0xFFF8FAFC);
    final fgColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final filteredTasks = _getFilteredTasks();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: Center(child: _buildCircleButton(PhosphorIcons.caretLeft, fgColor, isDark, () => context.canPop() ? context.pop() : context.go('/'))),
        title: Text('Downloads', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, fontSize: 18, color: fgColor)),
        actions: [Center(child: Padding(padding: const EdgeInsets.only(right: AppSpacing.x4), child: _buildCircleButton(PhosphorIcons.dotsThreeVertical, fgColor, isDark, () {})))],
      ),
      bottomNavigationBar: BrowserBottomBar(
        onForward: () => context.canPop() ? context.pop() : null,
        onShare: () {},
        onHome: () => context.go('/'),
        onOpenTabs: () => context.go('/'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x3, AppSpacing.x4, 96),
            children: [
              const DownloadStorageCard(),
              const SizedBox(height: AppSpacing.x4),
              _buildFilterChips(isDark),
              const SizedBox(height: AppSpacing.x4),
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (filteredTasks.isEmpty)
                _buildEmptyState(isDark)
              else ...[
                for (final task in filteredTasks) ...[
                  DownloadTaskCard(
                    task: task,
                    onDelete: () {
                      _service.cancelDownload(task.id);
                      setState(() => _tasks.remove(task.id));
                    },
                  ),
                  const SizedBox(height: AppSpacing.x3),
                ],
              ],
            ],
          ),
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

  Widget _buildEmptyState(bool isDark) {
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.tray, size: 56, color: subColor.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.x3),
            Text(
              'No downloads yet',
              style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Tap + to add a link or copy from clipboard',
              style: AppTypography.bodySm.copyWith(color: subColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final count = _tasks.length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(DownloadFilter.all, 'All ($count)', isDark),
          const SizedBox(width: AppSpacing.x2),
          _buildChip(DownloadFilter.media, 'Media', isDark),
          const SizedBox(width: AppSpacing.x2),
          _buildChip(DownloadFilter.documents, 'Documents', isDark),
          const SizedBox(width: AppSpacing.x2),
          _buildChip(DownloadFilter.archives, 'Archives', isDark),
        ],
      ),
    );
  }

  Widget _buildChip(DownloadFilter filter, String label, bool isDark) {
    final isSelected = _selectedFilter == filter;
    final activeBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final activeFg = isDark ? const Color(0xFF0B0E14) : Colors.white;
    final inactiveBg = isDark ? const Color(0xFF131722) : Colors.white;
    final inactiveFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0F5);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: () => setState(() => _selectedFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: isSelected ? activeBg : borderColor, width: 1),
        ),
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeFg : inactiveFg,
          ),
        ),
      ),
    );
  }
}
