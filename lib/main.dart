import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/downloads/downloads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DownloadService(); // Initialize download channel listener & logger
  runApp(
    const ProviderScope(
      child: BrowserApp(),
    ),
  );
}
