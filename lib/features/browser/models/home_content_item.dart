import 'package:flutter/material.dart';

/// Represents a quick shortcut link on the browser home screen.
/// Complies with rules.md §13, §29.1, and §29.2 (< 200 lines).
class QuickLink {
  final String id;
  final String title;
  final String url;
  final String letter;
  final Color? color;

  const QuickLink({
    required this.id,
    required this.title,
    required this.url,
    required this.letter,
    this.color,
  });

  bool get isAddButton => url.isEmpty;

  static const List<QuickLink> defaults = [
    QuickLink(id: 'google', title: 'Google', url: 'https://www.google.com', letter: 'G'),
    QuickLink(id: 'linear', title: 'Linear', url: 'https://linear.app', letter: 'L'),
    QuickLink(id: 'figma', title: 'Figma', url: 'https://www.figma.com', letter: 'F'),
    QuickLink(id: 'add', title: 'Add', url: '', letter: '+'),
  ];
}

/// Represents a bookmark or saved offline reading item.
/// Complies with rules.md §13, §29.1, and §29.2 (< 200 lines).
class BookmarkItem {
  final String id;
  final String title;
  final String url;
  final String subtitle;
  final bool isSavedPage;

  const BookmarkItem({
    required this.id,
    required this.title,
    required this.url,
    required this.subtitle,
    this.isSavedPage = false,
  });

  static const List<BookmarkItem> defaultBookmarks = [
    BookmarkItem(
      id: 'bm-1',
      title: 'Frontend Design Inspirations',
      url: 'https://dribbble.com',
      subtitle: 'dribbble.com',
    ),
    BookmarkItem(
      id: 'bm-2',
      title: 'AI Agent Architecture Docs',
      url: 'https://arxiv.org',
      subtitle: 'arxiv.org',
    ),
  ];

  static const List<BookmarkItem> defaultSavedPages = [
    BookmarkItem(
      id: 'sp-1',
      title: 'Next-Gen Browser Engine Specs',
      url: 'https://developer.mozilla.org',
      subtitle: '5 min read',
      isSavedPage: true,
    ),
    BookmarkItem(
      id: 'sp-2',
      title: 'Modern CSS & Micro-interactions',
      url: 'https://web.dev',
      subtitle: '3 min read',
      isSavedPage: true,
    ),
  ];
}
