import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_geckoview/webview_flutter_geckoview.dart';
import '../../../config/env.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_shapes.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';

/// Minimal single-screen browser validating the GeckoView engine integration.
/// Strictly governed by rules.md §25.1, §25.2, §25.7, and §29.2.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const String _defaultUrl = Env.defaultHomeUrl;

  late final WebViewController _controller;
  late final TextEditingController _urlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _defaultUrl);

    // Instantiate GeckoView controller via GeckoWebViewControllerCreationParams
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
            if (mounted) {
              setState(() => _isLoading = false);
            }
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

  void _loadUrl() {
    String input = _urlController.text.trim();
    if (input.isEmpty) return;

    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      input = 'https://$input';
    }

    final uri = Uri.tryParse(input);
    if (uri != null) {
      _controller.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                params: GeckoWebViewWidgetCreationParams(
                  controller: _controller.platform,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _loadUrl(),
              style: AppTypography.bodyMd.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search or enter address',
                hintStyle: AppTypography.bodyMd.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  PhosphorIcons.globe,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x2,
                ),
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
            onPressed: _loadUrl,
            style: FilledButton.styleFrom(
              shape: AppShapes.pill,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
            ),
            child: Text(
              'Go',
              style: AppTypography.bodyMd.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

