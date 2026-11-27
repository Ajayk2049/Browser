import 'package:browser/features/browser/models/browser_context_element.dart';
import 'package:browser/features/browser/widgets/browser_context_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('Link-only context menu shows all link actions and returns selection', (tester) async {
    BrowserContextAction? result;
    const element = BrowserContextElement(
      baseUri: 'https://example.com',
      linkUri: 'https://example.com/article',
      textContent: 'Read Article',
    );

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await BrowserContextMenuSheet.show(context, element: element);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Open in new tab'), findsOneWidget);
    expect(find.text('Open in private tab'), findsOneWidget);
    expect(find.text('Copy link address'), findsOneWidget);
    expect(find.text('Copy link text'), findsOneWidget);
    expect(find.text('Download link'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Save image'), findsNothing);

    await tester.tap(find.text('Copy link address'));
    await tester.pumpAndSettle();

    expect(result, BrowserContextAction.copyLinkAddress);
  });

  testWidgets('Image-inside-link context menu shows both link and image sections', (tester) async {
    const element = BrowserContextElement(
      baseUri: 'https://example.com',
      linkUri: 'https://example.com/post',
      srcUri: 'data:image/png;base64,iVBORw0KGgo=',
      altText: 'Hero Photo',
      mediaType: BrowserContextMediaType.image,
    );

    await tester.pumpWidget(wrap(const BrowserContextMenuSheet(element: element)));

    expect(find.text('Hero Photo'), findsOneWidget);
    expect(find.text('Open in new tab'), findsOneWidget);
    expect(find.text('Copy link address'), findsOneWidget);
    expect(find.text('Open image in new tab'), findsOneWidget);
    expect(find.text('Save image'), findsOneWidget);
    expect(find.text('Copy image address'), findsOneWidget);
    expect(find.text('Share image'), findsOneWidget);
  });

  testWidgets('Video context menu shows video actions in private mode', (tester) async {
    const element = BrowserContextElement(
      baseUri: 'https://example.com',
      linkUri: 'https://example.com/watch',
      srcUri: 'https://cdn.example.com/clip.mp4',
      mediaType: BrowserContextMediaType.video,
    );

    await tester.pumpWidget(
      wrap(const BrowserContextMenuSheet(element: element, isPrivateMode: true)),
    );

    expect(find.text('Open in new private tab'), findsOneWidget);
    expect(find.text('Open in private tab'), findsNothing);
    expect(find.text('Open video in new tab'), findsOneWidget);
    expect(find.text('Save video'), findsOneWidget);
    expect(find.text('Copy video address'), findsOneWidget);
    expect(find.text('Share video'), findsOneWidget);
  });
}
