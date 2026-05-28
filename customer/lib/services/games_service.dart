import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import '../models/dish_match_dish.dart';
import '../models/food_swipe_card.dart';
import '../models/pizza_match_round.dart';
import '../models/recipe_scrambler_round.dart';

/// Service per gestire le API dei minigiochi
class GamesService {
  final String baseUrl = AppConstants.apiUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// GET /api/games/dish-match/round
  /// Recupera 4 piatti random per il gioco Dish Match
  Future<List<DishMatchDish>> getDishMatchRound() async {
    try {
      final uri = Uri.parse('$baseUrl/games/dish-match/round');

      print('🎯 [DISH_MATCH] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('🎯 [DISH_MATCH] Status: ${response.statusCode}');
      print('🎯 [DISH_MATCH] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> dishes = data['data']['dishes'] as List<dynamic>;
          return dishes
              .map(
                (json) => DishMatchDish.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
      }

      // Fallback: se non ci sono piatti o errore, ritorna lista vuota
      return [];
    } catch (e) {
      print('❌ [DISH_MATCH] Errore: $e');
      return [];
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

  /// GET /api/games/pizza-match/round
  /// Recupera una pizza con ingredienti per il gioco Pizza Match
  Future<PizzaMatchRound?> getPizzaMatchRound() async {
    try {
      final uri = Uri.parse('$baseUrl/games/pizza-match/round');

      print('🍕 [PIZZA_MATCH] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('🍕 [PIZZA_MATCH] Status: ${response.statusCode}');
      print('🍕 [PIZZA_MATCH] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return PizzaMatchRound.fromJson(data['data'] as Map<String, dynamic>);
        }
      }

      // Fallback: se errore, ritorna null
      return null;
    } catch (e) {
      print('❌ [PIZZA_MATCH] Errore: $e');
      return null;
    }
  }

  /// GET /api/games/recipe-scrambler/round
  /// Recupera un piatto con nome anagrammato per il gioco Recipe Scrambler
  Future<RecipeScramblerRound?> getRecipeScramblerRound() async {
    try {
      final uri = Uri.parse('$baseUrl/games/recipe-scrambler/round');

      print('📋 [RECIPE_SCRAMBLER] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📋 [RECIPE_SCRAMBLER] Status: ${response.statusCode}');
      print('📋 [RECIPE_SCRAMBLER] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return RecipeScramblerRound.fromJson(
            data['data'] as Map<String, dynamic>,
          );
        }
      }

      // Fallback: se errore, ritorna null
      return null;
    } catch (e) {
      print('❌ [RECIPE_SCRAMBLER] Errore: $e');
      return null;
    }
  }
}
