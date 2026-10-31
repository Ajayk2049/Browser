import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:browser/features/browser/models/home_content_item.dart';
import 'package:browser/features/browser/services/quick_links_service.dart';
import 'package:browser/features/browser/widgets/add_quick_link_dialog.dart';
import 'package:browser/features/browser/widgets/quick_link_squircle.dart';

void main() {
  setUp(() {
    QuickLinksService.instance.setQuickLinksForTesting([]);
  });

  group('QuickLink Model', () {
    test('faviconUrl resolves correct Google high-res favicon endpoint', () {
      const q1 = QuickLink(
        id: '1',
        title: 'Google',
        url: 'https://www.google.com',
        letter: 'G',
      );
      expect(q1.faviconUrl, 'https://www.google.com/s2/favicons?domain=www.google.com&sz=128');

      const q2 = QuickLink(
        id: '2',
        title: 'Linear',
        url: 'linear.app',
        letter: 'L',
      );
      expect(q2.faviconUrl, 'https://www.google.com/s2/favicons?domain=linear.app&sz=128');

      const qAdd = QuickLink(
        id: 'add',
        title: 'Add',
        url: '',
        letter: '+',
      );
      expect(qAdd.faviconUrl, isEmpty);
      expect(qAdd.isAddButton, isTrue);
    });

    test('toJson and fromJson preserves data', () {
      const original = QuickLink(
        id: 'yt',
        title: 'YouTube',
        url: 'https://youtube.com',
        letter: 'Y',
        iconUrl: 'https://custom.icon/yt.png',
      );
      final json = original.toJson();
      final restored = QuickLink.fromJson(json);

      expect(restored.id, 'yt');
      expect(restored.title, 'YouTube');
      expect(restored.url, 'https://youtube.com');
      expect(restored.letter, 'Y');
      expect(restored.iconUrl, 'https://custom.icon/yt.png');
    });
  });

  group('QuickLinksService', () {
    test('addQuickLink normalizes url, extracts title & letter, and notifies', () async {
      var notified = false;
      QuickLinksService.instance.addListener(() => notified = true);

      final item = await QuickLinksService.instance.addQuickLink(
        title: '',
        url: 'github.com',
      );

      expect(item, isNotNull);
      expect(item!.url, 'https://github.com');
      expect(item.title, 'github.com');
      expect(item.letter, 'G');
      expect(QuickLinksService.instance.count, 1);
      expect(notified, isTrue);
    });

    test('removeQuickLink removes item by id', () async {
      QuickLinksService.instance.setQuickLinksForTesting([
        const QuickLink(id: '1', title: 'A', url: 'https://a.com', letter: 'A'),
        const QuickLink(id: '2', title: 'B', url: 'https://b.com', letter: 'B'),
      ]);

      await QuickLinksService.instance.removeQuickLink('1');
      expect(QuickLinksService.instance.count, 1);
      expect(QuickLinksService.instance.quickLinks.first.id, '2');
    });
  });

  group('QuickLinkSquircle Widget', () {
    Widget buildTestable(Widget child) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: Center(child: child)),
      );
    }

    testWidgets('renders website icon for regular quick link with fallback', (tester) async {
      const link = QuickLink(
        id: 'figma',
        title: 'Figma',
        url: 'https://figma.com',
        letter: 'F',
      );

      await tester.pumpWidget(
        buildTestable(
          QuickLinkSquircle(
            item: link,
            isDark: false,
            borderColor: Colors.grey,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      // Title is rendered
      expect(find.text('Figma'), findsOneWidget);
      // Image.network is used to fetch website icon file
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders plus icon for Add button', (tester) async {
      const addLink = QuickLink(
        id: 'add',
        title: 'Add',
        url: '',
        letter: '+',
      );

      await tester.pumpWidget(
        buildTestable(
          QuickLinkSquircle(
            item: addLink,
            isDark: false,
            borderColor: Colors.grey,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.plus), findsOneWidget);
    });
  });

  group('AddQuickLinkDialog Widget', () {
    Widget buildTestable(Widget child) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      );
    }

    testWidgets('disables Add button until URL is entered, then saves link', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AddQuickLinkDialog.show(ctx),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Add Shortcut'), findsOneWidget);

      // Initially Add button is disabled
      final addButtonFinder = find.widgetWithText(FilledButton, 'Add');
      expect(tester.widget<FilledButton>(addButtonFinder).enabled, isFalse);

      // Enter title and URL
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Wikipedia');
      await tester.enterText(find.widgetWithText(TextField, 'URL'), 'wikipedia.org');
      await tester.pumpAndSettle();

      // Now Add button is enabled
      expect(tester.widget<FilledButton>(addButtonFinder).enabled, isTrue);

      // Tap Add
      await tester.tap(addButtonFinder);
      await tester.pumpAndSettle();

      // Verify added in QuickLinksService
      expect(QuickLinksService.instance.count, 1);
      final item = QuickLinksService.instance.quickLinks.first;
      expect(item.title, 'Wikipedia');
      expect(item.url, 'https://wikipedia.org');
    });
  });
}

