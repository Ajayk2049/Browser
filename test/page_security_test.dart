import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:browser/features/browser/services/site_permissions_service.dart';
import 'package:browser/features/browser/widgets/browser_address_bar.dart';
import 'package:browser/features/browser/widgets/page_security_sheet.dart';

void main() {
  setUp(() {
    SitePermissionsService.instance.setPermissionsForTesting({});
  });

  group('SitePermissionsService', () {
    test('isAllowed returns false by default, updates on setPermission, and clears on reset', () async {
      expect(SitePermissionsService.instance.isAllowed('thehindu.com', 'location'), isFalse);

      await SitePermissionsService.instance.setPermission('thehindu.com', 'location', true);
      expect(SitePermissionsService.instance.isAllowed('thehindu.com', 'location'), isTrue);

      await SitePermissionsService.instance.resetPermissions('thehindu.com');
      expect(SitePermissionsService.instance.isAllowed('thehindu.com', 'location'), isFalse);
    });
  });

  group('PageSecuritySheet Widget', () {
    Widget buildTestable(Widget child) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders security info, certifier, and displays empty state when no permissions granted', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const PageSecuritySheet(
            url: 'https://thehindu.com',
            title: 'The Hindu',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Host & Security
      expect(find.text('thehindu.com'), findsOneWidget);
      expect(find.text('Connection is secure'), findsOneWidget);
      expect(find.text('Certificate Information'), findsOneWidget);
      expect(find.textContaining('Certifier:'), findsOneWidget);
      expect(find.text('Protocol: TLS 1.3 (AES-256-GCM)'), findsOneWidget);

      // Verify no permissions are displayed by default
      expect(find.text('No permissions granted to this site'), findsOneWidget);
      expect(find.text('Microphone'), findsNothing);
      expect(find.text('Camera'), findsNothing);
      expect(find.text('Location Access'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets('shows only explicitly allowed permissions and revokes on toggle', (tester) async {
      // Explicitly allow ONLY microphone beforehand
      await SitePermissionsService.instance.setPermission('thehindu.com', 'microphone', true);

      await tester.pumpWidget(
        buildTestable(
          const PageSecuritySheet(
            url: 'https://thehindu.com',
            title: 'The Hindu',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ONLY microphone is displayed
      expect(find.text('Microphone'), findsOneWidget);
      expect(find.text('Camera'), findsNothing);
      expect(find.text('Location Access'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('No permissions granted to this site'), findsNothing);

      // Toggle off the microphone switch to revoke
      final micSwitchFinder = find.widgetWithText(SwitchListTile, 'Microphone');
      expect(micSwitchFinder, findsOneWidget);
      await tester.tap(micSwitchFinder);
      await tester.pumpAndSettle();

      expect(SitePermissionsService.instance.isAllowed('thehindu.com', 'microphone'), isFalse);
      expect(find.text('No permissions granted to this site'), findsOneWidget);
      expect(find.text('Microphone'), findsNothing);
    });

    testWidgets('renders Dab Browser internal page security when on home screen', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const PageSecuritySheet(
            url: 'Welcome to Dab Browser',
            title: 'Explore & Discover',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dab Browser'), findsOneWidget);
      expect(find.text('Connection is secure'), findsOneWidget);
      expect(find.textContaining('Google Antigravity Trust Root'), findsOneWidget);
    });
  });

  group('BrowserAddressBar Lock Icon', () {
    testWidgets('tapping lock icon invokes onOpenPageInfo callback', (tester) async {
      var lockTapped = false;
      final controller = TextEditingController(text: 'https://thehindu.com');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrowserAddressBar(
              controller: controller,
              onSubmitted: (_) {},
              onReload: () {},
              onOpenMediaGrabber: () {},
              onOpenPageInfo: () => lockTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find lock icon and tap it
      await tester.tap(find.byIcon(PhosphorIcons.lockSimple));
      await tester.pumpAndSettle();

      expect(lockTapped, isTrue);
    });
  });
}

