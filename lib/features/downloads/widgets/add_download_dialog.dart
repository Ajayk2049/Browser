import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../services/download_service.dart';
import '../utils/url_metadata_helper.dart';

/// Material 3 monochrome Download dialog matching 1DM+ layout with auto-resolution.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class AddDownloadDialog extends StatefulWidget {
  final String? initialUrl;
  const AddDownloadDialog({super.key, this.initialUrl});

  static Future<bool?> show(BuildContext context, {String? initialUrl}) =>
      showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => AddDownloadDialog(initialUrl: initialUrl));

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _nameCtrl;
  Timer? _debounceTimer;
  String _ext = 'bin';
  String _sizeText = 'Resolving file info...';
  int _resolvedTotalBytes = -1;
  bool _supportsResume = true;
  String _storageText = 'Calculating storage...';
  String _storagePath = '';

  @override
  void initState() {
    super.initState();
    final url = widget.initialUrl ?? '';
    _urlCtrl = TextEditingController(text: url);
    final uri = Uri.tryParse(url);
    _refCtrl = TextEditingController(text: uri?.host.isNotEmpty == true ? '${uri!.scheme}://${uri.host}' : '');
    final isMag = url.toLowerCase().startsWith('magnet:');
    String cand = '';
    try { if (url.isNotEmpty) cand = UrlMetadataHelper.extractCandidateName(url); } catch (_) {}
    _nameCtrl = TextEditingController(text: cand);
    try {
      _ext = cand.isNotEmpty ? (isMag && !cand.contains('.') ? 'torrent' : UrlMetadataHelper.extractExtension(cand)) : (isMag ? 'torrent' : 'bin');
    } catch (_) { _ext = isMag ? 'torrent' : 'bin'; }
    if (url.isNotEmpty) _sizeText = isMag ? 'Connecting to trackers to resolve size...' : 'Resolving file info...';
    _urlCtrl.addListener(_onUrlChanged);
    _initStorage();
    if (url.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _probe(url); });
    }
  }

  void _onUrlChanged() {
    final url = _urlCtrl.text.trim();
    final lower = url.toLowerCase();
    if (url.isEmpty || !(lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('magnet:'))) return;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty && _refCtrl.text.isEmpty) _refCtrl.text = '${uri.scheme}://${uri.host}';
    final cand = UrlMetadataHelper.extractCandidateName(url);
    setState(() {
      if (_nameCtrl.text.isEmpty || _nameCtrl.text.startsWith('download_') || _nameCtrl.text == 'Resolving title...') _nameCtrl.text = cand;
      final isMag = lower.startsWith('magnet:');
      final cName = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : cand;
      _ext = isMag && !cName.contains('.') ? 'torrent' : UrlMetadataHelper.extractExtension(cName);
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () { if (mounted) _probe(url); });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _urlCtrl.dispose(); _refCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _initStorage() async {
    try {
      await DownloadService().requestStoragePermission();
      final publicDir = await DownloadService().getPublicDownloadDirectory();
      final targetPath = publicDir ?? (await getApplicationDocumentsDirectory()).path;
      _storagePath = targetPath;
      final space = await DownloadService().getDiskSpace(targetPath);
      final a = space['available'] ?? 0, t = space['total'] ?? 0;
      if (mounted) {
        setState(() => _storageText = t > 0
            ? 'Storage: ${(a / 1e9).toStringAsFixed(2)}GB/${(t / 1e9).toStringAsFixed(2)}GB, ${((a / t) * 100).toStringAsFixed(1)}% free'
            : 'Storage: Ready');
      }
    } catch (_) { if (mounted) setState(() => _storageText = 'Storage: Ready'); }
  }

  Future<void> _probe(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final isMag = trimmed.toLowerCase().startsWith('magnet:');
    if (mounted) setState(() => _sizeText = isMag ? 'Connecting to trackers to resolve size...' : 'Resolving file info...');
    if (isMag) await Future<void>.delayed(const Duration(milliseconds: 600));
    try {
      final meta = await UrlMetadataHelper.resolve(trimmed, referer: _refCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _resolvedTotalBytes = meta.totalBytes;
        _nameCtrl.text = meta.fileName;
        _ext = meta.fileExtension;
        _supportsResume = meta.supportsResume;
        _sizeText = meta.formattedSize;
        if (meta.finalUrl.isNotEmpty && meta.finalUrl != url && meta.finalUrl.startsWith('http')) {
          _refCtrl.text = url;
          _urlCtrl.text = meta.finalUrl;
        }
      });
    } catch (_) { if (mounted) setState(() => _sizeText = 'Unknown size'); }
  }

  Future<void> _submit({required bool startNow}) async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) return;
    var fileName = _nameCtrl.text.trim();
    if (fileName.isEmpty || fileName.startsWith('download_')) fileName = UrlMetadataHelper.extractCandidateName(rawUrl);
    final dest = '$_storagePath${Platform.pathSeparator}$fileName';
    final ref = _refCtrl.text.trim();
    final ok = await DownloadService().startDownload(
      taskId: '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}',
      url: rawUrl, destinationPath: dest, segmentsCount: 4, startNow: startNow,
      referer: ref.isNotEmpty ? ref : null,
      totalBytes: _resolvedTotalBytes > 0 ? _resolvedTotalBytes : null,
    );
    if (mounted) {
      Navigator.pop(context, ok);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(startNow ? 'Starting: $fileName' : 'Added to list: $fileName'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Widget _buildField(String label, Widget child, ColorScheme cs, [List<Widget>? actions]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [Expanded(child: Text(label, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))), ...?actions]),
      const SizedBox(height: 3),
      child,
    ],
  );

  InputDecoration _inputDeco(ColorScheme cs) => InputDecoration(
    isDense: true, filled: true, fillColor: cs.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.card), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.card), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.card), borderSide: BorderSide(color: cs.primary, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final borderCol = isDark ? const Color(0xFF272E3F) : const Color(0xFFE2E8F0);
    final extBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card), side: BorderSide(color: borderCol)),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Download file', style: AppTypography.displaySm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: AppSpacing.x3),
              _buildField('Link (Resume: ${_supportsResume ? "Yes" : "No"})',
                TextField(controller: _urlCtrl, style: AppTypography.bodyMd.copyWith(color: cs.onSurface), onSubmitted: _probe, decoration: _inputDeco(cs)), cs,
                [
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _urlCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied URL to clipboard'), duration: Duration(seconds: 2)));
                    },
                    child: Icon(PhosphorIcons.copy, size: 16, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Icon(PhosphorIcons.caretDown, size: 14, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              _buildField('Download/Referer page link', TextField(controller: _refCtrl, style: AppTypography.bodyMd.copyWith(color: cs.onSurface), decoration: _inputDeco(cs)), cs),
              const SizedBox(height: AppSpacing.x2),
              _buildField('Save as:', Row(children: [
                Expanded(child: TextField(controller: _nameCtrl, maxLines: 2, minLines: 1, style: AppTypography.bodyMd.copyWith(color: cs.onSurface), decoration: _inputDeco(cs))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: extBg, borderRadius: BorderRadius.circular(AppRadius.input), border: Border.all(color: borderCol)),
                  child: Text(_ext.toUpperCase(), style: AppTypography.bodySm.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
                ),
              ]), cs),
              const SizedBox(height: AppSpacing.x2),
              Text(_sizeText, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(_storageText, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.x1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.card)),
                child: Row(children: [
                  Icon(PhosphorIcons.clockCounterClockwise, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_storagePath, style: AppTypography.bodySm.copyWith(color: cs.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Icon(PhosphorIcons.folderSimple, size: 18, color: cs.onSurfaceVariant),
                ]),
              ),
              const SizedBox(height: AppSpacing.x3),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 4),
                  TextButton(onPressed: () => _submit(startNow: false), child: Text('ADD', style: AppTypography.bodyMd.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => _submit(startNow: true),
                    style: FilledButton.styleFrom(backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A), foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white),
                    child: Text('START', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
