import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/tokens/app_radius.dart';
import '../../downloads/downloads.dart';
import '../../settings/services/homepage_settings_service.dart';
import '../../settings/services/search_engine_settings_service.dart';
import '../models/browser_tab.dart';
import '../models/home_content_item.dart';
import '../models/search_engine.dart';
import '../services/bookmarks_service.dart';
import '../services/quick_links_service.dart';
import '../services/site_permissions_service.dart';
import '../services/tab_persistence_service.dart';
import '../utils/url_helper.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_bottom_bar.dart';
import '../widgets/browser_error_banner.dart';
import '../widgets/browser_home_view.dart';
import '../widgets/browser_overflow_menu.dart';
import '../widgets/browser_shortcut_helper.dart';
import '../widgets/browser_tabs_sheet.dart';
import '../widgets/browser_tab_viewport.dart';
import '../widgets/media_grabber_sheet.dart';
import '../widgets/page_security_sheet.dart';

/// Pure native GeckoView browser screen with direct delegate control.
/// Strictly governed by rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const String _homeUrl = 'Welcome to Dab Browser';

  late final TextEditingController _urlController;
  final List<BrowserTabSession> _tabs = [];
  final List<DetectedMedia> _detectedMedia = [];
  late String _activeTabId;
  int _tabSequence = 0;
  bool _isPromptingDownload = false;

  SearchEngine get _selectedEngine => SearchEngineSettingsService.instance.settings.defaultEngine;

  BrowserTabSession get _activeTab => _tabs.firstWhere((t) => t.id == _activeTabId);

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: '');
    _activeTabId = _createTab().id;
    _initAndRestoreSession();
    BookmarksService.instance..init()..addListener(_syncData);
    QuickLinksService.instance..init()..addListener(_syncData);
    SitePermissionsService.instance.init();
  }

  Future<void> _initAndRestoreSession() async {
    await HomepageSettingsService.instance.init();
    final savedTabs = await TabPersistenceService.instance.loadSavedTabs();
    if (!mounted) return;
    setState(() {
      for (final rec in savedTabs) {
        _tabs.add(BrowserTabSession(id: 'tab-${_tabSequence++}', controller: GeckoBrowserController(), url: rec.url)..title = rec.title);
      }
      final hs = HomepageSettingsService.instance.settings;
      if (hs.customHomepageUrl.isNotEmpty && hs.openOnStartup) {
        _activeTab.url = hs.customHomepageUrl;
        _urlController.text = hs.customHomepageUrl;
        _activeTab.controller.loadUrl(hs.customHomepageUrl);
      }
    });
  }

  void _persistTabs() {
    TabPersistenceService.instance.saveTabs([
      for (final t in _tabs) if (!t.isHome) TabPersistenceRecord(id: t.id, url: t.url, title: t.title)
    ]);
  }

  @override
  void dispose() {
    BookmarksService.instance.removeListener(_syncData);
    QuickLinksService.instance.removeListener(_syncData);
    _urlController.dispose();
    super.dispose();
  }

  void _syncData() { if (mounted) setState(() {}); }

  BrowserTabSession _createTab([String url = _homeUrl]) {
    final tab = BrowserTabSession(id: 'tab-${_tabSequence++}', controller: GeckoBrowserController(), url: url);
    _tabs.add(tab);
    return tab;
  }

  void _handleSubmit(String rawInput) {
    if (rawInput == _homeUrl || rawInput == 'dab.app/home' || rawInput.trim().isEmpty) return _loadHome();
    final customUrl = SearchEngineSettingsService.instance.settings.customEngineUrl;
    final resolvedUrl = UrlHelper.resolveInput(rawInput, _selectedEngine, customQueryUrl: customUrl);
    if (resolvedUrl.isEmpty) return;
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) return;
    if (UrlHelper.isDownloadable(resolvedUrl)) {
      _promptDownload(uri);
    } else {
      setState(() { _activeTab..error = null..url = resolvedUrl; _urlController.text = resolvedUrl; });
      _activeTab.controller.loadUrl(resolvedUrl);
      _persistTabs();
    }
  }

  void _loadHome() {
    setState(() {
      _activeTab..url = _homeUrl..title = 'Home'..error = null..isLoading = false..canGoForward = false;
      _urlController.text = ''; _detectedMedia.clear();
      _persistTabs();
    });
  }

  Future<void> _promptDownload(Uri uri) async {
    if (_isPromptingDownload) return;
    _isPromptingDownload = true;
    try {
      if (mounted) await AddDownloadDialog.show(context, initialUrl: uri.toString());
    } finally { _isPromptingDownload = false; }
  }

  void _selectTab(String id) {
    if (id == _activeTabId) return;
    final tab = _tabs.firstWhere((t) => t.id == id);
    setState(() { _activeTabId = id; _urlController.text = tab.isHome ? '' : tab.url; _detectedMedia.clear(); });
  }

  void _newTab() => setState(() { _activeTabId = _createTab().id; _urlController.text = ''; _detectedMedia.clear(); });

  void _closeTab(String id) {
    setState(() {
      final idx = _tabs.indexWhere((t) => t.id == id);
      if (idx < 0) return;
      _tabs.removeAt(idx);
      _activeTabId = _tabs.isEmpty ? _createTab().id : (_activeTabId == id ? _tabs[idx < _tabs.length ? idx : _tabs.length - 1].id : _activeTabId);
      _urlController.text = _activeTab.isHome ? '' : _activeTab.url;
      _detectedMedia.clear();
      _persistTabs();
    });
  }

  Future<void> _openTabsSheet() async {
    if (_tabs.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => BrowserTabsSheet(
          tabs: [for (final t in _tabs) t.info(isActive: t.id == _activeTabId)],
          onSelect: (id) { _selectTab(id); Navigator.of(sCtx).pop(); },
          onClose: (id) { _closeTab(id); setSheetState(() {}); },
          onNewTab: () { _newTab(); Navigator.of(sCtx).pop(); },
        ),
      ),
    );
  }

  Future<void> _openBookmarks() async {
    final u = await context.push<String>('/bookmarks');
    if (u != null && u.isNotEmpty) _handleSubmit(u);
  }

  Future<void> _openHistory() async {
    final u = await context.push<String>('/history');
    if (u != null && u.isNotEmpty) _handleSubmit(u);
  }

  void _handleMenuAction(BrowserMenuAction action) {
    switch (action) {
      case BrowserMenuAction.settings: context.push('/settings');
      case BrowserMenuAction.downloadManager: context.push('/downloads');
      case BrowserMenuAction.bookmarks: _openBookmarks();
      case BrowserMenuAction.history: _openHistory();
      default:
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
          content: Text('${action.label} is not wired up yet'),
          behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
        ));
    }
  }

  Future<void> _toggleBookmark() async {
    if (_activeTab.isHome || _activeTab.url.isEmpty) return;
    final wasAdded = await BookmarksService.instance.toggleBookmark(
      url: _activeTab.url, title: _activeTab.title.isNotEmpty ? _activeTab.title : _activeTab.url,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
      content: Text(wasAdded ? 'Page added to bookmarks' : 'Bookmark removed'),
      behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
    ));
  }

  void _sharePage() => (_activeTab.url.isNotEmpty && !_activeTab.isHome)
      ? const MethodChannel('com.dab/downloader').invokeMethod('shareUrl', {'url': _activeTab.url, 'title': _activeTab.title})
      : null;

  void _openPageSecurity() => PageSecuritySheet.show(context, url: _activeTab.url, title: _activeTab.title);

  void _openMediaGrabber() => showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal))),
        builder: (_) => MediaGrabberSheet(items: _detectedMedia),
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeIndex = _tabs.indexWhere((t) => t.id == _activeTabId).clamp(0, _tabs.length - 1);
    final canHandleBack = _activeTab.canGoBack || !_activeTab.isHome;
    final isCurrentBookmarked = BookmarksService.instance.isBookmarked(_activeTab.url);

    return PopScope(
      canPop: !canHandleBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_activeTab.canGoBack) {
          _activeTab.controller.goBack();
        } else if (!_activeTab.isHome) {
          _loadHome();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              BrowserAddressBar(
                controller: _urlController,
                onSubmitted: _handleSubmit,
                isBookmarked: !_activeTab.isHome && isCurrentBookmarked,
                onToggleBookmark: _activeTab.isHome ? null : _toggleBookmark,
                onOpenPageInfo: _openPageSecurity,
                onReload: () { if (!_activeTab.isHome) _activeTab.controller.reload(); },
                isLoading: _activeTab.isLoading,
                detectedMediaCount: _detectedMedia.length,
                onOpenMediaGrabber: _openMediaGrabber,
                selectedEngine: _selectedEngine,
                onEngineChanged: (e) => SearchEngineSettingsService.instance.updateSettings((c) => c.copyWith(defaultEngine: e)),
                isHome: _activeTab.isHome,
              ),
              if (_activeTab.isLoading)
                LinearProgressIndicator(value: _activeTab.progress > 0 ? _activeTab.progress : null, minHeight: 2, color: colorScheme.primary, backgroundColor: colorScheme.surfaceContainerHighest),
              if (_activeTab.error != null)
                BrowserErrorBanner(message: _activeTab.error ?? '', onRetry: () { setState(() => _activeTab.error = null); _activeTab.controller.reload(); }),
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
          canGoForward: _activeTab.canGoForward,
          onForward: () => _activeTab.controller.goForward(),
          onShare: _sharePage,
          canShare: !_activeTab.isHome && _activeTab.url.isNotEmpty,
          isHome: _activeTab.isHome,
          onHome: _loadHome,
          tabCount: _tabs.length,
          onOpenTabs: _openTabsSheet,
          onNewTab: _newTab,
          onMenuAction: _handleMenuAction,
        ),
      ),
    );
  }

  Widget _buildTabView(BrowserTabSession tab) {
    if (tab.isHome) {
      return BrowserHomeView(
        onOpenUrl: _handleSubmit,
        onSeeAllBookmarks: _openBookmarks,
        onAddQuickLink: () => BrowserShortcutHelper.openAddQuickLink(context),
        onRemoveQuickLink: (item) => BrowserShortcutHelper.confirmRemoveQuickLink(context, item),
        quickLinks: QuickLinksService.instance.quickLinks,
        bookmarks: BookmarksService.instance.bookmarks,
      );
    }
    return BrowserTabViewport(
      tab: tab,
      isActive: tab.id == _activeTabId,
      onUrlChanged: (url) => setState(() { _urlController.text = url; _detectedMedia.clear(); }),
      onDownloadPrompt: _promptDownload,
      onSync: () => setState(() {}),
    );
  }
}
