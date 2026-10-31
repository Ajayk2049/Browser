import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:browser/features/browser/models/home_content_item.dart';
import 'package:browser/features/browser/screens/bookmarks_screen.dart';
import 'package:browser/features/browser/services/bookmarks_service.dart';

void main() {
  setUp(() {
    BookmarksService.instance.setBookmarksForTesting([]);
  });

  group('BookmarkItem JSON', () {
    test('serializes and deserializes correctly', () {
      const item = BookmarkItem(
        id: 'bm-1',
        title: 'Flutter Dev',
        url: 'https://flutter.dev',
        subtitle: 'flutter.dev',
      );
      final json = item.toJson();
      final restored = BookmarkItem.fromJson(json);

      expect(restored.id, 'bm-1');
      expect(restored.title, 'Flutter Dev');
      expect(restored.url, 'https://flutter.dev');
      expect(restored.subtitle, 'flutter.dev');
    });
  });

  group('BookmarksService', () {
    test('isBookmarked normalizes trailing slashes and casing', () {
      BookmarksService.instance.setBookmarksForTesting([
        const BookmarkItem(
          id: '1',
          title: 'Google',
          url: 'https://google.com/',
          subtitle: 'google.com',
        ),
      ]);

      expect(BookmarksService.instance.isBookmarked('https://google.com'), isTrue);
      expect(BookmarksService.instance.isBookmarked('HTTPS://GOOGLE.COM/'), isTrue);
      expect(BookmarksService.instance.isBookmarked('https://bing.com'), isFalse);
    });

    test('removeBookmark removes by id', () async {
      BookmarksService.instance.setBookmarksForTesting([
        const BookmarkItem(id: '1', title: 'A', url: 'https://a.com', subtitle: 'a.com'),
        const BookmarkItem(id: '2', title: 'B', url: 'https://b.com', subtitle: 'b.com'),
      ]);

      await BookmarksService.instance.removeBookmark('1');
      expect(BookmarksService.instance.count, 1);
      expect(BookmarksService.instance.bookmarks.first.id, '2');
    });

    test('clearAll empties bookmarks list', () async {
      BookmarksService.instance.setBookmarksForTesting([
        const BookmarkItem(id: '1', title: 'A', url: 'https://a.com', subtitle: 'a.com'),
      ]);

      await BookmarksService.instance.clearAll();
      expect(BookmarksService.instance.count, 0);
    });

    test('home page cannot be bookmarked', () async {
      expect(BookmarksService.instance.isBookmarked('Welcome to Dab Browser'), isFalse);
      expect(BookmarksService.instance.isBookmarked('dab.app/home'), isFalse);

      final added = await BookmarksService.instance.toggleBookmark(
        url: 'Welcome to Dab Browser',
        title: 'Home',
      );
      expect(added, isFalse);
      expect(BookmarksService.instance.count, 0);
    });
  });

  group('BookmarksScreen Widget', () {
    Widget buildTestable(Widget child) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: child,
      );
    }

    testWidgets('renders clean empty state when no bookmarks are present', (tester) async {
      BookmarksService.instance.setBookmarksForTesting([]);

      await tester.pumpWidget(buildTestable(const BookmarksScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('No bookmarks yet'), findsOneWidget);
      expect(find.text('Tap the star button in the address bar to save pages here for easy access.'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.bookmarkSimple), findsOneWidget);
    });

    testWidgets('renders saved bookmarks list and removes item on trash tap', (tester) async {
      BookmarksService.instance.setBookmarksForTesting([
        const BookmarkItem(
          id: 'bm-test-1',
          title: 'Dart Language',
          url: 'https://dart.dev',
          subtitle: 'dart.dev',
        ),
      ]);

      await tester.pumpWidget(buildTestable(const BookmarksScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Dart Language'), findsOneWidget);
      expect(find.text('dart.dev'), findsOneWidget);

      // Tap remove button on the bookmark tile
      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('No bookmarks yet'), findsOneWidget);
    });

    testWidgets('tapping bookmark pops screen with selected url', (tester) async {
      BookmarksService.instance.setBookmarksForTesting([
        const BookmarkItem(
          id: 'bm-pop-1',
          title: 'The Hindu',
          url: 'https://thehindu.com',
          subtitle: 'thehindu.com',
        ),
      ]);

      String? returnedUrl;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                returnedUrl = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('The Hindu'), findsOneWidget);
      await tester.tap(find.text('The Hindu'));
      await tester.pumpAndSettle();

      expect(returnedUrl, 'https://thehindu.com');
    });
  });
}

