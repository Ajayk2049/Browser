import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../downloads/downloads.dart';
import '../models/browser_tab.dart';
import '../models/search_engine.dart';
import '../utils/url_helper.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_bookmarks_sheet.dart';
import '../widgets/browser_bottom_bar.dart';
import '../widgets/browser_error_banner.dart';
import '../widgets/browser_home_view.dart';
import '../widgets/browser_overflow_menu.dart';
import '../widgets/browser_tabs_sheet.dart';
import '../widgets/gecko_browser_view.dart';
import '../widgets/media_grabber_sheet.dart';

/// Pure native GeckoView browser screen with direct delegate control.
/// Strictly governed by rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const String _homeUrl = 'dab.app/home';

  late final TextEditingController _urlController;
  final List<BrowserTabSession> _tabs = [];
  final List<DetectedMedia> _detectedMedia = [];
  late String _activeTabId;
  int _tabSequence = 0;
  SearchEngine _selectedEngine = SearchEngine.duckDuckGo;
  bool _isPromptingDownload = false;

  BrowserTabSession get _activeTab =>
      _tabs.firstWhere((tab) => tab.id == _activeTabId);

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _homeUrl);
    _activeTabId = _createTab().id;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  BrowserTabSession _createTab([String url = _homeUrl]) {
    final tab = BrowserTabSession(
      id: 'tab-${_tabSequence++}',
      controller: GeckoBrowserController(),
      url: url,
    );
    _tabs.add(tab);
    return tab;
  }

  void _handleSubmit(String rawInput) {
    if (rawInput == _homeUrl || rawInput.trim().isEmpty) {
      _loadHome();
      return;
    }
    final resolvedUrl = UrlHelper.resolveInput(rawInput, _selectedEngine);
    if (resolvedUrl.isEmpty) return;

    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) return;

    if (UrlHelper.isDownloadable(resolvedUrl)) {
      _promptDownload(uri);
    } else {
      setState(() {
        _activeTab
          ..error = null
          ..url = resolvedUrl;
        _urlController.text = resolvedUrl;
      });
      _activeTab.controller.loadUrl(resolvedUrl);
    }
  }

  void _loadHome() {
    setState(() {
      _activeTab
        ..url = _homeUrl
        ..title = 'Explore & Discover'
        ..error = null
        ..isLoading = false;
      _urlController.text = _homeUrl;
      _detectedMedia.clear();
    });
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

  void _selectTab(String id) {
    if (id == _activeTabId) return;
    final tab = _tabs.firstWhere((t) => t.id == id);
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
      final index = _tabs.indexWhere((t) => t.id == id);
      if (index < 0) return;
      _tabs.removeAt(index);

      if (_tabs.isEmpty) {
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
          tabs: [for (final t in _tabs) t.info(isActive: t.id == _activeTabId)],
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

  void _handleMenuAction(BrowserMenuAction action) {
    if (action == BrowserMenuAction.settings) {
      context.push('/settings');
    } else if (action == BrowserMenuAction.downloadManager) {
      context.push('/downloads');
    } else if (action == BrowserMenuAction.bookmarks) {
      BrowserBookmarksSheet.show(context, onSelect: _handleSubmit);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${action.label} is not wired up yet'), behavior: SnackBarBehavior.floating));
    }
  }

  void _openMediaGrabber() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal))),
      builder: (_) => MediaGrabberSheet(items: _detectedMedia),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeIndex = _tabs.indexWhere((t) => t.id == _activeTabId).clamp(0, _tabs.length - 1);

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
              tabCount: _tabs.length,
              onOpenTabs: _openTabsSheet,
              detectedMediaCount: _detectedMedia.length,
              onOpenMediaGrabber: _openMediaGrabber,
            ),
            if (_activeTab.isLoading)
              LinearProgressIndicator(
                value: _activeTab.progress > 0 ? _activeTab.progress : null,
                minHeight: 2,
                color: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            if (_activeTab.error != null)
              BrowserErrorBanner(
                message: _activeTab.error ?? '',
                onRetry: () {
                  setState(() => _activeTab.error = null);
                  _activeTab.controller.reload();
                },
              ),
            Expanded(
              child: IndexedStack(
                index: activeIndex,
                children: [for (final tab in _tabs) _buildTabView(tab)],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BrowserBottomBar(
        canGoBack: _activeTab.canGoBack,
        onBack: () => _activeTab.controller.goBack(),
        isHome: _activeTab.isHome,
        onHome: _loadHome,
        onDownloads: () => context.push('/downloads'),
        onBookmarks: () => BrowserBookmarksSheet.show(context, onSelect: _handleSubmit),
        onMenuAction: _handleMenuAction,
      ),
    );
  }

  Widget _buildTabView(BrowserTabSession tab) {
    if (tab.isHome) {
      return BrowserHomeView(
        onOpenUrl: _handleSubmit,
        onSeeAllBookmarks: () => BrowserBookmarksSheet.show(context, onSelect: _handleSubmit),
        onAddQuickLink: () => _handleSubmit('https://www.google.com'),
      );
    }
    return KeyedSubtree(
      key: ValueKey(tab.id),
      child: GeckoBrowserView(
        initialUrl: tab.url,
        controller: tab.controller,
        onPageStarted: (url) {
          tab..url = url..isLoading = true..error = null;
          if (mounted && tab.id == _activeTabId) setState(() { _urlController.text = url; _detectedMedia.clear(); });
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
          if (tab.id == _activeTabId) {
            _urlController.text = url;
            final uri = Uri.tryParse(url);
            if (uri != null && UrlHelper.isDownloadable(url)) _promptDownload(uri);
          }
        },
        onCanGoBack: (bool canGoBack) {
          tab.canGoBack = canGoBack;
          if (mounted && tab.id == _activeTabId) setState(() {});
        },
        onWebResourceError: (uri, code, category) {
          tab..error = 'Could not reach this page ($category error $code)'..isLoading = false;
          if (mounted && tab.id == _activeTabId) setState(() {});
        },
      ),
    );
  }
}
