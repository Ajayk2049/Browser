import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';
import '../widgets/delete_download_dialog.dart';
import '../widgets/download_detail_components.dart';

/// Screen displaying detailed metadata and real-time progress for a direct (HTTP/HTTPS) download.
/// Adheres to rules.md §13, §29.2 (< 300 lines).
class DirectDownloadDetailsScreen extends StatefulWidget {
  final DownloadTask initialTask;

  const DirectDownloadDetailsScreen({super.key, required this.initialTask});

  @override
  State<DirectDownloadDetailsScreen> createState() => _DirectDownloadDetailsScreenState();
}

class _DirectDownloadDetailsScreenState extends State<DirectDownloadDetailsScreen> {
  late DownloadTask _task;
  final DownloadService _service = DownloadService();

  @override
  void initState() {
    super.initState();
    _task = widget.initialTask;
    _service.downloadUpdates.listen((updated) {
      if (mounted && updated.id == _task.id) setState(() => _task = updated);
    });
  }

  IconData _getFileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.iso') || lower.endsWith('.img') || lower.endsWith('.dmg')) return PhosphorIcons.disc;
    if (lower.endsWith('.flac') || lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.m4a')) return PhosphorIcons.musicNote;
    if (lower.endsWith('.pdf') || lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) return PhosphorIcons.fileText;
    if (lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.avi') || lower.endsWith('.mov')) return PhosphorIcons.filmStrip;
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || lower.endsWith('.tar')) return PhosphorIcons.archive;
    return PhosphorIcons.file;
  }

  String _fileName() {
    final raw = _task.destinationPath.isNotEmpty ? _task.destinationPath : _task.url;
    return raw.split('/').lastOrNull ?? 'download_${_task.id}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _deleteTask() async {
    DeleteDownloadDialog.show(
      context,
      task: _task,
      service: _service,
      onDeleted: () {
        if (mounted) Navigator.of(context).maybePop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF131722) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0F5);
    final fgColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final isDownloading = _task.status == DownloadStatus.downloading || _task.status == DownloadStatus.connecting;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 60.0,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                DownloadDetailComponents.buildCircleButton(PhosphorIcons.caretLeft, fgColor, isDark, () => Navigator.of(context).maybePop()),
                Expanded(child: Center(child: Text('Direct Download', style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600, color: fgColor)))),
                DownloadDetailComponents.buildCircleButton(PhosphorIcons.dotsThreeVertical, fgColor, isDark, () {}),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 100.0),
        children: [
          _buildHeroCard(cardBg, borderColor, fgColor, subColor, isDark),
          const SizedBox(height: 20.0),
          DownloadDetailComponents.buildSectionLabel('FILE', subColor),
          const SizedBox(height: 8.0),
          _buildFileDetailsCard(cardBg, borderColor, fgColor, subColor),
          const SizedBox(height: 20.0),
          DownloadDetailComponents.buildSectionLabel('SOURCE', subColor),
          const SizedBox(height: 8.0),
          _buildSourceCard(cardBg, borderColor, fgColor, subColor),
        ],
      ),
      bottomSheet: DownloadDetailComponents.buildBottomActionBar(
        context: context,
        scaffoldBg: scaffoldBg,
        borderColor: borderColor,
        fgColor: fgColor,
        isDark: isDark,
        isDownloading: isDownloading,
        isCompleted: _task.status == DownloadStatus.completed,
        onTogglePlayPause: () {
          if (_task.status == DownloadStatus.completed) {
            _service.resumeDownload(_task.id);
          } else if (isDownloading) {
            _service.pauseDownload(_task.id);
          } else {
            _service.resumeDownload(_task.id);
          }
        },
        onShare: () => const MethodChannel('com.dab/downloader').invokeMethod('shareUrl', {'url': _task.url, 'title': _fileName()}),
        onDelete: _deleteTask,
      ),
    );
  }

  Widget _buildHeroCard(Color cardBg, Color borderColor, Color fgColor, Color subColor, bool isDark) {
    final isDone = _task.status == DownloadStatus.completed;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16.0), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2533) : const Color(0xFFF1F5F9), shape: BoxShape.circle),
                child: Icon(_getFileIcon(_fileName()), size: 22, color: fgColor),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fileName(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: fgColor)),
                    const SizedBox(height: 3.0),
                    Text('HTTPS • ${_task.fileSizeFormatted}', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: subColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_task.progressPercentage, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: fgColor)),
              Text(isDone ? 'Completed' : '${_task.etaFormatted} left • ${_task.speedFormatted}', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: subColor)),
            ],
          ),
          const SizedBox(height: 8.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: LinearProgressIndicator(
              value: _task.progress.clamp(0.0, 1.0),
              minHeight: 6.0,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              DownloadDetailComponents.buildStatBox('SPEED', isDone ? '0 B/s' : _task.speedFormatted, fgColor, subColor, isDark),
              const SizedBox(width: 8.0),
              DownloadDetailComponents.buildStatBox('THREADS', '${_task.segmentsCount}', fgColor, subColor, isDark),
              const SizedBox(width: 8.0),
              DownloadDetailComponents.buildStatBox('ETA', isDone ? 'Done' : _task.etaFormatted, fgColor, subColor, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileDetailsCard(Color cardBg, Color borderColor, Color fgColor, Color subColor) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16.0), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          DownloadDetailComponents.buildDetailRow('Downloaded', '${_task.downloadedSizeFormatted} of ${_task.fileSizeFormatted}', fgColor, subColor),
          DownloadDetailComponents.buildDivider(borderColor),
          DownloadDetailComponents.buildDetailRow('Saved to', _task.destinationPath.isNotEmpty ? _task.destinationPath : '/storage/emulated/0/Download', fgColor, subColor, isPath: true),
          DownloadDetailComponents.buildDivider(borderColor),
          DownloadDetailComponents.buildDetailRow('Added', _task.dateLabel ?? 'Today', fgColor, subColor),
          DownloadDetailComponents.buildDivider(borderColor),
          DownloadDetailComponents.buildDetailRow('Resume support', 'Yes', fgColor, subColor),
        ],
      ),
    );
  }

  Widget _buildSourceCard(Color cardBg, Color borderColor, Color fgColor, Color subColor) {
    final host = Uri.tryParse(_task.url)?.host ?? 'Direct Download Server';
    final mime = _fileName().endsWith('.iso') ? 'application/x-iso9660-image' : 'application/octet-stream';
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16.0), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('URL', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: subColor)),
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    Expanded(child: Text(_task.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: fgColor))),
                    IconButton(
                      visualDensity: VisualDensity.compact, padding: EdgeInsets.zero,
                      icon: Icon(PhosphorIcons.copy, size: 18, color: subColor),
                      onPressed: () => _copyToClipboard(_task.url, 'URL'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          DownloadDetailComponents.buildDivider(borderColor),
          DownloadDetailComponents.buildDetailRow('Server', host, fgColor, subColor),
          DownloadDetailComponents.buildDivider(borderColor),
          DownloadDetailComponents.buildDetailRow('File type', mime, fgColor, subColor),
        ],
      ),
    );
  }
}
