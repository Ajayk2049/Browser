import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:browser/features/downloads/downloads.dart';

void main() {
  group('DownloadTask 1DM+ multithreaded chunks', () {
    test('getChunks calculates segment progress correctly across threads', () {
      // 50% overall progress across 8 segments
      const task = DownloadTask(
        id: 'test-1',
        url: 'https://example.com/file.zip',
        destinationPath: 'file.zip',
        segmentsCount: 8,
        totalBytes: 1000,
        downloadedBytes: 500,
        progress: 0.5,
        status: DownloadStatus.downloading,
      );

      final chunks = task.getChunks(8);
      expect(chunks.length, 8);
      // First 4 chunks are fully completed (1.0)
      expect(chunks[0], 1.0);
      expect(chunks[1], 1.0);
      expect(chunks[2], 1.0);
      expect(chunks[3], 1.0);
      // Chunks 5-8 are 0.0
      expect(chunks[4], 0.0);
      expect(chunks[5], 0.0);
      expect(chunks[6], 0.0);
      expect(chunks[7], 0.0);
    });

    test('getChunks handles partial progress on active segment', () {
      // 53.8% progress with 8 segments (span = 0.125)
      // Segment 4 starts at 0.50 and ends at 0.625
      const task = DownloadTask(
        id: 'test-2',
        url: 'https://example.com/file.iso',
        destinationPath: 'file.iso',
        segmentsCount: 8,
        progress: 0.538,
        status: DownloadStatus.downloading,
      );

      final chunks = task.getChunks(8);
      expect(chunks[0], 1.0);
      expect(chunks[1], 1.0);
      expect(chunks[2], 1.0);
      expect(chunks[3], 1.0);
      // Chunk index 4 has partial progress
      expect(chunks[4], greaterThan(0.0));
      expect(chunks[4], lessThan(1.0));
      // Chunk index 5 has 0.0
      expect(chunks[5], 0.0);
    });
  });

  group('DownloadTaskCard Widget', () {
    Widget buildTestable(Widget child) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders active downloading card with 1DM+ chunks and pause button', (tester) async {
      const task = DownloadTask(
        id: 'task-active',
        url: 'https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server.iso',
        destinationPath: 'ubuntu-24.04-live-server.iso',
        segmentsCount: 6,
        totalBytes: 2791728742,
        downloadedBytes: 1503238553,
        speedBytesPerSec: 19084083,
        progress: 0.538,
        status: DownloadStatus.downloading,
      );

      await tester.pumpWidget(
        buildTestable(
          DownloadTaskCard(
            task: task,
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ubuntu-24.04-live-server.iso'), findsOneWidget);
      expect(find.textContaining('6 Threads'), findsOneWidget);
      expect(find.textContaining('18.2 MB/s'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.pause), findsOneWidget);
    });

    testWidgets('renders completed card with checkmark and formatted date', (tester) async {
      const task = DownloadTask(
        id: 'task-done',
        url: 'https://cdn.example.com/audio/interstellar_main_theme.flac',
        destinationPath: 'interstellar_main_theme.flac',
        totalBytes: 44879052,
        downloadedBytes: 44879052,
        progress: 1.0,
        status: DownloadStatus.completed,
        dateLabel: 'Today, 3:14 PM',
      );

      await tester.pumpWidget(
        buildTestable(
          DownloadTaskCard(
            task: task,
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('interstellar_main_theme.flac'), findsOneWidget);
      expect(find.textContaining('42.8 MB • Today, 3:14 PM'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.check), findsOneWidget);
    });
  });

  group('DownloadSpeedDialFab Widget', () {
    testWidgets('renders B&W FAB and expands options without error', (tester) async {
      var addedLink = false;
      var fromClipboard = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          home: Scaffold(
            floatingActionButton: DownloadSpeedDialFab(
              isOpen: true,
              onToggle: () {},
              onAddLink: () => addedLink = true,
              onFromClipboard: () => fromClipboard = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('From clipboard'), findsOneWidget);
      expect(find.text('Add link'), findsOneWidget);

      await tester.tap(find.text('Add link'));
      expect(addedLink, isTrue);

      await tester.tap(find.text('From clipboard'));
      expect(fromClipboard, isTrue);
    });
  });

  group('UrlMetadataHelper candidate extraction', () {
    test('extractCandidateName extracts filename from path or query', () {
      expect(
        UrlMetadataHelper.extractCandidateName('https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server.iso'),
        'ubuntu-24.04-live-server.iso',
      );
      expect(
        UrlMetadataHelper.extractCandidateName('https://cdn.example.com/download?file=custom_archive.zip'),
        'custom_archive.zip',
      );
      expect(
        UrlMetadataHelper.extractExtension('ubuntu-24.04-live-server.iso'),
        'iso',
      );
    });
  });

  group('AddDownloadDialog manual entry', () {
    testWidgets('entering url manually auto-populates candidate filename and extension', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddDownloadDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final urlField = find.byType(TextField).first;
      await tester.enterText(urlField, 'https://example.com/downloads/my_dataset.tar.gz');
      await tester.pumpAndSettle();

      // Ensure candidate name is immediately populated without requiring Enter
      expect(find.text('my_dataset.tar.gz'), findsOneWidget);
      expect(find.text('gz'), findsOneWidget);
    });
  });
}

