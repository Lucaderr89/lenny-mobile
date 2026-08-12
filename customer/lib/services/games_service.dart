import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import '../models/food_swipe_card.dart';

/// Service per gestire le API dei minigiochi
class GamesService {
  final String baseUrl = AppConstants.apiUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// GET /api/games/piatto-segreto/oggi
  /// Il gioco giornaliero: segreto del giorno, indizi e 12 candidati.
  /// Ritorna la mappa data (date, secret_dish_id, clues, candidates) o null.
  Future<Map<String, dynamic>?> getPiattoSegretoOggi() async {
    try {
      final uri = Uri.parse('$baseUrl/games/piatto-segreto/oggi');
      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Map<String, dynamic>.from(data['data'] as Map);
        }
      }
      return null;
    } catch (e) {
      print('❌ [PIATTO_SEGRETO] Errore: $e');
      return null;
    }
  }

  /// GET /api/games/prezzo-giusto/round
  /// Un piatto vero con foto e prezzo per la stima. Null in caso di errore.
  Future<Map<String, dynamic>?> getPrezzoGiustoRound() async {
    try {
      final uri = Uri.parse('$baseUrl/games/prezzo-giusto/round');
      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data']?['dish'] != null) {
          return Map<String, dynamic>.from(data['data']['dish'] as Map);
        }
      }
      return null;
    } catch (e) {
      print('❌ [PREZZO_GIUSTO] Errore: $e');
      return null;
    }
  }

  /// GET /api/games/food-swipe/cards
  /// Recupera 20-30 piatti per il gioco Food Swipe
  Future<List<FoodSwipeCard>> getFoodSwipeCards() async {
    try {
      final uri = Uri.parse('$baseUrl/games/food-swipe/cards');

      print('❤️ [FOOD_SWIPE] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('❤️ [FOOD_SWIPE] Status: ${response.statusCode}');
      print('❤️ [FOOD_SWIPE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> cards = data['data']['cards'] as List<dynamic>;
          return cards
              .map(
                (json) => FoodSwipeCard.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
      }

      // Fallback: se non ci sono piatti o errore, ritorna lista vuota
      return [];
    } catch (e) {
      print('❌ [FOOD_SWIPE] Errore: $e');
      return [];
    }
  }
}
