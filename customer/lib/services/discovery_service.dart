import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import '../models/discover_content.dart';
import '../models/trending_dish.dart';
import '../models/food_event.dart';
import '../models/weather_suggestion.dart';

/// Service per gestire le API della tab Scopri
class DiscoveryService {
  final String baseUrl = AppConstants.apiUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Recupera suggerimento meteo intelligente
  Future<WeatherSuggestion?> getWeatherSuggestion() async {
    try {
      final uri = Uri.parse('$baseUrl/discovery/weather');

      print('🌤️ [WEATHER] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return WeatherSuggestion.fromJson(
            data['data'] as Map<String, dynamic>,
          );
        }
      }
      return null;
    } catch (e) {
      print('❌ [WEATHER] Errore: $e');
      return null;
    }
  }

  /// Recupera piatti trending (popolare ora)
  Future<List<TrendingDish>> getTrendingDishes() async {
    try {
      final uri = Uri.parse('$baseUrl/discovery/trending');

      print('🔥 [TRENDING] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> items = data['data'] as List<dynamic>;
          return items
              .map(
                (json) => TrendingDish.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ [TRENDING] Errore: $e');
      return [];
    }
  }

  /// Recupera contenuti Giallo Zafferano aggregati
  Future<List<DiscoveryContent>> getGialloZafferanoContent() async {
    try {
      final uri = Uri.parse('$baseUrl/discovery/giallo-zafferano');

      print('📚 [GIALLO_ZAFFERANO] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final items = data['data'] as List<dynamic>;
          return items
              .map(
                (json) =>
                    DiscoveryContent.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ [GIALLO_ZAFFERANO] Errore: $e');
      return [];
    }
  }

  /// Recupera evento/tema del giorno
  Future<FoodEvent?> getTodayEvent() async {
    try {
      final uri = Uri.parse('$baseUrl/discovery/event');

      print('📅 [EVENT] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return FoodEvent.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      print('❌ [EVENT] Errore: $e');
      return null;
    }
  }

  /// Recupera domanda quiz random per "Indovina il Piatto"
  Future<Map<String, dynamic>?> getQuizQuestion() async {
    try {
      final uri = Uri.parse('$baseUrl/discovery/quiz');

      print('🎯 [QUIZ] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('❌ [QUIZ] Errore: $e');
      return null;
    }
  }
}
