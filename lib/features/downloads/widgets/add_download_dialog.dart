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
  final String? audioUrl;
  final String? suggestedFileName;
  final int? totalBytes;
  const AddDownloadDialog({super.key, this.initialUrl, this.audioUrl, this.suggestedFileName, this.totalBytes});

  static Future<bool?> show(BuildContext context, {String? initialUrl, String? audioUrl, String? suggestedFileName, int? totalBytes}) =>
      showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => AddDownloadDialog(initialUrl: initialUrl, audioUrl: audioUrl, suggestedFileName: suggestedFileName, totalBytes: totalBytes));

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  late final TextEditingController _urlCtrl, _refCtrl, _nameCtrl;
  Timer? _debounceTimer;
  String _ext = 'bin', _sizeText = 'Resolving file info...', _storageText = 'Calculating storage...', _storagePath = '';
  int _resolvedTotalBytes = -1;
  bool _supportsResume = true;

  @override
  void initState() {
    super.initState();
    final url = widget.initialUrl ?? '';
    _urlCtrl = TextEditingController(text: url);
    final uri = Uri.tryParse(url);
    final isGv = uri?.host.contains('googlevideo.com') == true;
    _refCtrl = TextEditingController(text: isGv ? 'https://www.youtube.com/' : (uri?.host.isNotEmpty == true ? '${uri!.scheme}://${uri.host}' : ''));
    final isMag = url.toLowerCase().startsWith('magnet:');
    String cand = widget.suggestedFileName ?? '';
    if (cand.isNotEmpty && cand.contains('.')) {
      _ext = cand.substring(cand.lastIndexOf('.') + 1);
      cand = cand.substring(0, cand.lastIndexOf('.'));
    } else if (cand.isEmpty && url.isNotEmpty) {
      try { cand = UrlMetadataHelper.extractCandidateName(url); } catch (_) {}
      _ext = isMag ? 'torrent' : 'bin';
    }
    _nameCtrl = TextEditingController(text: cand);
    if (widget.totalBytes != null && widget.totalBytes! > 0) {
      _resolvedTotalBytes = widget.totalBytes!;
      _sizeText = '${(_resolvedTotalBytes / 1048576).toStringAsFixed(2)} MB ($_resolvedTotalBytes bytes)';
    } else if (url.isNotEmpty) {
      _sizeText = isMag ? 'Connecting to trackers to resolve size...' : 'Resolving file info...';
    }
    _urlCtrl.addListener(_onUrlChanged);
    _initStorage();
    if (url.isNotEmpty && widget.totalBytes == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _probe(url); });
    }
  }

  void _onUrlChanged() {
    final url = _urlCtrl.text.trim();
    final lower = url.toLowerCase();
    if (url.isEmpty || !(lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('magnet:'))) return;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty && _refCtrl.text.isEmpty) _refCtrl.text = uri.host.contains('googlevideo.com') ? 'https://www.youtube.com/' : '${uri.scheme}://${uri.host}';
    final cand = UrlMetadataHelper.extractCandidateName(url);
    setState(() {
      if (_nameCtrl.text.isEmpty || _nameCtrl.text.startsWith('download_') || _nameCtrl.text == 'Resolving title...') _nameCtrl.text = cand;
      _ext = lower.startsWith('magnet:') && !_nameCtrl.text.contains('.') ? 'torrent' : UrlMetadataHelper.extractExtension(_nameCtrl.text.isNotEmpty ? _nameCtrl.text : cand);
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
      _storagePath = publicDir ?? (await getApplicationDocumentsDirectory()).path;
      final space = await DownloadService().getDiskSpace(_storagePath);
      final a = space['available'] ?? 0, t = space['total'] ?? 0;
      if (mounted) setState(() => _storageText = t > 0 ? 'Storage: ${(a / 1e9).toStringAsFixed(2)}GB/${(t / 1e9).toStringAsFixed(2)}GB, ${((a / t) * 100).toStringAsFixed(1)}% free' : 'Storage: Ready');
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
        if (_resolvedTotalBytes <= 0 && meta.totalBytes > 0) {
          _resolvedTotalBytes = meta.totalBytes;
          _sizeText = meta.formattedSize;
        }
        if (widget.suggestedFileName == null || widget.suggestedFileName!.isEmpty) {
          _nameCtrl.text = meta.fileName;
          _ext = meta.fileExtension;
          _sizeText = meta.formattedSize;
        }
        _supportsResume = meta.supportsResume;
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
    if (fileName.isEmpty) fileName = widget.suggestedFileName ?? UrlMetadataHelper.extractCandidateName(rawUrl);
    fileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (fileName.length > 120) fileName = fileName.substring(0, 120).trim();
    final cleanExt = _ext.replaceAll('.', '').trim();
    if (cleanExt.isNotEmpty && !fileName.toLowerCase().endsWith('.${cleanExt.toLowerCase()}')) {
      fileName = '$fileName.$cleanExt';
    }
    final dest = '$_storagePath${Platform.pathSeparator}$fileName';
    final ref = _refCtrl.text.trim();
    final ok = await DownloadService().startDownload(
      taskId: '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}',
      url: rawUrl, destinationPath: dest, segmentsCount: 4, startNow: startNow,
      referer: ref.isNotEmpty ? ref : null,
      totalBytes: _resolvedTotalBytes > 0 ? _resolvedTotalBytes : null,
      audioUrl: widget.audioUrl,
    );
    if (mounted) {
      Navigator.pop(context, ok);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(startNow ? 'Starting: $fileName' : 'Added to list: $fileName'), duration: const Duration(seconds: 2)));
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

  InputDecoration _inputDeco(ColorScheme cs) {
    final b = OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.card), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)));
    return InputDecoration(isDense: true, filled: true, fillColor: cs.surfaceContainerHighest, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: b, enabledBorder: b, focusedBorder: b.copyWith(borderSide: BorderSide(color: cs.primary, width: 1.5)));
  }

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
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
                const SizedBox(width: 4),
                TextButton(onPressed: () => _submit(startNow: false), child: Text('ADD', style: AppTypography.bodyMd.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700))),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => _submit(startNow: true),
                  style: FilledButton.styleFrom(backgroundColor: isDark ? Colors.white : const Color(0xFF0F172A), foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white),
                  child: Text('START', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
