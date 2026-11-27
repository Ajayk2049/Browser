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
    testWidgets('renders Share, Home, Downloads, Tabs, New Tab, Menu and responds to taps', (tester) async {
      var shareTapped = false;
      var homeTapped = false;
      var downloadsTapped = false;
      var tabsTapped = false;
      var newTabTapped = false;
      var menuTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserBottomBar(
            canShare: true,
            onShare: () => shareTapped = true,
            onHome: () => homeTapped = true,
            onDownloads: () => downloadsTapped = true,
            tabCount: 3,
            onOpenTabs: () => tabsTapped = true,
            onNewTab: () => newTabTapped = true,
            onMenu: () => menuTapped = true,
          ),
        ),
      );

      expect(find.text('Forward'), findsNothing);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Tabs'), findsOneWidget);
      expect(find.text('New Tab'), findsOneWidget);
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('Share'));
      expect(shareTapped, isTrue);

      await tester.tap(find.text('Home'));
      expect(homeTapped, isTrue);

      await tester.tap(find.text('Downloads'));
      expect(downloadsTapped, isTrue);

      await tester.tap(find.text('Tabs'));
      expect(tabsTapped, isTrue);

      await tester.tap(find.text('New Tab'));
      expect(newTabTapped, isTrue);

      await tester.tap(find.text('Menu'));
      expect(menuTapped, isTrue);
    });

    testWidgets('opens menu popup with Forward action and respects canGoForward', (tester) async {
      BrowserMenuAction? selectedAction;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserBottomBar(
            canGoForward: false,
            onShare: () {},
            onHome: () {},
            onOpenTabs: () {},
            onMenuAction: (action) => selectedAction = action,
          ),
        ),
      );

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Forward'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Download Manager'), findsOneWidget);
      expect(find.text('Find in page'), findsOneWidget);

      // Forward is disabled when canGoForward is false
      await tester.tap(find.text('Forward'));
      await tester.pumpAndSettle();
      expect(selectedAction, isNull);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(selectedAction, BrowserMenuAction.settings);
    });
  });
}
