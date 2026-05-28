import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import '../models/restaurant.dart';

/// Service per gestire le chiamate API relative ai ristoranti
class RestaurantService {
  final String baseUrl = AppConstants.apiUrl;

  /// Headers comuni per le richieste
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Recupera lista ristoranti
  ///
  /// Parametri opzionali:
  /// - [categoryId] - Filtra per categoria ristorante
  /// - [cuisineId] - Filtra per tipo cucina
  /// - [featured] - Solo ristoranti in evidenza
  /// - [search] - Cerca per nome
  /// - [orderBy] - Ordinamento: 'name' (default) o 'updated_at' (novità)
  Future<List<Restaurant>> getRestaurants({
    int? categoryId,
    int? cuisineId,
    bool? featured,
    String? search,
    String? orderBy,
  }) async {
    try {
      // Costruisci URL con parametri
      final queryParams = <String, String>{};
      if (categoryId != null) {
        queryParams['category_id'] = categoryId.toString();
      }
      if (cuisineId != null) queryParams['cuisine_id'] = cuisineId.toString();
      if (featured != null) queryParams['featured'] = featured.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (orderBy != null && orderBy.isNotEmpty) {
        queryParams['order_by'] = orderBy;
      }

      final uri = Uri.parse(
        '$baseUrl/restaurants',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      print('🍕 [RESTAURANTS] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [RESTAURANTS] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          // La risposta è paginata: data['data'] contiene 'items' e 'pagination'
          final responseData = data['data'];
          final List<dynamic> restaurantsJson = responseData is Map
              ? (responseData['items'] as List<dynamic>)
              : responseData as List<dynamic>;

          final restaurants = restaurantsJson
              .map((json) => Restaurant.fromJson(json as Map<String, dynamic>))
              .toList();

          print('✅ [RESTAURANTS] Caricati ${restaurants.length} ristoranti');
          return restaurants;
        } else {
          print('⚠️ [RESTAURANTS] Risposta non valida');
          return [];
        }
      } else {
        print(
          '❌ [RESTAURANTS] Errore ${response.statusCode}: ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('❌ [RESTAURANTS] Eccezione: $e');
      return [];
    }
  }

  /// Recupera dettaglio completo di un ristorante
  Future<Restaurant?> getRestaurantDetail(int restaurantId) async {
    try {
      final uri = Uri.parse('$baseUrl/restaurants/detail?id=$restaurantId');

      print('🍕 [RESTAURANT_DETAIL] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [RESTAURANT_DETAIL] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return Restaurant.fromJson(data['data'] as Map<String, dynamic>);
        } else {
          print('⚠️ [RESTAURANT_DETAIL] Ristorante non trovato');
          return null;
        }
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Errore nel caricamento del ristorante');
      }
    } catch (e) {
      print('❌ [RESTAURANT_DETAIL] Errore: $e');
      throw Exception('Impossibile recuperare il ristorante: $e');
    }
  }

  /// Recupera menu completo di un ristorante con categorie
  ///
  /// [restaurantId] - ID del ristorante
  /// [categoryId] - Opzionale: filtra per categoria di piatti
  Future<Map<String, dynamic>> getRestaurantMenu(
    int restaurantId, {
    int? categoryId,
  }) async {
    try {
      final queryParams = <String, String>{'id': restaurantId.toString()};
      if (categoryId != null) {
        queryParams['category_id'] = categoryId.toString();
      }

      final uri = Uri.parse(
        '$baseUrl/restaurants/menu',
      ).replace(queryParameters: queryParams);

      print('🍕 [RESTAURANT_MENU] Chiamata API: $uri');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [RESTAURANT_MENU] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          // L'API ora restituisce direttamente l'array di categorie in data
          final List<dynamic> categoriesJson = data['data'] is List
              ? data['data'] as List<dynamic>
              : (data['data'] as Map<String, dynamic>)['categories'] ?? [];

          final categories = categoriesJson.map((catJson) {
            final cat = catJson as Map<String, dynamic>;

            return {
              'id': cat['id'],
              'name': cat['name'],
              'dishes':
                  cat['dishes'] ??
                  [], // Mantieni come Map, non convertire in MenuItem qui
            };
          }).toList();

          print('✅ [RESTAURANT_MENU] Caricate ${categories.length} categorie');

          return {
            'categories': categories,
            'total_dishes': categories.fold<int>(
              0,
              (sum, cat) => sum + ((cat['dishes'] as List).length),
            ),
          };
        } else {
          print('⚠️ [RESTAURANT_MENU] Menu non disponibile');
          return {'categories': [], 'total_dishes': 0};
        }
      } else {
        throw Exception('Errore nel caricamento del menu');
      }
    } catch (e) {
      print('❌ [RESTAURANT_MENU] Errore: $e');
      throw Exception('Impossibile recuperare il menu: $e');
    }
  }

  /// Recupera ristoranti in evidenza per home
  Future<List<Restaurant>> getFeaturedRestaurants({int? cuisineId}) async {
    return getRestaurants(featured: true, cuisineId: cuisineId);
  }

  /// Recupera ristoranti recentemente aggiornati (novità)
  Future<List<Restaurant>> getNewRestaurants({int? cuisineId}) async {
    return getRestaurants(orderBy: 'updated_at', cuisineId: cuisineId);
  }

  /// Cerca ristoranti per nome
  Future<List<Restaurant>> searchRestaurants(String query) async {
    if (query.length < 2) return [];
    return getRestaurants(search: query);
  }

  /// Ottiene le regole di consegna per un singolo ristorante
  /// Usa l'endpoint esistente /api/delivery/calculate-fee
  Future<Map<String, dynamic>?> getDeliveryZoneRule({
    required int restaurantId,
    String? postalCode,
    double? latitude,
    double? longitude,
    double subtotal = 0.0,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'restaurant_id': restaurantId,
        'subtotal': subtotal,
      };

      if (postalCode != null && postalCode.isNotEmpty) {
        requestBody['postal_code'] = postalCode;
      }

      if (latitude != null && longitude != null) {
        requestBody['latitude'] = latitude;
        requestBody['longitude'] = longitude;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/delivery/calculate-fee'),
            headers: _headers,
            body: json.encode(requestBody),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
