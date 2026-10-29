import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter_geckoview/webview_flutter_geckoview.dart';
import 'app.dart';
import 'features/downloads/downloads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GeckoWebViewPlatform.registerWith();
  DownloadService(); // Initialize download channel listener & logger
  runApp(
    const ProviderScope(
      child: BrowserApp(),
    ),
  );
}
