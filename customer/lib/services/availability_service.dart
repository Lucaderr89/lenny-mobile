import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/availability_data.dart';

/// Service per gestire le chiamate API di disponibilità
class AvailabilityService {
  final String baseUrl = AppConstants.apiUrl;

  /// Headers comuni per le richieste con API token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken) ?? '';

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': apiToken,
    };
  }

  /// Recupera la disponibilità per una data e ristorante specifici
  ///
  /// Parametri:
  /// - [date] - Data nel formato YYYY-MM-DD
  /// - [restaurantId] - ID del ristorante
  /// - [includeCategories] - Includi disponibilità categorie (default: true)
  /// - [includeDishes] - Includi disponibilità piatti (default: true)
  /// - [categoryId] - Opzionale: filtra categoria specifica
  /// - [dishId] - Opzionale: filtra piatto specifico
  Future<AvailabilityData?> getAvailability({
    required String date,
    required int restaurantId,
    bool includeCategories = true,
    bool includeDishes = true,
    int? categoryId,
    int? dishId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/availability/get-availability');

      final body = {
        'date': date,
        'restaurant_id': restaurantId,
        'include_categories': includeCategories,
        'include_dishes': includeDishes,
      };

      if (categoryId != null) {
        body['category_id'] = categoryId;
      }
      if (dishId != null) {
        body['dish_id'] = dishId;
      }

      print('📡 [AVAILABILITY] Richiesta: POST $uri');
      print('📋 [AVAILABILITY] Body: ${jsonEncode(body)}');

      final headers = await _getHeaders();
      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [AVAILABILITY] Status: ${response.statusCode}');
      print('📡 [AVAILABILITY] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final availabilityJson = data['data'] as Map<String, dynamic>;
          return AvailabilityData.fromJson(availabilityJson);
        } else {
          print(
            '⚠️ [AVAILABILITY] Risposta non valida: ${data['error'] ?? 'Unknown error'}',
          );
          return null;
        }
      } else if (response.statusCode == 404) {
        print('❌ [AVAILABILITY] Risorsa non trovata');
        return null;
      } else {
        print(
          '❌ [AVAILABILITY] Errore ${response.statusCode}: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('❌ [AVAILABILITY] Eccezione: $e');
      return null;
    }
  }

  /// Recupera solo la disponibilità del ristorante (senza categorie/piatti)
  Future<RestaurantAvailability?> getRestaurantAvailability({
    required String date,
    required int restaurantId,
  }) async {
    final availability = await getAvailability(
      date: date,
      restaurantId: restaurantId,
      includeCategories: false,
      includeDishes: false,
    );

    return availability?.restaurant;
  }

  /// Verifica se un piatto è disponibile in una data specifica
  /// Se time è specificato, verifica che l'orario cada in uno slot disponibile
  Future<bool> isDishAvailable({
    required String date,
    required int restaurantId,
    required int dishId,
    TimeOfDay? time,
  }) async {
    try {
      final availability = await getAvailability(
        date: date,
        restaurantId: restaurantId,
        dishId: dishId,
      );

      if (availability == null) return false;

      final dish = availability.getDishById(dishId);
      if (dish == null) return false;

      // Se non c'è orario specificato, verifica solo se esiste almeno uno slot disponibile
      if (time == null) {
        return dish.availableSlots.any((slot) => slot.available);
      }

      // Verifica se l'orario specificato cade in uno slot disponibile
      final timeMinutes = time.hour * 60 + time.minute;

      for (final slot in dish.availableSlots) {
        if (!slot.available) continue;

        final startTime = slot.startTime;
        final endTime = slot.endTime;

        if (startTime == null || endTime == null) continue;

        final startMinutes = startTime.hour * 60 + startTime.minute;
        final endMinutes = endTime.hour * 60 + endTime.minute;

        if (timeMinutes >= startMinutes && timeMinutes < endMinutes) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ [AVAILABILITY] Errore verifica piatto: $e');
      return false;
    }
  }

  /// Recupera il motivo di indisponibilità di un piatto
  Future<String?> getDishUnavailabilityReason({
    required String date,
    required int restaurantId,
    required int dishId,
  }) async {
    try {
      final availability = await getAvailability(
        date: date,
        restaurantId: restaurantId,
        dishId: dishId,
      );

      if (availability == null) return null;

      final dish = availability.getDishById(dishId);
      if (dish == null) return null;

      // Cerca primo slot non disponibile
      final unavailableSlot = dish.availableSlots.firstWhere(
        (slot) => !slot.available,
        orElse: () => TimeSlot(start: '', end: '', available: true),
      );

      return unavailableSlot.reason ?? 'Piatto non disponibile';
    } catch (e) {
      print('❌ [AVAILABILITY] Errore recupero motivo: $e');
      return null;
    }
  }

  /// Verifica se il ristorante è aperto in una data specifica
  Future<bool> isRestaurantOpen({
    required String date,
    required int restaurantId,
  }) async {
    try {
      final restaurant = await getRestaurantAvailability(
        date: date,
        restaurantId: restaurantId,
      );

      return restaurant?.isOpen ?? false;
    } catch (e) {
      print('❌ [AVAILABILITY] Errore verifica apertura: $e');
      return false;
    }
  }

  /// Recupera il prossimo slot disponibile del ristorante
  Future<TimeSlot?> getNextAvailableSlot({
    required String date,
    required int restaurantId,
  }) async {
    try {
      final restaurant = await getRestaurantAvailability(
        date: date,
        restaurantId: restaurantId,
      );

      return restaurant?.getNextAvailableSlot();
    } catch (e) {
      print('❌ [AVAILABILITY] Errore recupero slot: $e');
      return null;
    }
  }

  /// Verifica disponibilità di una lista di piatti
  /// Restituisce una mappa {dishId: isAvailable}
  Future<Map<int, bool>> checkDishesAvailability({
    required String date,
    required int restaurantId,
    required List<int> dishIds,
  }) async {
    final result = <int, bool>{};

    try {
      final availability = await getAvailability(
        date: date,
        restaurantId: restaurantId,
        includeDishes: true,
      );

      if (availability == null) {
        // Se non disponibilità, considera tutti non disponibili
        for (final id in dishIds) {
          result[id] = false;
        }
        return result;
      }

      for (final id in dishIds) {
        result[id] = availability.isDishAvailable(id);
      }

      return result;
    } catch (e) {
      print('❌ [AVAILABILITY] Errore verifica batch: $e');
      // In caso di errore, considera tutti non disponibili
      for (final id in dishIds) {
        result[id] = false;
      }
      return result;
    }
  }
}
