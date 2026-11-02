import 'package:flutter/material.dart';

/// Represents a bookmark folder.
class BookmarkFolder {
  final String id;
  final String title;
  final IconData? icon;

  const BookmarkFolder({
    required this.id,
    required this.title,
    this.icon,
  });

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  factory BookmarkFolder.fromJson(Map<String, dynamic> json) => BookmarkFolder(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

/// Represents a user-saved bookmark.
/// Serializes to/from JSON for persistent local disk storage.
/// Complies with rules.md §13, §29.1, and §29.2 (< 200 lines).
class BookmarkItem {
  final String id;
  final String title;
  final String url;
  final String subtitle;
  final String folderId;
  final bool isSavedPage;

  const BookmarkItem({
    required this.id,
    required this.title,
    required this.url,
    required this.subtitle,
    this.folderId = 'bookmarks_bar',
    this.isSavedPage = false,
  });

  BookmarkItem copyWith({
    String? id,
    String? title,
    String? url,
    String? subtitle,
    String? folderId,
    bool? isSavedPage,
  }) =>
      BookmarkItem(
        id: id ?? this.id,
        title: title ?? this.title,
        url: url ?? this.url,
        subtitle: subtitle ?? this.subtitle,
        folderId: folderId ?? this.folderId,
        isSavedPage: isSavedPage ?? this.isSavedPage,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'subtitle': subtitle,
        'folderId': folderId,
        'isSavedPage': isSavedPage,
      };

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        folderId: json['folderId'] as String? ?? 'bookmarks_bar',
        isSavedPage: json['isSavedPage'] as bool? ?? false,
      );
}

/// Represents a quick shortcut link on the browser home screen.
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
        letter: json['letter'] as String? ??
            (json['title'] is String && (json['title'] as String).isNotEmpty
                ? (json['title'] as String)[0].toUpperCase()
                : '?'),
        iconUrl: json['iconUrl'] as String?,
      );

  static const List<QuickLink> defaults = [
    QuickLink(id: 'google', title: 'Google', url: 'https://www.google.com', letter: 'G'),
    QuickLink(id: 'linear', title: 'Linear', url: 'https://linear.app', letter: 'L'),
    QuickLink(id: 'figma', title: 'Figma', url: 'https://www.figma.com', letter: 'F'),
  ];
}
