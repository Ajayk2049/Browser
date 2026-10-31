import 'package:flutter/material.dart';

/// Represents a quick shortcut link on the browser home screen.
/// Complies with rules.md §13, §29.1, and §29.2 (< 200 lines).
class QuickLink {
  final String id;
  final String title;
  final String url;
  final String letter;
  final String? iconUrl;
  final Color? color;

  const QuickLink({
    required this.id,
    required this.title,
    required this.url,
    required this.letter,
    this.iconUrl,
    this.color,
  });

  bool get isAddButton => url.isEmpty;

  /// High-resolution official website icon file URL.
  String get faviconUrl {
    if (iconUrl != null && iconUrl!.isNotEmpty) return iconUrl!;
    if (url.isEmpty) return '';
    final parsed = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    final host = parsed?.host.isNotEmpty == true ? parsed!.host : url;
    return 'https://www.google.com/s2/favicons?domain=$host&sz=128';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'letter': letter,
    if (iconUrl != null) 'iconUrl': iconUrl,
  };

  factory QuickLink.fromJson(Map<String, dynamic> json) => QuickLink(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    letter: json['letter'] as String? ?? (json['title'] is String && (json['title'] as String).isNotEmpty ? (json['title'] as String)[0].toUpperCase() : '?'),
    iconUrl: json['iconUrl'] as String?,
  );

  static const List<QuickLink> defaults = [
    QuickLink(id: 'google', title: 'Google', url: 'https://www.google.com', letter: 'G'),
    QuickLink(id: 'linear', title: 'Linear', url: 'https://linear.app', letter: 'L'),
    QuickLink(id: 'figma', title: 'Figma', url: 'https://www.figma.com', letter: 'F'),
  ];
}

/// Represents a user-saved bookmark.
/// Serializes to/from JSON for persistent local disk storage.
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'subtitle': subtitle,
    'isSavedPage': isSavedPage,
  };

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    isSavedPage: json['isSavedPage'] as bool? ?? false,
  );
}
