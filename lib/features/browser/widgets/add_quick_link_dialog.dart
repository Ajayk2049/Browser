import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../models/home_content_item.dart';
import '../services/quick_links_service.dart';

/// Modal dialog allowing users to add custom quick shortcuts with live icon preview.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class AddQuickLinkDialog extends StatefulWidget {
  const AddQuickLinkDialog({super.key});

  static Future<QuickLink?> show(BuildContext context) {
    return showDialog<QuickLink>(
      context: context,
      builder: (_) => const AddQuickLinkDialog(),
    );
  }

  @override
  State<AddQuickLinkDialog> createState() => _AddQuickLinkDialogState();
}

class _AddQuickLinkDialogState extends State<AddQuickLinkDialog> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final valid = _urlController.text.trim().isNotEmpty;
    if (valid != _canSave) setState(() => _canSave = valid);
  }

  String get _previewFaviconUrl {
    final text = _urlController.text.trim();
    if (text.isEmpty) return '';
    final url = text.startsWith('http') ? text : 'https://$text';
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return '';
    return 'https://www.google.com/s2/favicons?domain=$host&sz=128';
  }

  Future<void> _handleSave() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final title = _titleController.text.trim();
    final item = await QuickLinksService.instance.addQuickLink(
      title: title,
      url: url,
    );

    if (mounted && item != null) {
      Navigator.of(context).pop(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final previewUrl = _previewFaviconUrl;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Row(
        children: [
          Icon(PhosphorIcons.plusCircle, size: 22, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.x2),
          Text(
            'Add Shortcut',
            style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (previewUrl.isNotEmpty)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.m3Sm),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                previewUrl,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  PhosphorIcons.globe,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. YouTube',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'e.g. youtube.com',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (_canSave) _handleSave();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave ? _handleSave : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

