import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/browser/services/bookmarks_service.dart';
import 'features/browser/services/history_service.dart';
import 'features/browser/services/quick_links_service.dart';
import 'features/downloads/downloads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DownloadService(); // Initialize download channel listener & logger
  await BookmarksService.instance.init();
  await QuickLinksService.instance.init();
  await HistoryService.instance.init();
  runApp(
    const ProviderScope(
      child: BrowserApp(),
    ),
  );
}
