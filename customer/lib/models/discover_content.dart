/// Modello per contenuti discovery (Giallo Zafferano, eventi, ecc.)
class DiscoveryContent {
  final String type; // 'recipe', 'news', 'video', 'event'
  final String category; // 'featured', 'quick', 'dessert', 'food_news', etc.
  final String title;
  final String description;
  final String? imageUrl;
  final String? sourceUrl;
  final String source; // 'Giallo Zafferano', 'System', etc.
  final String? badge; // '⭐ Del Giorno', '⚡ Veloce', etc.
  final DateTime? publishedAt;

  DiscoveryContent({
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    this.imageUrl,
    this.sourceUrl,
    required this.source,
    this.badge,
    this.publishedAt,
  });

  factory DiscoveryContent.fromJson(Map<String, dynamic> json) {
    return DiscoveryContent(
      type: json['type'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String?,
      sourceUrl: json['source_url'] as String?,
      source: json['source'] as String,
      badge: json['badge'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
    );
  }
}
