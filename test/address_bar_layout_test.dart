import 'package:browser/features/browser/widgets/browser_address_bar.dart';
import 'package:browser/features/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('address bar lays out without overflow on a narrow phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TextEditingController(text: 'https://duckduckgo.com');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        ),
        home: Scaffold(
          body: BrowserAddressBar(
            controller: controller,
            onSubmitted: (_) {},
            isBookmarked: false,
            onToggleBookmark: () {},
            onReload: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // The omnibox pill was intentionally slimmed from 48 to 44.
    final pill = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('https://duckduckgo.com'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((pill.constraints?.maxHeight) ?? 44, 44);
  });

  testWidgets('settings screen lists placeholder entries without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        ),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Homepage'), findsOneWidget);
    expect(find.text('Default search engine'), findsOneWidget);

    // Later sections live below the fold in a lazy list.
    await tester.scrollUntilVisible(find.text('Privacy & security'), 200);
    expect(find.text('Privacy & security'), findsOneWidget);
  });

  testWidgets('address bar aligns left on focus and selects all on webpage',
      (tester) async {
    final homeCtrl = TextEditingController();
    addTearDown(homeCtrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserAddressBar(
            controller: homeCtrl,
            onSubmitted: (_) {},
            onReload: () {},
            isHome: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).textAlign, TextAlign.center);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).textAlign, TextAlign.start);

    final pageCtrl = TextEditingController(text: 'https://example.com/path');
    addTearDown(pageCtrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserAddressBar(
            key: const ValueKey('page-bar'),
            controller: pageCtrl,
            onSubmitted: (_) {},
            onReload: () {},
            isHome: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).textAlign, TextAlign.start);
    expect(
      pageCtrl.selection,
      const TextSelection(baseOffset: 0, extentOffset: 24),
    );

    // Clear button appears when focused with text and clears input
    expect(find.byTooltip('Clear'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(pageCtrl.text, '');
    expect(find.byTooltip('Reload'), findsOneWidget);

    // Tapping outside unfocuses and restores original URL when not submitted
    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();
    expect(pageCtrl.text, 'https://example.com/path');
  });
}
