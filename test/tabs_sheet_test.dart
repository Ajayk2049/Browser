import 'package:browser/features/browser/models/browser_tab.dart';
import 'package:browser/features/browser/widgets/browser_tabs_button.dart';
import 'package:browser/features/browser/widgets/browser_tabs_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('tab counter shows the open tab count and fires on tap',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(_host(
      Align(
        alignment: Alignment.topLeft,
        child: BrowserTabsButton(tabCount: 3, onPressed: () => taps++),
      ),
    ));

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byType(BrowserTabsButton));
    expect(taps, 1);

    final target = tester.getRect(find.byType(BrowserTabsButton));
    expect(target.size, const Size(44, 44));

    // The visible chip is inset inside the 44dp tap target. A full-height
    // outlined square reads heavier than the omnibox pill and the neighbouring
    // icons, which is why the chip is smaller and centred.
    final chip = tester.getRect(
      find.ancestor(of: find.text('3'), matching: find.byType(Container)).first,
    );
    expect(chip.size, const Size(36, 36));
    expect(chip.center, target.center);
  });

  testWidgets('tabs sheet lists tabs, marks the active one, and reports taps',
      (tester) async {
    String? selected;
    String? closed;
    var created = 0;

    await tester.pumpWidget(_host(
      BrowserTabsSheet(
        tabs: const [
          BrowserTabInfo(
            id: 'tab-0',
            title: 'DuckDuckGo',
            url: 'https://duckduckgo.com',
            isActive: false,
          ),
          BrowserTabInfo(
            id: 'tab-1',
            title: '',
            url: 'https://example.com/article',
            isActive: true,
          ),
        ],
        onSelect: (id) => selected = id,
        onClose: (id) => closed = id,
        onNewTab: () => created++,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tabs'), findsOneWidget);
    expect(find.text('DuckDuckGo'), findsOneWidget);

    // An untitled tab falls back to its host instead of rendering blank.
    expect(find.text('example.com'), findsOneWidget);

    await tester.tap(find.text('DuckDuckGo'));
    expect(selected, 'tab-0');

    await tester.tap(find.byTooltip('Close tab').first);
    expect(closed, 'tab-0');

    await tester.tap(find.text('New tab'));
    expect(created, 1);
  });
}
