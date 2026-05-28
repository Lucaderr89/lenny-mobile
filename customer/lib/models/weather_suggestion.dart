/// Modello per suggerimenti meteo
class WeatherSuggestion {
  final String icon;
  final String condition; // 'sunny', 'rain', 'cloudy', 'cold', 'hot'
  final double temperature;
  final String title;
  final String subtitle;
  final List<String> suggestions; // Nomi piatti/categorie
  final List<int> cuisineIds; // IDs cucine correlate

  WeatherSuggestion({
    required this.icon,
    required this.condition,
    required this.temperature,
    required this.title,
    required this.subtitle,
    required this.suggestions,
    required this.cuisineIds,
  });

  factory WeatherSuggestion.fromJson(Map<String, dynamic> json) {
    return WeatherSuggestion(
      icon: json['icon'] as String,
      condition: '', // Non fornito dall'API, usa fallback
      temperature: (json['temperature'] as num).toDouble(),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      suggestions: List<String>.from(json['suggestions'] as List),
      cuisineIds: [], // Non fornito dall'API, usa lista vuota
    );
  }
}
