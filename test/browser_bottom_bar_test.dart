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
      var forwardTapped = false;
      var shareTapped = false;
      var homeTapped = false;
      var tabsTapped = false;
      var menuTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserBottomBar(
            canGoForward: true,
            onForward: () => forwardTapped = true,
            onShare: () => shareTapped = true,
            onHome: () => homeTapped = true,
            tabCount: 3,
            onOpenTabs: () => tabsTapped = true,
            onMenu: () => menuTapped = true,
          ),
        ),
      );

      // Verify labels
      expect(find.text('Forward'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Tabs'), findsOneWidget);
      expect(find.text('Menu'), findsOneWidget);

      // Verify tab counter
      expect(find.text('3'), findsOneWidget);

      // Tap actions
      await tester.tap(find.text('Forward'));
      expect(forwardTapped, isTrue);

      await tester.tap(find.text('Share'));
      expect(shareTapped, isTrue);

      await tester.tap(find.text('Home'));
      expect(homeTapped, isTrue);

      await tester.tap(find.text('Tabs'));
      expect(tabsTapped, isTrue);

      await tester.tap(find.text('Menu'));
      expect(menuTapped, isTrue);
    });

    testWidgets('respects canGoForward disabled state', (tester) async {
      var forwardTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserBottomBar(
            canGoForward: false,
            onForward: () => forwardTapped = true,
            onShare: () {},
            onHome: () {},
            onOpenTabs: () {},
            onMenu: () {},
          ),
        ),
      );

      await tester.tap(find.text('Forward'));
      expect(forwardTapped, isFalse);
    });

    testWidgets('opens menu popup when onMenuAction is provided', (tester) async {
      BrowserMenuAction? selectedAction;

      await tester.pumpWidget(
        buildTestableWidget(
          BrowserBottomBar(
            onShare: () {},
            onHome: () {},
            onOpenTabs: () {},
            onMenuAction: (action) => selectedAction = action,
          ),
        ),
      );

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Download Manager'), findsOneWidget);
      expect(find.text('Find in page'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(selectedAction, BrowserMenuAction.settings);
    });
  });
}
