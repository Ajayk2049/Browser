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
import '../widgets/browser_tab_viewport.dart';
import '../widgets/find_in_page_bar.dart';
import '../widgets/page_security_sheet.dart';
import '../widgets/private_home_view.dart';

/// Pure native GeckoView browser screen with direct delegate control.
/// Governed by rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 300 lines).
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const String _homeUrl = 'Welcome to Dab Browser';
  static const MethodChannel _channel = MethodChannel('com.dab/downloader');

  late final TextEditingController _urlController;
  final List<BrowserTabSession> _normalTabs = [], _privateTabs = [];
  final List<DetectedMedia> _detectedMedia = [];
  bool _isPrivateMode = false, _isFindInPageVisible = false;
  late String _activeTabId;
  int _tabSequence = 0, _findCurrent = 0, _findTotal = 0;
  String _findQuery = '';

  SearchEngine get _selectedEngine => SearchEngineSettingsService.instance.settings.defaultEngine;
  List<BrowserTabSession> get _activeTabs => _isPrivateMode ? _privateTabs : _normalTabs;
  BrowserTabSession get _activeTab => _activeTabs.firstWhere((t) => t.id == _activeTabId, orElse: () => _activeTabs.isNotEmpty ? _activeTabs.first : _createTab(_homeUrl, _isPrivateMode));

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: '');
    _activeTabId = _createTab().id;
    _initAndRestoreSession();
    BookmarksService.instance..init()..addListener(_syncData);
    QuickLinksService.instance..init()..addListener(_syncData);
    SitePermissionsService.instance.init();
    _channel.setMethodCallHandler((call) async { if (call.method == 'closeAllPrivateTabs') _closeAllPrivateTabs(); });
  }

  Future<void> _initAndRestoreSession() async {
    await HomepageSettingsService.instance.init();
    final savedTabs = await TabPersistenceService.instance.loadSavedTabs();
    if (!mounted) return;
    setState(() {
      for (final rec in savedTabs) {
        _normalTabs.add(BrowserTabSession(id: 'tab-${_tabSequence++}', controller: GeckoBrowserController(), url: rec.url)..title = rec.title);
      }
      final hs = HomepageSettingsService.instance.settings;
      if (hs.customHomepageUrl.isNotEmpty && hs.openOnStartup) {
        _activeTab.url = hs.customHomepageUrl; _urlController.text = hs.customHomepageUrl;
        _activeTab.controller.loadUrl(hs.customHomepageUrl);
      }
    });
  }

  void _persistTabs() => TabPersistenceService.instance.saveTabs([for (final t in _normalTabs) if (!t.isHome) TabPersistenceRecord(id: t.id, url: t.url, title: t.title)]);
  void _notifyPrivateCount() => _channel.invokeMethod('updatePrivateNotification', {'count': _privateTabs.length});

  @override
  void dispose() {
    BookmarksService.instance.removeListener(_syncData);
    QuickLinksService.instance.removeListener(_syncData);
    _urlController.dispose(); super.dispose();
  }

  void _syncData() { if (mounted) setState(() {}); }

  BrowserTabSession _createTab([String url = _homeUrl, bool isPrivate = false]) {
    final tab = BrowserTabSession(id: 'tab-${_tabSequence++}', controller: GeckoBrowserController(), url: url, isPrivate: isPrivate);
    if (isPrivate) { _privateTabs.add(tab); _notifyPrivateCount(); } else { _normalTabs.add(tab); }
    return tab;
  }

  void _handleSubmit(String rawInput) {
    if (rawInput == _homeUrl || rawInput == 'dab.app/home' || rawInput.trim().isEmpty) return _loadHome();
    final customUrl = SearchEngineSettingsService.instance.settings.customEngineUrl;
    final resolvedUrl = UrlHelper.resolveInput(rawInput, _selectedEngine, customQueryUrl: customUrl);
    if (resolvedUrl.isEmpty) return;
    if (UrlHelper.isDownloadable(resolvedUrl)) { _promptDownload(resolvedUrl); return; }
    if (Uri.tryParse(resolvedUrl) == null) return;
    _activeTab.controller.loadUrl(resolvedUrl);
    setState(() { _activeTab..error = null..url = resolvedUrl; _urlController.text = resolvedUrl; });
    if (!_isPrivateMode) _persistTabs();
  }

  void _loadHome() {
    setState(() {
      _activeTab..url = _homeUrl..title = 'Home'..error = null..isLoading = false..canGoForward = false;
      _urlController.text = ''; _detectedMedia.clear();
      if (!_isPrivateMode) _persistTabs();
    });
  }

  Future<void> _promptDownload(String url) async => BrowserShortcutHelper.promptDownload(context, url);

  void _selectTab(String id, [bool? isPrivate]) {
    if (_isFindInPageVisible) { _isFindInPageVisible = false; _activeTab.controller.clearFindInPage(); }
    final oldTab = _activeTab;
    setState(() {
      if (isPrivate != null) _isPrivateMode = isPrivate;
      _activeTabId = id;
      _urlController.text = _activeTab.isHome ? '' : _activeTab.url;
      _detectedMedia.clear();
    });
    if (oldTab.id != _activeTab.id) {
      if (!oldTab.isHome) oldTab.controller.setActive(false);
      if (!_activeTab.isHome) _activeTab.controller.setActive(true);
    }
  }

  void _newTab([bool? isPrivate]) {
    if (_isFindInPageVisible) { _isFindInPageVisible = false; _activeTab.controller.clearFindInPage(); }
    final oldTab = _activeTab;
    setState(() {
      final priv = isPrivate ?? _isPrivateMode;
      _isPrivateMode = priv;
      final pool = priv ? _privateTabs : _normalTabs;
      final existingHome = pool.cast<BrowserTabSession?>().firstWhere((t) => t?.isHome ?? false, orElse: () => null);
      _activeTabId = (existingHome ?? _createTab(_homeUrl, priv)).id;
      _urlController.text = ''; _detectedMedia.clear();
    });
    if (oldTab.id != _activeTab.id && !oldTab.isHome) {
      oldTab.controller.setActive(false);
    }
  }

  void _closeTab(String id, [bool? isPrivate]) {
    setState(() {
      final priv = isPrivate ?? _isPrivateMode;
      final pool = priv ? _privateTabs : _normalTabs;
      final idx = pool.indexWhere((t) => t.id == id);
      if (idx < 0) return;
      pool.removeAt(idx);
      if (priv) _notifyPrivateCount();
      if (pool.isEmpty) {
        if (priv) {
          _isPrivateMode = false;
          if (_normalTabs.isEmpty) _createTab();
          _activeTabId = _normalTabs.last.id;
        } else {
          _activeTabId = _createTab().id;
        }
      } else if (_activeTabId == id) {
        _activeTabId = pool[idx < pool.length ? idx : pool.length - 1].id;
      }
      _urlController.text = _activeTab.isHome ? '' : _activeTab.url;
      _detectedMedia.clear();
      if (!priv) _persistTabs();
    });
    if (!_activeTab.isHome) _activeTab.controller.setActive(true);
  }

  void _closeAllPrivateTabs() => setState(() {
    _privateTabs.clear(); _notifyPrivateCount();
    if (_isPrivateMode) {
      _isPrivateMode = false;
      if (_normalTabs.isEmpty) _createTab();
      _activeTabId = _normalTabs.last.id;
      _urlController.text = _activeTab.isHome ? '' : _activeTab.url;
    }
  });

  Future<void> _openTabsSheet() async {
    await BrowserShortcutHelper.openTabsSheet(
      context,
      normalTabs: [for (final t in _normalTabs) if (!t.isHome) t.info(isActive: !_isPrivateMode && t.id == _activeTabId)],
      privateTabs: [for (final t in _privateTabs) if (!t.isHome) t.info(isActive: _isPrivateMode && t.id == _activeTabId)],
      initialSegment: _isPrivateMode ? 1 : 0,
      onSelect: (id, priv) => _selectTab(id, priv), onClose: (id, priv) => _closeTab(id, priv), onNewTab: (priv) => _newTab(priv),
    );
  }

  Future<void> _openBookmarks() async { final u = await context.push<String>('/bookmarks'); if (u != null && u.isNotEmpty) _handleSubmit(u); }
  Future<void> _openHistory() async { final u = await context.push<String>('/history'); if (u != null && u.isNotEmpty) _handleSubmit(u); }

  void _handleMenuAction(BrowserMenuAction action) {
    switch (action) {
      case BrowserMenuAction.findInPage:
        if (_activeTab.isHome) {
          ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(
            content: Text('Open a webpage to find text'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2),
          ));
        } else {
          setState(() { _isFindInPageVisible = true; _findCurrent = 0; _findTotal = 0; });
        }
      case BrowserMenuAction.settings: context.push('/settings');
      case BrowserMenuAction.downloadManager: context.push('/downloads');
      case BrowserMenuAction.bookmarks: _openBookmarks();
      case BrowserMenuAction.history: _openHistory();
    }
  }

  void _toggleBookmark() => BrowserShortcutHelper.toggleBookmark(context, _activeTab);
  void _sharePage() => BrowserShortcutHelper.sharePage(_activeTab.url, _activeTab.title);
  void _openPageSecurity() => PageSecuritySheet.show(context, url: _activeTab.url, title: _activeTab.title); void _openMediaGrabber() => BrowserShortcutHelper.openMediaGrabber(context, _detectedMedia);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeIndex = _activeTabs.indexWhere((t) => t.id == _activeTabId).clamp(0, _activeTabs.length - 1);
    final canHandleBack = _activeTab.canGoBack || !_activeTab.isHome;
    final isCurrentBookmarked = BookmarksService.instance.isBookmarked(_activeTab.url);

    return PopScope(
      canPop: !canHandleBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_activeTab.canGoBack) { _activeTab.controller.goBack(); } else if (!_activeTab.isHome) { _loadHome(); }
      },
      child: Scaffold(
        backgroundColor: _isPrivateMode ? const Color(0xFF0C0E14) : colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              BrowserAddressBar(
                controller: _urlController, onSubmitted: _handleSubmit,
                isBookmarked: !_activeTab.isHome && isCurrentBookmarked,
                onToggleBookmark: _activeTab.isHome ? null : _toggleBookmark,
                onOpenPageInfo: _openPageSecurity,
                onReload: () { if (!_activeTab.isHome) _activeTab.controller.reload(); },
                isLoading: _activeTab.isLoading, detectedMediaCount: _detectedMedia.length,
                onOpenMediaGrabber: _openMediaGrabber, selectedEngine: _selectedEngine,
                onEngineChanged: (e) => SearchEngineSettingsService.instance.updateSettings((c) => c.copyWith(defaultEngine: e)),
                isHome: _activeTab.isHome, isPrivate: _isPrivateMode,
              ),
              if (_activeTab.isLoading)
                LinearProgressIndicator(value: _activeTab.progress > 0 ? _activeTab.progress : null, minHeight: 2, color: colorScheme.primary, backgroundColor: colorScheme.surfaceContainerHighest),
              if (_activeTab.error != null)
                BrowserErrorBanner(message: _activeTab.error ?? '', onRetry: () { setState(() => _activeTab.error = null); _activeTab.controller.reload(); }),
              Expanded(
                child: IndexedStack(
                  index: activeIndex,
                  children: [for (final tab in _activeTabs) _buildTabView(tab)],
                ),
              ),
              if (_isFindInPageVisible)
                FindInPageBar(
                  currentMatch: _findCurrent, totalMatches: _findTotal,
                  onQueryChanged: (q) { _findQuery = q; _activeTab.controller.findInPage(q, forward: true); },
                  onNext: () => _findQuery.isNotEmpty ? _activeTab.controller.findInPage(_findQuery, forward: true) : null,
                  onPrevious: () => _findQuery.isNotEmpty ? _activeTab.controller.findInPage(_findQuery, forward: false) : null,
                  onClose: () { setState(() => _isFindInPageVisible = false); _activeTab.controller.clearFindInPage(); },
                ),
            ],
          ),
        ),
        bottomNavigationBar: BrowserBottomBar(
          canGoForward: _activeTab.canGoForward, onForward: () => _activeTab.controller.goForward(),
          onShare: _sharePage, canShare: !_activeTab.isHome && _activeTab.url.isNotEmpty,
          isHome: _activeTab.isHome, onHome: _loadHome, tabCount: _activeTabs.where((t) => !t.isHome).length,
          isPrivate: _isPrivateMode, onOpenTabs: _openTabsSheet, onNewTab: () => _newTab(), onMenuAction: _handleMenuAction,
        ),
      ),
    );
  }

  Widget _buildTabView(BrowserTabSession tab) {
    if (tab.isHome) {
      if (tab.isPrivate) return PrivateHomeView(onOpenUrl: _handleSubmit);
      return BrowserHomeView(
        onOpenUrl: _handleSubmit, onSeeAllBookmarks: _openBookmarks,
        onAddQuickLink: () => BrowserShortcutHelper.openAddQuickLink(context),
        onRemoveQuickLink: (item) => BrowserShortcutHelper.confirmRemoveQuickLink(context, item),
        quickLinks: QuickLinksService.instance.quickLinks, bookmarks: BookmarksService.instance.bookmarks,
      );
    }
    return BrowserTabViewport(
      key: ValueKey(tab.id), tab: tab, isActive: tab.id == _activeTabId,
      onUrlChanged: (url) => setState(() { _urlController.text = url; _detectedMedia.clear(); }),
      onDownloadPrompt: _promptDownload,
      onFinderResult: (cur, tot) => setState(() { _findCurrent = cur; _findTotal = tot; }),
      onSync: () => setState(() {}),
    );
  }
}
