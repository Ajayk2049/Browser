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

/// Material 3 white-theme Download dialog matching 1DM+ layout.
/// Supports ADD (queue/paused), CANCEL, and START (active download) actions.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class AddDownloadDialog extends StatefulWidget {
  final String? initialUrl;

  const AddDownloadDialog({super.key, this.initialUrl});

  static Future<bool?> show(BuildContext context, {String? initialUrl}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddDownloadDialog(initialUrl: initialUrl),
    );
  }

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _nameCtrl;
  String _ext = 'bin';
  String _sizeText = 'Resolving file info...';
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
    _nameCtrl = TextEditingController(text: 'Resolving title...');
    _initStorage();
    if (url.isNotEmpty) _probe(url);
  }

  @override
  void dispose() {
    _urlCtrl.dispose(); _refCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _initStorage() async {
    final dir = await getApplicationDocumentsDirectory();
    _storagePath = dir.path;
    final space = await DownloadService().getDiskSpace(dir.path);
    final a = space['available'] ?? 0;
    final t = space['total'] ?? 0;
    if (mounted) {
      setState(() {
        _storageText = t > 0
            ? 'Storage: ${(a / 1e9).toStringAsFixed(2)}GB/${(t / 1e9).toStringAsFixed(2)}GB, ${((a / t) * 100).toStringAsFixed(1)}% free'
            : 'Storage: Ready';
      });
    }
  }

  Future<void> _probe(String url) async {
    if (url.trim().isEmpty) return;
    setState(() => _sizeText = 'Resolving file info...');
    final meta = await UrlMetadataHelper.resolve(url, referer: _refCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = meta.fileName;
      _ext = meta.fileExtension;
      _supportsResume = meta.supportsResume;
      _sizeText = meta.formattedSize;
      if (meta.finalUrl.isNotEmpty && meta.finalUrl != url && meta.finalUrl.startsWith('http')) {
        _refCtrl.text = url;
        _urlCtrl.text = meta.finalUrl;
      }
    });
  }

  Future<void> _submit({required bool startNow}) async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) return;
    final fileName = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'download_${DateTime.now().millisecondsSinceEpoch}.$_ext';
    final dest = '$_storagePath${Platform.pathSeparator}$fileName';
    final ref = _refCtrl.text.trim();
    final ok = await DownloadService().startDownload(
      taskId: '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}',
      url: rawUrl, destinationPath: dest, segmentsCount: 4, startNow: startNow,
      referer: ref.isNotEmpty ? ref : null,
    );
    if (mounted) {
      Navigator.pop(context, ok);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(startNow ? 'Starting: $fileName' : 'Added to list: $fileName')));
    }
  }

  Widget _buildField(String label, Widget child, ColorScheme cs, [List<Widget>? actions]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(label, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))), ...?actions]),
        const SizedBox(height: 3),
        child,
      ],
    );
  }

  InputDecoration _inputDeco(ColorScheme cs) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: cs.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.card), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.card), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.card), borderSide: BorderSide(color: cs.primary, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const orange = Color(0xFFE65100);

    return Dialog(
      backgroundColor: cs.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header without right-side icons
              Text('Download file!', style: AppTypography.displaySm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: AppSpacing.x3),

              // 1. Link Section with Resume status & Quick actions
              _buildField(
                'Link (Resume: ${_supportsResume ? "Yes" : "No"})',
                TextField(
                  controller: _urlCtrl,
                  style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
                  onSubmitted: _probe,
                  decoration: _inputDeco(cs),
                ),
                cs,
                [
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _urlCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied URL to clipboard')));
                    },
                    child: Icon(PhosphorIcons.copy, size: 16, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  Icon(PhosphorIcons.shareNetwork, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Icon(PhosphorIcons.caretDown, size: 14, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),

              // 2. Referer link
              _buildField(
                'Download/Referer page link',
                TextField(
                  controller: _refCtrl,
                  style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
                  decoration: _inputDeco(cs),
                ),
                cs,
                [Icon(PhosphorIcons.caretDown, size: 14, color: cs.onSurfaceVariant)],
              ),
              const SizedBox(height: AppSpacing.x2),

              // 3. Save as with Extension Badge
              _buildField(
                'Save as:',
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        maxLines: 2,
                        minLines: 1,
                        style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
                        decoration: _inputDeco(cs),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_ext, style: AppTypography.bodySm.copyWith(color: orange, fontWeight: FontWeight.w700)),
                  ],
                ),
                cs,
              ),
              const SizedBox(height: AppSpacing.x2),

              // 4. File Size & Storage Information
              Text(_sizeText, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(_storageText, style: AppTypography.bodySm.copyWith(color: orange, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.x1),

              // 5. Storage Directory Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.card)),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.clockCounterClockwise, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_storagePath, style: AppTypography.bodySm.copyWith(color: cs.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Icon(PhosphorIcons.folderSimple, size: 18, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),

              // 6. Action Buttons: ADD, CANCEL, START
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => _submit(startNow: false), child: Text('ADD', style: AppTypography.bodyMd.copyWith(color: cs.primary, fontWeight: FontWeight.w700))),
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: AppTypography.bodyMd.copyWith(color: cs.primary, fontWeight: FontWeight.w700))),
                  TextButton(onPressed: () => _submit(startNow: true), child: Text('START', style: AppTypography.bodyMd.copyWith(color: cs.primary, fontWeight: FontWeight.w700))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
