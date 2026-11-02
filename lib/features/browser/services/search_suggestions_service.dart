import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/search_engine.dart';
import 'history_service.dart';
import 'bookmarks_service.dart';

/// Item representing a search suggestion or local URL match.
class SearchSuggestionItem {
  final String text;
  final String? subtitle;
  final bool isUrl;

  const SearchSuggestionItem({
    required this.text,
    this.subtitle,
    this.isUrl = false,
  });
}

/// Service providing live as-you-type search suggestions via HTTP and local history/bookmarks.
/// Complies with rules.md §13, §29.2 (< 200 lines).
class SearchSuggestionsService {
  static final SearchSuggestionsService instance = SearchSuggestionsService._internal();

  SearchSuggestionsService._internal();

  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

  Future<List<SearchSuggestionItem>> getSuggestions(String query, SearchEngine engine) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final lower = q.toLowerCase();
    final results = <SearchSuggestionItem>[];

    // 1. Local history & bookmark matching (instant offline feedback)
    for (final b in BookmarksService.instance.bookmarks) {
      if (b.title.toLowerCase().contains(lower) || b.url.toLowerCase().contains(lower)) {
        results.add(SearchSuggestionItem(text: b.title, subtitle: b.url, isUrl: true));
        if (results.length >= 2) break;
      }
    }

    for (final h in HistoryService.instance.items) {
      if (h.title.toLowerCase().contains(lower) || h.url.toLowerCase().contains(lower)) {
        if (!results.any((r) => r.subtitle == h.url)) {
          results.add(SearchSuggestionItem(text: h.title, subtitle: h.url, isUrl: true));
          if (results.length >= 3) break;
        }
      }
    }

    // 2. Fetch live suggestions from search engine
    try {
      final uri = _buildSuggestionUri(q, engine);
      if (uri != null) {
        final request = await _client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
        final response = await request.close().timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final webSuggestions = _parseSuggestions(body);
          for (final ws in webSuggestions) {
            if (!results.any((r) => r.text.toLowerCase() == ws.text.toLowerCase())) {
              results.add(ws);
            }
            if (results.length >= 6) break;
          }
        }
      }
    } catch (e) {
      debugPrint('SearchSuggestionsService error: $e');
    }

    return results;
  }

  Uri? _buildSuggestionUri(String query, SearchEngine engine) {
    final enc = Uri.encodeComponent(query);
    switch (engine) {
      case SearchEngine.google:
      case SearchEngine.custom:
        return Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&q=$enc');
      case SearchEngine.duckDuckGo:
        return Uri.parse('https://duckduckgo.com/ac/?q=$enc&type=list');
      case SearchEngine.bing:
        return Uri.parse('https://api.bing.com/osjson.aspx?query=$enc');
      case SearchEngine.brave:
        return Uri.parse('https://search.brave.com/api/suggest?q=$enc');
      case SearchEngine.startpage:
        return Uri.parse('https://www.startpage.com/suggestions?q=$enc');
    }
  }

  List<SearchSuggestionItem> _parseSuggestions(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List && decoded.length >= 2 && decoded[1] is List) {
        final list = decoded[1] as List;
        return list.take(6).map((item) {
          final str = item is Map ? (item['phrase'] ?? item.toString()) : item.toString();
          return SearchSuggestionItem(text: str.toString(), isUrl: false);
        }).toList();
      }
    } catch (_) {}
    return const [];
  }
}
