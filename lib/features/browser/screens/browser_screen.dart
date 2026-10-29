import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_geckoview/webview_flutter_geckoview.dart';
import '../../../config/env.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_shapes.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../../downloads/downloads.dart';

/// Single-screen browser with GeckoView engine and Download Manager trigger.
/// Strictly governed by rules.md §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const String _defaultUrl = Env.defaultHomeUrl;
  static const _downloadExtensions = [
    '.apk', '.zip', '.rar', '.7z', '.tar', '.gz', '.bin', '.iso',
    '.mp4', '.mkv', '.avi', '.mp3', '.pdf', '.dmg', '.exe'
  ];

  late final WebViewController _controller;
  late final TextEditingController _urlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _defaultUrl);

    const params = GeckoWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
              _urlController.text = url;
            }
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_defaultUrl));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    String input = _urlController.text.trim();
    if (input.isEmpty) return;

    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      input = 'https://$input';
    }

    final uri = Uri.tryParse(input);
    if (uri == null) return;

    final pathLower = uri.path.toLowerCase();
    final isDownload = _downloadExtensions.any((ext) => pathLower.endsWith(ext));

    if (isDownload) {
      _promptDownload(uri);
    } else {
      _controller.loadRequest(uri);
    }
  }

  Future<void> _promptDownload(Uri uri) async {
    final fileName = uri.pathSegments.lastOrNull ?? 'download_${DateTime.now().millisecondsSinceEpoch}';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(PhosphorIcons.downloadSimple, color: cs.primary, size: 28),
                  const SizedBox(width: AppSpacing.x2),
                  Text('Start High-Speed Download?', style: AppTypography.displaySm),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(fileName, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.x1),
              Text(
                'Uses 8 parallel connections with native foreground speed boost.',
                style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.x6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Download'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      final dir = await getApplicationDocumentsDirectory();
      final destPath = '${dir.path}/$fileName';
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();

      await DownloadService().startDownload(
        taskId: taskId,
        url: uri.toString(),
        destinationPath: destPath,
        segmentsCount: 8,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading $fileName...'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => context.push('/downloads'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAddressBar(colorScheme),
            if (_isLoading)
              LinearProgressIndicator(
                minHeight: 2,
                color: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            Expanded(
              child: WebViewWidget.fromPlatformCreationParams(
                params: GeckoWebViewWidgetCreationParams(controller: _controller.platform),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x1),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _handleSubmit(),
              style: AppTypography.bodyMd.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search or enter address',
                hintStyle: AppTypography.bodyMd.copyWith(color: colorScheme.onSurfaceVariant),
                prefixIcon: Icon(PhosphorIcons.globe, size: 20, color: colorScheme.onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x1),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          FilledButton(
            onPressed: _handleSubmit,
            style: FilledButton.styleFrom(
              shape: AppShapes.pill,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
            ),
            child: Text('Go', style: AppTypography.bodyMd.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppSpacing.x1),
          IconButton.filledTonal(
            tooltip: 'Downloads',
            icon: Icon(PhosphorIcons.downloadSimple, size: 20),
            onPressed: () => context.push('/downloads'),
          ),
        ],
      ),
    );
  }
}
