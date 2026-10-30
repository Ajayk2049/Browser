import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../config/env.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../../downloads/downloads.dart';
import '../models/search_engine.dart';
import '../utils/url_helper.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/gecko_browser_view.dart';
import '../widgets/media_grabber_sheet.dart';

/// Pure native GeckoView browser screen with direct delegate control.
/// Strictly governed by rules.md §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const String _defaultUrl = Env.defaultHomeUrl;

  late final GeckoBrowserController _controller;
  late final TextEditingController _urlController;
  final List<DetectedMedia> _detectedMedia = [];
  SearchEngine _selectedEngine = SearchEngine.duckDuckGo;
  bool _isLoading = false;
  double _progress = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = GeckoBrowserController();
    _urlController = TextEditingController(text: _defaultUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _handleSubmit(String rawInput) {
    final resolvedUrl = UrlHelper.resolveInput(rawInput, _selectedEngine);
    if (resolvedUrl.isEmpty) return;

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) return;

    if (UrlHelper.isDownloadable(resolvedUrl)) {
      _promptDownload(uri);
    } else {
      setState(() => _errorMessage = null);
      _controller.loadUrl(resolvedUrl);
    }
  }

  bool _isPromptingDownload = false;

  Future<void> _promptDownload(Uri uri) async {
    final urlStr = uri.toString();
    if (_isPromptingDownload) return;
    _isPromptingDownload = true;
    try {
      if (mounted) await AddDownloadDialog.show(context, initialUrl: urlStr);
    } finally {
      _isPromptingDownload = false;
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
            BrowserAddressBar(
              controller: _urlController,
              selectedEngine: _selectedEngine,
              onEngineChanged: (engine) => setState(() => _selectedEngine = engine),
              onSubmitted: _handleSubmit,
              onOpenDownloads: () => context.push('/downloads'),
              detectedMediaCount: _detectedMedia.length,
              onOpenMediaGrabber: () => showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
                ),
                builder: (_) => MediaGrabberSheet(items: _detectedMedia),
              ),
            ),
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 2,
                color: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            if (_errorMessage != null) _buildErrorBanner(colorScheme),
            Expanded(
              child: GeckoBrowserView(
                initialUrl: _defaultUrl,
                controller: _controller,
                onPageStarted: (url) {
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                      _urlController.text = url;
                      _detectedMedia.clear();
                    });
                  }
                },
                onPageFinished: (success) {
                  if (mounted) setState(() => _isLoading = false);
                },
                onProgressChanged: (progress) {
                  if (mounted) setState(() => _progress = progress / 100.0);
                },
                onLocationChanged: (url) {
                  if (mounted && url.isNotEmpty) _urlController.text = url;
                  if (UrlHelper.isDownloadable(url)) {
                    final uri = Uri.tryParse(url);
                    if (uri != null) _promptDownload(uri);
                  }
                },
                onWebResourceError: (uri, code, category) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _errorMessage = 'Failed to load page: $category ($code)';
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(PhosphorIcons.warningCircle, color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: AppTypography.bodySm.copyWith(color: colorScheme.onErrorContainer),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _errorMessage = null);
              _controller.reload();
            },
            child: Text(
              'Retry',
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
