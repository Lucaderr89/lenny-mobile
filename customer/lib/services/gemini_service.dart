import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/menu_item.dart';

/// Servizio per gestire le chiamate API all'assistente AI (Google Gemini)
class GeminiService {
  final String baseUrl = AppConstants.apiUrl;

  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyApiToken) ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Invia un messaggio all'assistente AI
  /// [lat] / [lng]  — posizione utente (0 = non disponibile)
  /// [conversationHistory] — ultimi messaggi della chat per il multi-turn
  Future<AIResponse> sendMessage(
    String message, {
    double lat = 0,
    double lng = 0,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/chat'),
            headers: await _headers,
            body: jsonEncode({
              'message': message,
              'lat': lat,
              'lng': lng,
              'conversation_history': conversationHistory,
            }),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AIResponse.fromJson(json);
      } else {
        return AIResponse(
          success: false,
          message: json['message'] as String? ?? 'Errore comunicazione AI',
          status: 'error',
        );
      }
    } catch (e) {
      return AIResponse(
        success: false,
        message: 'Errore di connessione: $e',
        status: 'error',
      );
    }
  }

  /// Verifica lo stato di una richiesta in coda
  Future<AIResponse> checkQueueStatus(String requestId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/ai/queue-status/$requestId'),
            headers: await _headers,
          )
          .timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return AIResponse.fromJson(json);
      return AIResponse(success: false, message: 'Errore stato coda', status: 'error');
    } catch (e) {
      return AIResponse(success: false, message: 'Errore connessione', status: 'error');
    }
  }

  /// Recupera il dettaglio completo di un piatto con le sue personalizzazioni
  /// Usato prima di aprire il ProductDetailModal dalla chat
  Future<MenuItem?> getDishDetail(int dishId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/ai/dish/$dishId'),
            headers: await _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['success'] == true && json['data'] != null) {
          return MenuItem.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Piatti più ordinati (pulsante quick action)
  Future<Map<String, dynamic>> getTrendingDishes({int limit = 5}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/ai/trending-dishes?limit=$limit'),
            headers: await _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Errore recupero piatti'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

// ─── Modelli risposta ─────────────────────────────────────────────────────────

/// Risposta strutturata dall'AI
class AIResponse {
  final bool success;
  final String message;
  final String status; // 'ready', 'queued', 'error'
  final String action; // 'none', 'show_dishes', 'show_restaurants'
  final List<AIDish> dishes;
  final List<AIRestaurant> restaurants;
  // Campi coda
  final int? position;
  final int? estimatedWait;
  final String? requestId;

  AIResponse({
    required this.success,
    required this.message,
    required this.status,
    this.action = 'none',
    this.dishes = const [],
    this.restaurants = const [],
    this.position,
    this.estimatedWait,
    this.requestId,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    final rawDishes = json['dishes'];
    final rawRest   = json['restaurants'];

    return AIResponse(
      success:       json['success'] as bool? ?? false,
      message:       json['message'] as String? ?? '',
      status:        json['status'] as String? ?? 'error',
      action:        json['action'] as String? ?? 'none',
      dishes: rawDishes is List
          ? rawDishes.map((d) => AIDish.fromJson(d as Map<String, dynamic>)).toList()
          : [],
      restaurants: rawRest is List
          ? rawRest.map((r) => AIRestaurant.fromJson(r as Map<String, dynamic>)).toList()
          : [],
      position:      json['position'] as int?,
      estimatedWait: json['estimated_wait'] as int?,
      requestId:     json['request_id'] as String?,
    );
  }
}

/// Piatto suggerito dall'AI
class AIDish {
  final int id;
  final String name;
  final double price;
  final int restaurantId;
  final String restaurantName;
  final bool hasRequiredExtras;

  const AIDish({
    required this.id,
    required this.name,
    required this.price,
    required this.restaurantId,
    required this.restaurantName,
    required this.hasRequiredExtras,
  });

  factory AIDish.fromJson(Map<String, dynamic> json) => AIDish(
        id:                  json['id'] as int? ?? 0,
        name:                json['name'] as String? ?? '',
        price:               (json['price'] as num?)?.toDouble() ?? 0,
        restaurantId:        json['restaurant_id'] as int? ?? 0,
        restaurantName:      json['restaurant_name'] as String? ?? '',
        hasRequiredExtras:   json['has_required_extras'] as bool? ?? false,
      );
}

/// Ristorante suggerito dall'AI
class AIRestaurant {
  final int id;
  final String name;
  final double distanceKm;
  final String city;

  const AIRestaurant({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.city,
  });

  factory AIRestaurant.fromJson(Map<String, dynamic> json) => AIRestaurant(
        id:          json['id'] as int? ?? 0,
        name:        json['name'] as String? ?? '',
        distanceKm:  (json['distance_km'] as num?)?.toDouble() ?? 0,
        city:        json['city'] as String? ?? '',
      );
}
