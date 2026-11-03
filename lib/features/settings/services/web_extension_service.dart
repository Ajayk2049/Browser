import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/web_extension_item.dart';

/// Service managing WebExtensions installation, lifecycle, and curated marketplace.
/// Complies with rules.md §13, §25.1, §25.2, and §29.2 (< 250 lines).
class WebExtensionService extends ChangeNotifier {
  static final WebExtensionService instance = WebExtensionService._internal();

  WebExtensionService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel _channel = MethodChannel('com.dab/extensions');

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onExtensionsChanged') {
      debugPrint('WebExtensionService: onExtensionsChanged received');
      await refreshInstalled();
    }
  }

  final List<WebExtensionItem> _installed = [];
  bool _isLoading = false;

  List<WebExtensionItem> get installed => List.unmodifiable(_installed);
  bool get isLoading => _isLoading;

  /// Curated marketplace list (pre-installed are handled separately and listed under installed)
  static const List<WebExtensionItem> curatedMarketplace = [
    WebExtensionItem(
      id: 'jid1-MnnxcxisBPnSXQ@jetpack',
      name: 'Privacy Badger',
      version: '2024.2.6',
      description: 'Automatically learns to block invisible trackers.',
      category: 'Security & Privacy',
      rating: 4.8,
      reviewsCount: '80k',
      downloadUrl: 'https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi',
    ),
    WebExtensionItem(
      id: 'addon@darkreader.org',
      name: 'Dark Reader',
      version: '4.9.96',
      description: 'Dark mode for every website. Invert colors for night browsing.',
      category: 'Appearance',
      rating: 4.7,
      reviewsCount: '48k',
      downloadUrl: 'https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi',
    ),
    WebExtensionItem(
      id: 'video-bg-play@janh.de',
      name: 'Video Background Play Fix',
      version: '1.8.0',
      description: 'Plays video and audio in the background on mobile websites.',
      category: 'Streaming & Media',
      rating: 4.6,
      reviewsCount: '25k',
      downloadUrl: 'https://addons.mozilla.org/firefox/downloads/latest/video-background-play-fix/latest.xpi',
    ),
    WebExtensionItem(
      id: '{7b1bf0b6-a1b9-42b0-b75d-252036438bdc}',
      name: 'YouTube High Definition',
      version: '85.0.0',
      description: 'Plays all YouTube videos in highest available definition automatically.',
      category: 'Streaming & Media',
      rating: 4.5,
      reviewsCount: '34k',
      downloadUrl: 'https://addons.mozilla.org/firefox/downloads/latest/youtube-high-definition/latest.xpi',
    ),
  ];

  Future<void> init() async {
    await refreshInstalled();
  }

  Future<void> refreshInstalled() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('list');
      _installed.clear();
      if (res != null) {
        for (final item in res) {
          if (item is Map) {
            _installed.add(WebExtensionItem.fromNativeMap(item));
          }
        }
      }
    } catch (e) {
      debugPrint('WebExtensionService.refreshInstalled error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> install(String xpiUrl) async {
    try {
      await _channel.invokeMethod('install', {'url': xpiUrl});
      await refreshInstalled();
      return true;
    } catch (e) {
      debugPrint('WebExtensionService.install error: $e');
      return false;
    }
  }

  Future<bool> update(String id) async {
    try {
      await _channel.invokeMethod('update', {'id': id});
      await refreshInstalled();
      return true;
    } catch (e) {
      debugPrint('WebExtensionService.update error: $e');
      return false;
    }
  }

  Future<void> toggleEnabled(WebExtensionItem item) async {
    try {
      if (item.isEnabled) {
        await _channel.invokeMethod('disable', {'id': item.id});
      } else {
        await _channel.invokeMethod('enable', {'id': item.id});
      }
      await refreshInstalled();
    } catch (e) {
      debugPrint('WebExtensionService.toggleEnabled error: $e');
    }
  }

  Future<void> uninstall(String id) async {
    try {
      await _channel.invokeMethod('uninstall', {'id': id});
      await refreshInstalled();
    } catch (e) {
      debugPrint('WebExtensionService.uninstall error: $e');
    }
  }
}
