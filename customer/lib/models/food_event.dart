/// Modello per eventi food e temi giornalieri
class FoodEvent {
  final String icon;
  final String title;
  final String description;
  final String type; // 'real_event', 'weekly_theme', 'seasonal'
  final List<String>? suggestions; // Nomi piatti/categorie
  final List<int>? cuisineIds; // IDs cucine correlate
  final String? actionText; // Testo CTA
  final String? backgroundColor; // Hex color per gradiente

  FoodEvent({
    required this.icon,
    required this.title,
    required this.description,
    required this.type,
    this.suggestions,
    this.cuisineIds,
    this.actionText,
    this.backgroundColor,
  });

  factory FoodEvent.fromJson(Map<String, dynamic> json) {
    return FoodEvent(
      icon: json['icon'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      suggestions: json['suggestions'] != null
          ? List<String>.from(json['suggestions'] as List)
          : null,
      cuisineIds: json['cuisine_ids'] != null
          ? List<int>.from(json['cuisine_ids'] as List)
          : null,
      actionText: json['action_text'] as String?,
      backgroundColor: json['background_color'] as String?,
    );
  }
}
