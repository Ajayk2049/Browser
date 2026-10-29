import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:browser/app.dart';

void main() {
  testWidgets('App root initializes properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BrowserApp(),
      ),
    );
    expect(find.byType(BrowserApp), findsOneWidget);
  });
}
