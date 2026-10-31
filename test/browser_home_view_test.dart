import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}

