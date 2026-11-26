import 'package:browser/features/browser/models/browser_page_error.dart';
import 'package:browser/features/browser/widgets/browser_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BrowserErrorView renders detailed message and Reload/Home actions', (tester) async {
    var reloaded = false;
    var wentHome = false;

    const err = BrowserPageError(
      uri: 'https://invalid.example.invalid/page',
      errorKey: 'UNKNOWN_HOST',
      categoryName: 'NETWORK',
      code: 35,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserErrorView(
            error: err,
            onReload: () => reloaded = true,
            onGoHome: () => wentHome = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("This site can't be reached"), findsOneWidget);
    expect(find.textContaining('invalid.example.invalid'), findsWidgets);
    expect(find.text('NETWORK · ERR_UNKNOWN_HOST (35)'), findsOneWidget);

    await tester.tap(find.text('Reload'));
    expect(reloaded, isTrue);

    await tester.tap(find.text('Back to Home'));
    expect(wentHome, isTrue);
  });

  testWidgets('BrowserErrorView shows Advanced -> Proceed anyway for security errors', (tester) async {
    var proceeded = false;

    const err = BrowserPageError(
      uri: 'https://selfsigned.example.com',
      errorKey: 'SECURITY_BAD_CERT',
      categoryName: 'SECURITY',
      code: 18,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowserErrorView(
            error: err,
            onReload: () {},
            onGoHome: () {},
            onProceedAnyway: () => proceeded = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Secure connection failed'), findsOneWidget);
    expect(find.text('Proceed anyway (unsafe)'), findsNothing);

    await tester.ensureVisible(find.text('Advanced'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    expect(find.text('Proceed anyway (unsafe)'), findsOneWidget);
    await tester.ensureVisible(find.text('Proceed anyway (unsafe)'));
    await tester.tap(find.text('Proceed anyway (unsafe)'));
    expect(proceeded, isTrue);
  });
}
