import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/browser/services/bookmarks_service.dart';
import 'features/browser/services/history_service.dart';
import 'features/browser/services/quick_links_service.dart';
import 'features/browser/services/site_permissions_service.dart';
import 'features/downloads/downloads.dart';
import 'features/onboarding/services/onboarding_service.dart';
import 'features/settings/services/appearance_settings_service.dart';
import 'features/settings/services/homepage_settings_service.dart';
import 'features/settings/services/search_engine_settings_service.dart';
import 'features/settings/services/web_extension_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register the extension/native channel handlers before the Gecko runtime
  // installs the bundled sniffer extension, otherwise early `onSniffedMedia`
  // messages are delivered to nobody and dropped.
  WebExtensionService.instance;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 10 * 1024 * 1024;
  await OnboardingService.instance.init();
  runApp(
    const ProviderScope(
      child: BrowserApp(),
    ),
  );

  // Post-first-frame hydration & native Gecko warm-up (unblocks cold start)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    const MethodChannel('com.dab/downloader').invokeMethod('warmupGecko');
    DownloadService();
    Future.wait([
      BookmarksService.instance.init(),
      QuickLinksService.instance.init(),
      HistoryService.instance.init(),
      HomepageSettingsService.instance.init(),
      SearchEngineSettingsService.instance.init(),
      AppearanceSettingsService.instance.init(),
      SitePermissionsService.instance.init(),
    ]);
  });
}
