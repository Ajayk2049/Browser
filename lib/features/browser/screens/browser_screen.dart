import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../downloads/downloads.dart';
import '../../settings/services/homepage_settings_service.dart';
import '../../settings/services/search_engine_settings_service.dart';
import '../models/browser_tab.dart';
import '../models/search_engine.dart';
import '../services/bookmarks_service.dart';
import '../services/media_sniffer_service.dart';
import '../services/quick_links_service.dart';
import '../services/tab_persistence_service.dart';
import '../services/youtube_grabber_service.dart';
import '../utils/url_helper.dart';
import '../widgets/browser_address_bar.dart';
import '../widgets/browser_bottom_bar.dart';
import '../widgets/browser_error_view.dart';
import '../widgets/browser_home_view.dart';
import '../widgets/browser_overflow_menu.dart';
import '../widgets/browser_shortcut_helper.dart';
import '../widgets/browser_tab_viewport.dart';
import '../widgets/find_in_page_bar.dart';
import '../widgets/floating_media_grabber_button.dart';
import '../widgets/page_security_sheet.dart';
import '../widgets/private_home_view.dart';

/// Pure native GeckoView browser screen with direct delegate control.
/// Governed by rules.md Â§13, Â§25.1, Â§25.2, Â§25.7, and Â§29.2 (< 300 lines).
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
  String? _lastCheckedVideoId;
  String? _detectingVideoId;
  bool _isDetectingMedia = false;
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
    BookmarksService.instance.addListener(_syncData);
    QuickLinksService.instance.addListener(_syncData);
    SearchEngineSettingsService.instance.addListener(_syncData);
    _channel.setMethodCallHandler((call) async { if (call.method == 'closeAllPrivateTabs') _closeAllPrivateTabs(); });
    MediaSnifferService.instance.genericStream.listen(_onGenericSniffedMedia);
    MediaSnifferService.instance.removedUrlStream.listen(_onRemovedSniffedUrl);
    MediaSnifferService.instance.stream.listen(_onSniffedMedia);
  }

  Future<void> _initAndRestoreSession() async {
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
      _activeTab.isLoaded = true;
    });
    if (!_activeTab.isHome) _checkYouTube(_activeTab.url);
  }

  void _persistTabs() => TabPersistenceService.instance.saveTabs([for (final t in _normalTabs) if (!t.isHome) TabPersistenceRecord(id: t.id, url: t.url, title: t.title)]);
  void _notifyPrivateCount() => _channel.invokeMethod('updatePrivateNotification', {'count': _privateTabs.length});

  @override
  void dispose() {
    BookmarksService.instance.removeListener(_syncData); QuickLinksService.instance.removeListener(_syncData);
    SearchEngineSettingsService.instance.removeListener(_syncData);
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
    _lastCheckedVideoId = null;
    setState(() { _activeTab..isLoaded = true..error = null..pageError = null..url = resolvedUrl; _urlController.text = resolvedUrl; _detectedMedia.clear(); });
    _checkYouTube(resolvedUrl);
    if (!_isPrivateMode) _persistTabs();
  }

  void _loadHome() {
    _lastCheckedVideoId = null;
    setState(() {
      _activeTab..url = _homeUrl..title = 'Home'..error = null..pageError = null..isLoading = false..canGoForward = false;
      _urlController.text = ''; _detectedMedia.clear();
      if (!_isPrivateMode) _persistTabs();
    });
  }

  Future<void> _promptDownload(String url) async => BrowserShortcutHelper.promptDownload(context, url);

  void _selectTab(String id, [bool? isPrivate]) {
    if (_isFindInPageVisible) { _isFindInPageVisible = false; _activeTab.controller.clearFindInPage(); }
    final oldTab = _activeTab;
    _lastCheckedVideoId = null;
    setState(() {
      if (isPrivate != null) _isPrivateMode = isPrivate;
      _activeTabId = id; _activeTab.isLoaded = true;
      _urlController.text = _activeTab.isHome ? '' : _activeTab.url;
      _detectedMedia..clear()..addAll(_activeTab.isHome ? const [] : MediaSnifferService.instance.buildGenericItemsForPage(_activeTab.url, pageTitle: _activeTab.title));
    });
    if (oldTab.id != _activeTab.id) {
      if (!oldTab.isHome) oldTab.controller.setActive(false);
      if (!_activeTab.isHome) { _activeTab.controller.setActive(true); _checkYouTube(_activeTab.url); }
    }
  }

  void _newTab([bool? isPrivate]) {
    if (_isFindInPageVisible) { _isFindInPageVisible = false; _activeTab.controller.clearFindInPage(); }
    final oldTab = _activeTab;
    _lastCheckedVideoId = null;
    setState(() {
      final priv = isPrivate ?? _isPrivateMode;
      _isPrivateMode = priv;
      final pool = priv ? _privateTabs : _normalTabs;
      final existingHome = pool.cast<BrowserTabSession?>().firstWhere((t) => t?.isHome ?? false, orElse: () => null);
      _activeTabId = (existingHome ?? _createTab(_homeUrl, priv)).id; _urlController.text = ''; _detectedMedia.clear();
    });
    if (oldTab.id != _activeTab.id && !oldTab.isHome) oldTab.controller.setActive(false);
  }

  void _closeTab(String id, [bool? isPrivate]) {
    _lastCheckedVideoId = null;
    setState(() {
      final priv = isPrivate ?? _isPrivateMode;
      final pool = priv ? _privateTabs : _normalTabs;
      final idx = pool.indexWhere((t) => t.id == id);
      if (idx < 0) return;
      pool.removeAt(idx);
      if (priv) _notifyPrivateCount();
      if (pool.isEmpty) {
        if (priv) {
          _isPrivateMode = false; if (_normalTabs.isEmpty) _createTab();
          _activeTabId = _normalTabs.last.id;
        } else { _activeTabId = _createTab().id; }
      } else if (_activeTabId == id) {
        _activeTabId = pool[idx < pool.length ? idx : pool.length - 1].id;
      }
      _urlController.text = _activeTab.isHome ? '' : _activeTab.url; _detectedMedia.clear();
      if (!priv) _persistTabs();
    });
    if (!_activeTab.isHome) _activeTab.controller.setActive(true);
  }

  void _closeAllPrivateTabs() => setState(() {
    _privateTabs.clear(); _notifyPrivateCount();
    if (_isPrivateMode) {
      _isPrivateMode = false;
      if (_normalTabs.isEmpty) _createTab();
      _activeTabId = _normalTabs.last.id; _urlController.text = _activeTab.isHome ? '' : _activeTab.url;
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
  Future<void> _openSettings() async { final u = await context.push<String>('/settings'); if (u != null && u.isNotEmpty) _handleSubmit(u); }

  void _handleMenuAction(BrowserMenuAction action) {
    if (action == BrowserMenuAction.findInPage) {
      if (_activeTab.isHome) ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('Open a webpage to find text'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)));
      else setState(() { _isFindInPageVisible = true; _findCurrent = 0; _findTotal = 0; });
    } else if (action == BrowserMenuAction.settings) _openSettings();
    else if (action == BrowserMenuAction.downloadManager) context.push('/downloads');
    else if (action == BrowserMenuAction.bookmarks) _openBookmarks();
    else if (action == BrowserMenuAction.history) _openHistory();
  }

  void _toggleBookmark() => BrowserShortcutHelper.toggleBookmark(context, _activeTab); void _sharePage() => BrowserShortcutHelper.sharePage(_activeTab.url, _activeTab.title);
  void _openPageSecurity() => PageSecuritySheet.show(context, url: _activeTab.url, title: _activeTab.title);
  Future<void> _openMediaGrabber() async {
    // Nothing resolved yet (yt-dlp still warming up, or the probe failed):
    // tapping the pill retries instead of opening an empty sheet.
    if (_detectedMedia.isEmpty) {
      final vid = YoutubeGrabberService.extractVideoId(_activeTab.url);
      if (vid != null) {
        final messenger = ScaffoldMessenger.of(context);
        messenger..hideCurrentSnackBar()..showSnackBar(const SnackBar(
          content: Text('Finding downloadable streams…'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
        if (_detectingVideoId == vid) return; // probe already running
        await _checkYouTube(_activeTab.url);
        if (!mounted) return;
        if (_detectedMedia.isEmpty) {
          messenger..hideCurrentSnackBar()..showSnackBar(const SnackBar(
            content: Text('No downloadable streams found. Tap again to retry.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ));
          return;
        }
      }
    }
    if (!mounted) return;
    final isYt = YoutubeGrabberService.isYouTubeUrl(_activeTab.url) || YoutubeGrabberService.extractVideoId(_activeTab.url) != null;
    List<DetectedMedia> sheetItems = _detectedMedia;
    List<DetectedMedia> previews = const [];
    if (!isYt && !_activeTab.isHome) {
      final generic = MediaSnifferService.instance.buildGenericItemsForPage(_activeTab.url, pageTitle: _activeTab.title);
      previews = MediaSnifferService.instance.buildPreviewItemsForPage(_activeTab.url, pageTitle: _activeTab.title);
      final genericKeys = {for (final g in generic) MediaSnifferService.stripQuery(g.url)};
      final extras = _detectedMedia.where((m) => !m.sniffed && !genericKeys.contains(MediaSnifferService.stripQuery(m.url))).toList();
      sheetItems = [...generic, ...extras];
      setState(() => _detectedMedia..clear()..addAll(sheetItems));
    }
    BrowserShortcutHelper.openMediaGrabber(context, sheetItems, previews: previews);
  }
  void _handleMediaDetected(String u, String t, String typ) {
    if (YoutubeGrabberService.isYouTubeUrl(_activeTab.url)) return;
    if (!MediaSnifferService.isAllowedMedia(url: u, mediaType: typ)) return;
    final cleanU = MediaSnifferService.stripQuery(u);
    if (_detectedMedia.any((m) => MediaSnifferService.stripQuery(m.url) == cleanU && m.type == typ)) return;
    setState(() => _detectedMedia.add(DetectedMedia(url: u, referer: _activeTab.url, title: t.isNotEmpty && t != _homeUrl ? t : 'Media Stream ${_detectedMedia.length + 1}', type: typ)));
  }
  void _onUrlUpdated(String u) {
    setState(() => _urlController.text = u);
    final vid = YoutubeGrabberService.extractVideoId(u);
    // Same video (YouTube re-writes the query string on SPA navigation):
    // keep the streams we already resolved instead of clearing + re-probing.
    if (vid != null && vid == _lastCheckedVideoId) return;
    _lastCheckedVideoId = vid;
    if (vid == null) {
      final generic = MediaSnifferService.instance.buildGenericItemsForPage(u, pageTitle: _activeTab.title);
      setState(() => _detectedMedia..clear()..addAll(generic));
      return;
    }
    setState(_detectedMedia.clear);
    _checkYouTube(u);
  }
  bool get _isDetecting => _isDetectingMedia && _detectingVideoId == YoutubeGrabberService.extractVideoId(_activeTab.url);
  Future<void> _checkYouTube(String u) async {
    final vid = YoutubeGrabberService.extractVideoId(u);
    if (vid == null) return;
    if (_detectingVideoId == vid) return; // probe already in flight
    _detectingVideoId = vid;
    _lastCheckedVideoId = vid;
    if (mounted) setState(() => _isDetectingMedia = true);
    List<DetectedMedia> list;
    try {
      list = await YoutubeGrabberService.instance.extractStreams(u);
    } catch (_) {
      list = const [];
    } finally {
      if (_detectingVideoId == vid) _detectingVideoId = null;
      if (mounted) setState(() => _isDetectingMedia = _detectingVideoId != null);
    }
    if (!mounted || list.isEmpty) return;
    // Results only apply while this is still the active video.
    if (YoutubeGrabberService.extractVideoId(_activeTab.url) != vid) return;
    setState(() {
      for (final i in list) {
        // Sniffed (page-session) items win over API-derived ones for the same itag.
        if (_detectedMedia.any((m) => m.sniffed && m.videoItag == i.videoItag && m.videoId == vid)) continue;
        // Replace a stale entry for the same stream with the freshly minted URL
        // instead of appending a duplicate row to the grabber.
        final idx = _detectedMedia.indexWhere(
          (m) => !m.sniffed && m.videoId == i.videoId && m.videoItag == i.videoItag,
        );
        if (idx >= 0) {
          _detectedMedia[idx] = i;
        } else if (i.videoId != null && i.videoItag != null) {
          // yt-dlp items all share the page URL, so (video, format) is the key.
          _detectedMedia.add(i);
        } else if (!_detectedMedia.any((m) => m.url == i.url)) {
          _detectedMedia.add(i);
        }
      }
    });
  }

  /// Stream URLs sniffed from the page's own player traffic arrive here while
  /// the video is playing. They replace any API-derived items for the same
  /// itag because these URLs are attested for the current device session.
  void _onSniffedMedia(SniffedMedia s) {
    if (!mounted) return;
    final vid = YoutubeGrabberService.extractVideoId(_activeTab.url);
    if (vid == null || s.videoId != vid) return;
    final title = _activeTab.title.isNotEmpty ? _activeTab.title : s.pageUrl;
    final items = MediaSnifferService.instance.buildItems(vid, title);
    if (items.isEmpty) return;
    setState(() {
      _detectedMedia.removeWhere((m) => m.sniffed && m.videoId == vid);
      for (final i in items) {
        _detectedMedia.removeWhere((m) => !m.sniffed && m.videoId == vid && m.videoItag == i.videoItag);
        if (!_detectedMedia.any((m) => m.url == i.url)) _detectedMedia.add(i);
      }
    });
  }

  void _onRemovedSniffedUrl(String cleanUrl) {
    if (!mounted || YoutubeGrabberService.isYouTubeUrl(_activeTab.url)) return;
    if (_detectedMedia.any((m) => MediaSnifferService.stripQuery(m.url) == cleanUrl)) {
      setState(() => _detectedMedia.removeWhere((m) => MediaSnifferService.stripQuery(m.url) == cleanUrl));
    }
  }

  void _onGenericSniffedMedia(GenericSniffedMedia g) {
    if (!mounted || _activeTab.isHome) return;
    if (YoutubeGrabberService.extractVideoId(_activeTab.url) != null || YoutubeGrabberService.isYouTubeUrl(_activeTab.url)) return;
    final activeKey = MediaSnifferService.pageKey(_activeTab.url);
    final gKey = g.pageUrl.isNotEmpty ? MediaSnifferService.pageKey(g.pageUrl) : '';
    final activeHost = Uri.tryParse(_activeTab.url)?.host.toLowerCase() ?? '';
    final originHost = Uri.tryParse(g.originUrl)?.host.toLowerCase() ?? '';
    final matchesTab = gKey.isNotEmpty ? (gKey == activeKey) : (activeHost.isNotEmpty && originHost == activeHost);
    if (!matchesTab) return;
    final detected = MediaSnifferService.instance.toDetectedMedia(g, pageTitle: _activeTab.title);
    final cleanUrl = MediaSnifferService.stripQuery(detected.url);
    setState(() {
      if (g.replacesUrl != null) {
        final cleanReplaced = MediaSnifferService.stripQuery(g.replacesUrl!);
        _detectedMedia.removeWhere((m) => m.type == 'stream' && MediaSnifferService.stripQuery(m.url) == cleanReplaced);
      }
      final idx = _detectedMedia.indexWhere((m) => MediaSnifferService.stripQuery(m.url) == cleanUrl && m.type == detected.type && (m.quality ?? '') == (detected.quality ?? ''));
      if (idx >= 0) _detectedMedia[idx] = detected;
      else _detectedMedia.add(detected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeIndex = _activeTabs.indexWhere((t) => t.id == _activeTabId).clamp(0, _activeTabs.length - 1);
    final canHandleBack = _activeTab.canGoBack || !_activeTab.isHome;
    final isCurrentBookmarked = BookmarksService.instance.isBookmarked(_activeTab.url);

    return PopScope(
      canPop: !canHandleBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) { if (_activeTab.canGoBack) { _activeTab.controller.goBack(); } else if (!_activeTab.isHome) { _loadHome(); } }
      },
      child: Scaffold(
        backgroundColor: _isPrivateMode ? const Color(0xFF0C0E14) : colorScheme.surface,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  BrowserAddressBar(
                    controller: _urlController, onSubmitted: _handleSubmit, isBookmarked: !_activeTab.isHome && isCurrentBookmarked,
                    onToggleBookmark: _activeTab.isHome ? null : _toggleBookmark, onOpenPageInfo: _openPageSecurity,
                    onReload: () { if (!_activeTab.isHome) { setState(() => _activeTab.pageError = null); _activeTab.controller.reload(); } }, isLoading: _activeTab.isLoading,
                    selectedEngine: _selectedEngine, onEngineChanged: (e) => SearchEngineSettingsService.instance.updateSettings((c) => c.copyWith(defaultEngine: e)),
                    isHome: _activeTab.isHome, isPrivate: _isPrivateMode,
                  ),
                  if (_activeTab.isLoading)
                    LinearProgressIndicator(value: _activeTab.progress > 0 ? _activeTab.progress : null, minHeight: 2, color: colorScheme.primary, backgroundColor: colorScheme.surfaceContainerHighest),
                  Expanded(child: IndexedStack(index: activeIndex, children: [for (final tab in _activeTabs) _buildTabView(tab)])),
                  if (_isFindInPageVisible) FindInPageBar(
                    currentMatch: _findCurrent, totalMatches: _findTotal,
                    onQueryChanged: (q) { _findQuery = q; _activeTab.controller.findInPage(q, forward: true); },
                    onNext: () => _findQuery.isNotEmpty ? _activeTab.controller.findInPage(_findQuery, forward: true) : null,
                    onPrevious: () => _findQuery.isNotEmpty ? _activeTab.controller.findInPage(_findQuery, forward: false) : null,
                    onClose: () { setState(() => _isFindInPageVisible = false); _activeTab.controller.clearFindInPage(); },
                  ),
                ],
              ),
              if (!_activeTab.isHome && (_detectedMedia.isNotEmpty || YoutubeGrabberService.extractVideoId(_activeTab.url) != null))
                FloatingMediaGrabberButton(count: _detectedMedia.length, loading: _isDetecting, onTap: _openMediaGrabber),
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
      return tab.isPrivate ? PrivateHomeView(onOpenUrl: _handleSubmit) : BrowserHomeView(
        onOpenUrl: _handleSubmit, onSeeAllBookmarks: _openBookmarks,
        onAddQuickLink: () => BrowserShortcutHelper.openAddQuickLink(context),
        onRemoveQuickLink: (item) => BrowserShortcutHelper.confirmRemoveQuickLink(context, item),
        quickLinks: QuickLinksService.instance.quickLinks, bookmarks: BookmarksService.instance.bookmarks,
      );
    }
    if (!tab.isLoaded) return const SizedBox.shrink();
    final isActive = tab.id == _activeTabId;
    return Stack(
      children: [
        RepaintBoundary(child: BrowserTabViewport(
          key: ValueKey(tab.id), tab: tab, isActive: isActive, onUrlChanged: _onUrlUpdated,
          onDownloadPrompt: _promptDownload, onMediaDetected: _handleMediaDetected,
          onFinderResult: (cur, tot) => setState(() { _findCurrent = cur; _findTotal = tot; }), onSync: () => setState(() {}),
        )),
        if (tab.pageError != null)
          BrowserErrorView(
            error: tab.pageError!,
            onReload: () {
              setState(() => tab.pageError = null);
              if (tab.url.isNotEmpty) tab.controller.loadUrl(tab.url);
              else tab.controller.reload();
            },
            onGoHome: _loadHome,
            onProceedAnyway: tab.pageError!.isSecurityError
                ? () {
                    final target = tab.pageError!.insecureFallbackUrl;
                    setState(() {
                      tab.pageError = null;
                      if (target.isNotEmpty) {
                        tab.url = target;
                        if (isActive) _urlController.text = target;
                      }
                    });
                    tab.controller.proceedInsecure(target);
                  }
                : null,
          ),
      ],
    );
  }
}
