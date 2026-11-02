import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/browser/services/bookmarks_service.dart';
import 'features/browser/services/history_service.dart';
import 'features/browser/services/quick_links_service.dart';
import 'features/downloads/downloads.dart';
import 'features/settings/services/homepage_settings_service.dart';
import 'features/settings/services/search_engine_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DownloadService(); // Initialize download channel listener & logger
  await BookmarksService.instance.init();
  await QuickLinksService.instance.init();
  await HistoryService.instance.init();
  await HomepageSettingsService.instance.init();
  await SearchEngineSettingsService.instance.init();
  runApp(
    const ProviderScope(
      child: BrowserApp(),
    ),
  );
}
