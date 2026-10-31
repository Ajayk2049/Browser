import 'package:flutter_test/flutter_test.dart';
import 'package:browser/features/browser/models/search_engine.dart';
import 'package:browser/features/browser/utils/url_helper.dart';

void main() {
  group('UrlHelper.resolveInput', () {
    test('routes plain terms and multi-word terms to DuckDuckGo search', () {
      expect(
        UrlHelper.resolveInput('flutter state management', SearchEngine.duckDuckGo),
        'https://duckduckgo.com/?q=flutter%20state%20management',
      );
      expect(
        UrlHelper.resolveInput('apple', SearchEngine.duckDuckGo),
        'https://duckduckgo.com/?q=apple',
      );
      expect(
        UrlHelper.resolveInput('how to bake sourdough', SearchEngine.duckDuckGo),
        'https://duckduckgo.com/?q=how%20to%20bake%20sourdough',
      );
    });

    test('routes plain terms and multi-word terms to Google search', () {
      expect(
        UrlHelper.resolveInput('flutter state management', SearchEngine.google),
        'https://www.google.com/search?q=flutter%20state%20management',
      );
      expect(
        UrlHelper.resolveInput('apple', SearchEngine.google),
        'https://www.google.com/search?q=apple',
      );
    });

    test('preserves explicit schemes', () {
      expect(
        UrlHelper.resolveInput('https://github.com', SearchEngine.duckDuckGo),
        'https://github.com',
      );
      expect(
        UrlHelper.resolveInput('http://example.org/test', SearchEngine.google),
        'http://example.org/test',
      );
      expect(
        UrlHelper.resolveInput('magnet:?xt=urn:btih:123', SearchEngine.duckDuckGo),
        'magnet:?xt=urn:btih:123',
      );
    });

    test('prepends https to domain names without scheme', () {
      expect(
        UrlHelper.resolveInput('github.com', SearchEngine.duckDuckGo),
        'https://github.com',
      );
      expect(
        UrlHelper.resolveInput('sub.domain.co.uk/path?arg=1', SearchEngine.google),
        'https://sub.domain.co.uk/path?arg=1',
      );
      expect(
        UrlHelper.resolveInput('flutter.dev', SearchEngine.duckDuckGo),
        'https://flutter.dev',
      );
    });

    test('resolves localhost and IP addresses', () {
      expect(
        UrlHelper.resolveInput('localhost:3000', SearchEngine.duckDuckGo),
        'http://localhost:3000',
      );
      expect(
        UrlHelper.resolveInput('192.168.1.1:8080', SearchEngine.google),
        'http://192.168.1.1:8080',
      );
    });
  });

  group('UrlHelper.isDownloadable', () {
    test('identifies downloadable extensions and magnet links', () {
      expect(UrlHelper.isDownloadable('https://example.com/file.apk'), isTrue);
      expect(UrlHelper.isDownloadable('https://example.com/archive.zip'), isTrue);
      expect(UrlHelper.isDownloadable('magnet:?xt=urn:btih:xyz'), isTrue);
      expect(UrlHelper.isDownloadable('https://example.com/page.html'), isFalse);
    });
  });
}

