# 1DM+ Flutter Widgets & Download Engine Kit

Ready-to-use Flutter UI widgets and core controller replicating the 1DM+ download architecture.

## Included Files
1. `download_item_widget.dart`
   - Complete card widget displaying download tasks, state pills (Connecting, Downloading, Paused, Completed, Error), transfer speed, percentage, size formatting, and action buttons.
2. `multi_part_chunk_visualizer.dart`
   - Chunk progress visualizer showing multi-part partition segments (1–32 parts), byte range progress bars, and thread activity.
3. `media_grabber_sheet.dart`
   - Bottom sheet component for link & media sniffing. Filters video, audio, images, documents, and includes direct download triggers.
4. `download_engine_controller.dart`
   - State controller (`ChangeNotifier`) that splits large HTTP downloads into range chunks, downloads segments in parallel, writes directly to file offsets, and streams live speed statistics.

## How to use in your Flutter app

Add the dependencies to your `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
```

Import and display the widgets:
```dart
import 'package:flutter/material.dart';
import 'download_item_widget.dart';
import 'multi_part_chunk_visualizer.dart';
import 'media_grabber_sheet.dart';

// Display captured media sheet:
MediaGrabberSheet.show(
  context,
  items: sniffedList,
  onStartDownload: (item) => print('Start: ${item.url}'),
);
```
