import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:browser/features/browser/models/home_content_item.dart';
import 'package:browser/features/browser/widgets/browser_home_view.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('BrowserHomeView', () {
    testWidgets('renders Explore & Discover greeting, quick links, and sections', (tester) async {
      String? openedUrl;
      var seeAllTapped = false;
      var addTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserHomeView(
            onOpenUrl: (url) => openedUrl = url,
            onSeeAllBookmarks: () => seeAllTapped = true,
            onAddQuickLink: () => addTapped = true,
          ),
        ),
      );

      // Verify Greeting
      expect(find.text('Explore & Discover'), findsOneWidget);

      // Verify Quick Links
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Linear'), findsOneWidget);
      expect(find.text('Figma'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      // Verify Section headers
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('Saved Pages'), findsOneWidget);

      // Test tapping a quick link
      await tester.tap(find.text('Google'));
      await tester.pump();
      expect(openedUrl, 'https://www.google.com');

      // Test tapping Add
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(addTapped, isTrue);

      // Test tapping See all
      await tester.tap(find.textContaining('See all'));
      await tester.pump();
      expect(seeAllTapped, isTrue);
    });

    testWidgets('wraps quick links across multiple rows when more than 4 items exist', (tester) async {
      final items = [
        const QuickLink(id: '1', title: 'Site 1', url: 'https://1.com', letter: '1'),
        const QuickLink(id: '2', title: 'Site 2', url: 'https://2.com', letter: '2'),
        const QuickLink(id: '3', title: 'Site 3', url: 'https://3.com', letter: '3'),
        const QuickLink(id: '4', title: 'Site 4', url: 'https://4.com', letter: '4'),
        const QuickLink(id: '5', title: 'Site 5', url: 'https://5.com', letter: '5'),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserHomeView(
            onOpenUrl: (_) {},
            onSeeAllBookmarks: () {},
            onAddQuickLink: () {},
            quickLinks: items,
          ),
        ),
      );

      // Verify all 5 sites and the Add button exist in the grid
      expect(find.text('Site 1'), findsOneWidget);
      expect(find.text('Site 4'), findsOneWidget);
      expect(find.text('Site 5'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}

