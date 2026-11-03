/// Model representing an installed or marketplace WebExtension.
/// Complies with rules.md §13, §29.1, §29.2 (< 200 lines).
class WebExtensionItem {
  final String id;
  final String name;
  final String version;
  final String description;
  final String category;
  final double rating;
  final String reviewsCount;
  final String downloadUrl;
  final String optionsPageUrl;
  final bool isInstalled;
  final bool isEnabled;

  const WebExtensionItem({
    required this.id,
    required this.name,
    this.version = '',
    this.description = '',
    this.category = 'General',
    this.rating = 5.0,
    this.reviewsCount = '',
    this.downloadUrl = '',
    this.optionsPageUrl = '',
    this.isInstalled = false,
    this.isEnabled = true,
  });

  WebExtensionItem copyWith({
    String? id,
    String? name,
    String? version,
    String? description,
    String? category,
    double? rating,
    String? reviewsCount,
    String? downloadUrl,
    String? optionsPageUrl,
    bool? isInstalled,
    bool? isEnabled,
  }) {
    return WebExtensionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      optionsPageUrl: optionsPageUrl ?? this.optionsPageUrl,
      isInstalled: isInstalled ?? this.isInstalled,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  factory WebExtensionItem.fromNativeMap(Map<dynamic, dynamic> map) {
    return WebExtensionItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      version: map['version'] as String? ?? '',
      description: map['description'] as String? ?? '',
      optionsPageUrl: map['optionsPageUrl'] as String? ?? '',
      isInstalled: true,
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'category': category,
        'rating': rating,
        'reviewsCount': reviewsCount,
        'downloadUrl': downloadUrl,
        'optionsPageUrl': optionsPageUrl,
        'isInstalled': isInstalled,
        'isEnabled': isEnabled,
      };

  factory WebExtensionItem.fromJson(Map<String, dynamic> json) => WebExtensionItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        reviewsCount: json['reviewsCount'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
        optionsPageUrl: json['optionsPageUrl'] as String? ?? '',
        isInstalled: json['isInstalled'] as bool? ?? false,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );
}

