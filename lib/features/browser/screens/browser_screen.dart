import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../config/env.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../../theme/tokens/app_spacing.dart';
import '../../../theme/tokens/app_typography.dart';
import '../../downloads/downloads.dart';
import '../models/browser_tab.dart';
import '../models/search_engine.dart';
import '../utils/url_helper.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_overflow_menu.dart';
import '../widgets/browser_tabs_sheet.dart';
import '../widgets/gecko_browser_view.dart';
import '../widgets/media_grabber_sheet.dart';

/// Live state for one open tab.
///
/// Each tab owns its own [GeckoBrowserController]; the native side creates one
/// GeckoSession per platform view, so switching tabs preserves page state
/// instead of reloading the URL.
class _BrowserTab {
  _BrowserTab({
    required this.id,
    required this.controller,
    required this.url,
  });

  final String id;
  final GeckoBrowserController controller;
  String url;
  String title = '';
  bool isLoading = false;
  double progress = 0.0;
  String? error;

  BrowserTabInfo info({required bool isActive}) => BrowserTabInfo(
        id: id,
        title: title,
        url: url,
        isActive: isActive,
      );
}

/// Pure native GeckoView browser screen with direct delegate control.
/// Strictly governed by rules.md §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const String _defaultUrl = Env.defaultHomeUrl;

  late final TextEditingController _urlController;
  final List<_BrowserTab> _tabs = [];
  final List<DetectedMedia> _detectedMedia = [];
  late String _activeTabId;
  int _tabSequence = 0;
  SearchEngine _selectedEngine = SearchEngine.duckDuckGo;
  bool _isPromptingDownload = false;

  _BrowserTab get _activeTab =>
      _tabs.firstWhere((tab) => tab.id == _activeTabId);

  bool get _isLoading => _activeTab.isLoading;
  double get _progress => _activeTab.progress;
  String? get _errorMessage => _activeTab.error;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _defaultUrl);
    _activeTabId = _createTab().id;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  _BrowserTab _createTab() {
    final tab = _BrowserTab(
      id: 'tab-${_tabSequence++}',
      controller: GeckoBrowserController(),
      url: _defaultUrl,
    );
    _tabs.add(tab);
    return tab;
  }

  void _handleSubmit(String rawInput) {
    final resolvedUrl = UrlHelper.resolveInput(rawInput, _selectedEngine);
    if (resolvedUrl.isEmpty) return;

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) return;

    if (UrlHelper.isDownloadable(resolvedUrl)) {
      _promptDownload(uri);
    } else {
      _activeTab.error = null;
      _activeTab.controller.loadUrl(resolvedUrl);
    }
  }

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

  // ---------------------------------------------------------------- tabs ----

  void _selectTab(String id) {
    if (id == _activeTabId) return;
    final tab = _tabs.firstWhere((tab) => tab.id == id);
    setState(() {
      _activeTabId = id;
      _urlController.text = tab.url;
      _detectedMedia.clear();
    });
  }

  void _newTab() {
    final tab = _createTab();
    setState(() {
      _activeTabId = tab.id;
      _urlController.text = tab.url;
      _detectedMedia.clear();
    });
  }

  void _closeTab(String id) {
    setState(() {
      final index = _tabs.indexWhere((tab) => tab.id == id);
      if (index < 0) return;
      _tabs.removeAt(index);

      if (_tabs.isEmpty) {
        // Closing the last tab leaves a fresh one, as mobile browsers do.
        _activeTabId = _createTab().id;
      } else if (_activeTabId == id) {
        _activeTabId = _tabs[index < _tabs.length ? index : _tabs.length - 1].id;
      }
      _urlController.text = _activeTab.url;
      _detectedMedia.clear();
    });
  }

  Future<void> _openTabsSheet() async {
    if (_tabs.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => BrowserTabsSheet(
          tabs: [
            for (final tab in _tabs) tab.info(isActive: tab.id == _activeTabId),
          ],
          onSelect: (id) {
            _selectTab(id);
            Navigator.of(sheetContext).pop();
          },
          onClose: (id) {
            _closeTab(id);
            setSheetState(() {});
          },
          onNewTab: () {
            _newTab();
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  // -------------------------------------------------------------- actions ---

  void _handleMenuAction(BrowserMenuAction action) {
    switch (action) {
      case BrowserMenuAction.settings:
        context.push('/settings');
      case BrowserMenuAction.downloadManager:
        context.push('/downloads');
      case _:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${action.label} is not wired up yet'),
              behavior: SnackBarBehavior.floating,
            ),
          );
    }
  }

  void _openMediaGrabber() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.modal),
        ),
      ),
      builder: (_) => MediaGrabberSheet(items: _detectedMedia),
    );
  }

  // ----------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeIndex = _tabs
        .indexWhere((tab) => tab.id == _activeTabId)
        .clamp(0, _tabs.length - 1);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            BrowserAddressBar(
              controller: _urlController,
              selectedEngine: _selectedEngine,
              onEngineChanged: (engine) =>
                  setState(() => _selectedEngine = engine),
              onSubmitted: _handleSubmit,
              tabCount: _tabs.length,
              onOpenTabs: _openTabsSheet,
              onMenuAction: _handleMenuAction,
              detectedMediaCount: _detectedMedia.length,
              onOpenMediaGrabber: _openMediaGrabber,
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
              child: IndexedStack(
                index: activeIndex,
                children: [for (final tab in _tabs) _buildTabView(tab)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabView(_BrowserTab tab) {
    return KeyedSubtree(
      key: ValueKey(tab.id),
      child: GeckoBrowserView(
        initialUrl: tab.url,
        controller: tab.controller,
        onPageStarted: (url) {
          tab
            ..url = url
            ..isLoading = true
            ..error = null;
          if (!mounted || tab.id != _activeTabId) return;
          setState(() {
            _urlController.text = url;
            _detectedMedia.clear();
          });
        },
        onPageFinished: (success) {
          tab.isLoading = false;
          if (mounted && tab.id == _activeTabId) setState(() {});
        },
        onProgressChanged: (progress) {
          tab.progress = progress / 100.0;
          if (mounted && tab.id == _activeTabId) setState(() {});
        },
        onLocationChanged: (url) {
          if (url.isEmpty) return;
          tab.url = url;
          if (tab.id != _activeTabId) return;

          _urlController.text = url;
          if (!UrlHelper.isDownloadable(url)) return;
          final uri = Uri.tryParse(url);
          if (uri != null) _promptDownload(uri);
        },
        onTitleChanged: (title) {
          tab.title = title;
          if (mounted && tab.id == _activeTabId) setState(() {});
        },
        onWebResourceError: (uri, code, category) {
          tab
            ..isLoading = false
            ..error = 'Failed to load page: $category ($code)';
          if (mounted && tab.id == _activeTabId) setState(() {});
        },
      ),
    );
  }

  Widget _buildErrorBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            PhosphorIcons.warningCircle,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: AppTypography.bodySm.copyWith(
                color: colorScheme.onErrorContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _activeTab.error = null);
              _activeTab.controller.reload();
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
