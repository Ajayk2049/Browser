import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:browser/features/browser/widgets/browser_bottom_bar.dart';
import 'package:browser/features/browser/widgets/browser_overflow_menu.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(bottomNavigationBar: child),
    );
  }

  group('BrowserBottomBar', () {
    testWidgets('renders all 5 navigation actions and responds to taps', (tester) async {
      var backTapped = false;
      var homeTapped = false;
      var downloadsTapped = false;
      var bookmarksTapped = false;
      var menuTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserBottomBar(
            canGoBack: true,
            onBack: () => backTapped = true,
            onHome: () => homeTapped = true,
            onDownloads: () => downloadsTapped = true,
            activeDownloadsCount: 2,
            onBookmarks: () => bookmarksTapped = true,
            onMenu: () => menuTapped = true,
          ),
        ),
      );

      // Verify labels
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Menu'), findsOneWidget);

      // Verify badge on downloads
      expect(find.text('2'), findsOneWidget);

      // Tap actions
      await tester.tap(find.text('Back'));
      expect(backTapped, isTrue);

      await tester.tap(find.text('Home'));
      expect(homeTapped, isTrue);

      await tester.tap(find.text('Downloads'));
      expect(downloadsTapped, isTrue);

      await tester.tap(find.text('Saved'));
      expect(bookmarksTapped, isTrue);

      await tester.tap(find.text('Menu'));
      expect(menuTapped, isTrue);
    });

    testWidgets('respects canGoBack disabled state', (tester) async {
      var backTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserBottomBar(
            canGoBack: false,
            onBack: () => backTapped = true,
            onHome: () {},
            onDownloads: () {},
            onBookmarks: () {},
            onMenu: () {},
          ),
        ),
      );

      await tester.tap(find.text('Back'));
      expect(backTapped, isFalse);
    });

    testWidgets('opens menu popup when onMenuAction is provided', (tester) async {
      BrowserMenuAction? selectedAction;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserBottomBar(
            onHome: () {},
            onDownloads: () {},
            onBookmarks: () {},
            onMenuAction: (action) => selectedAction = action,
          ),
        ),
      );

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Download Manager'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(selectedAction, BrowserMenuAction.settings);
    });
  });
}
