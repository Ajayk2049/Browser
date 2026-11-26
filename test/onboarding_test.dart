import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:browser/features/browser/models/search_engine.dart';
import 'package:browser/features/onboarding/screens/onboarding_screen.dart';
import 'package:browser/features/settings/services/search_engine_settings_service.dart';

void main() {
  group('SearchEngine defaults', () {
    test('SearchEngineSettingsModel defaults to Google', () {
      const model = SearchEngineSettingsModel();
      expect(model.defaultEngine, SearchEngine.google);
      expect(SearchEngineSettingsModel.fromJson({}).defaultEngine, SearchEngine.google);
    });

    test('SearchEngine.values has Google first', () {
      expect(SearchEngine.values.first, SearchEngine.google);
    });
  });

  group('OnboardingScreen 4-step flow', () {
    setUp(() async {
      await SearchEngineSettingsService.instance.updateSettings(
        (cur) => cur.copyWith(defaultEngine: SearchEngine.google),
      );
    });

    testWidgets('walks through all 4 steps and persists selected search engine', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pumpAndSettle();

      // Step 1: Welcome
      expect(find.text('Dab Browser'), findsOneWidget);
      expect(find.text('uBlock Origin built-in'), findsOneWidget);
      expect(find.text('Direct torrent downloads'), findsOneWidget);
      expect(find.text('YouTube downloader built-in'), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      // Step 2: Ad blocking
      expect(find.text('STEP 2 OF 4'), findsOneWidget);
      expect(find.text('Block ads & trackers'), findsOneWidget);
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // Step 3: Search engine (Google is first & default)
      expect(find.text('STEP 3 OF 4'), findsOneWidget);
      expect(find.text('Choose your default search'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('DuckDuckGo'), findsOneWidget);

      final googleY = tester.getTopLeft(find.text('Google')).dy;
      final ddgY = tester.getTopLeft(find.text('DuckDuckGo')).dy;
      expect(googleY, lessThan(ddgY));
      expect(SearchEngineSettingsService.instance.settings.defaultEngine, SearchEngine.google);

      // Select DuckDuckGo
      await tester.ensureVisible(find.text('DuckDuckGo'));
      await tester.tap(find.text('DuckDuckGo'));
      await tester.pumpAndSettle();
      expect(SearchEngineSettingsService.instance.settings.defaultEngine, SearchEngine.duckDuckGo);

      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: Finish setup summary
      expect(find.text("You're all set"), findsOneWidget);
      expect(find.text('Not enabled'), findsOneWidget);
      expect(find.text('DuckDuckGo'), findsOneWidget);
      expect(find.text('Start browsing'), findsOneWidget);
    });
  });
}
