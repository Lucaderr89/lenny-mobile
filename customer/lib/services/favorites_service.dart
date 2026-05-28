import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/favorite.dart';

/// Servizio per gestire le chiamate API dei preferiti
class FavoritesService {
  final String baseUrl = AppConstants.apiUrl;

  /// Headers autenticati per le richieste
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken) ?? '';

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': apiToken,
    };
  }

  /// Recupera tutti i preferiti raggruppati per ristorante
  ///
  /// Ritorna una lista di [FavoriteGroup] contenente:
  /// - Ristoranti preferiti con i loro dati
  /// - Per ogni ristorante, i piatti preferiti
  Future<List<FavoriteGroup>> getFavorites() async {
    try {
      print('❤️ [FAVORITES] Recupero lista preferiti...');

      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/customer/favorites'), headers: headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [FAVORITES] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          final favoritesList = data['favorites'] as List<dynamic>? ?? [];

          final favorites = favoritesList
              .map(
                (json) => FavoriteGroup.fromJson(json as Map<String, dynamic>),
              )
              .toList();

          final totalCount = data['total_count'] as int? ?? 0;

          print(
            '✅ [FAVORITES] Caricati ${favorites.length} gruppi, $totalCount preferiti totali',
          );
          return favorites;
        } else {
          print('⚠️ [FAVORITES] Risposta non valida');
          return [];
        }
      } else {
        print('❌ [FAVORITES] Errore ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ [FAVORITES] Eccezione: $e');
      return [];
    }
  }

  /// Verifica se un elemento è nei preferiti
  ///
  /// [type] - 'restaurant' o 'dish'
  /// [id] - ID del ristorante o piatto
  Future<bool> isFavorite(String type, int id) async {
    try {
      print('🔍 [FAVORITES] Check preferito: $type #$id');

      final headers = await _getHeaders();
      final uri = Uri.parse(
        '$baseUrl/customer/favorites/check',
      ).replace(queryParameters: {'type': type, 'id': id.toString()});

      final response = await http
          .get(uri, headers: headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final isFav = jsonResponse['data']?['is_favorite'] as bool? ?? false;

        print('✅ [FAVORITES] Check: $isFav');
        return isFav;
      } else {
        print('⚠️ [FAVORITES] Check fallito, assume false');
        return false;
      }
    } catch (e) {
      print('❌ [FAVORITES] Check exception: $e');
      return false;
    }
  }

  /// Aggiunge un elemento ai preferiti
  ///
  /// [type] - 'restaurant' o 'dish'
  /// [id] - ID del ristorante o piatto
  Future<bool> addFavorite(String type, int id) async {
    try {
      print('➕ [FAVORITES] Aggiungo ai preferiti: $type #$id');

      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/customer/favorites/add'),
            headers: headers,
            body: jsonEncode({'type': type, 'id': id}),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [FAVORITES] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          print('✅ [FAVORITES] Aggiunto con successo');
          return true;
        } else {
          print('⚠️ [FAVORITES] Risposta success=false');
          return false;
        }
      } else {
        print('❌ [FAVORITES] Errore ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ [FAVORITES] Eccezione add: $e');
      return false;
    }
  }

  /// Rimuove un elemento dai preferiti
  ///
  /// [type] - 'restaurant' o 'dish'
  /// [id] - ID del ristorante o piatto
  Future<bool> removeFavorite(String type, int id) async {
    try {
      print('➖ [FAVORITES] Rimuovo dai preferiti: $type #$id');

      final headers = await _getHeaders();
      final request = http.Request(
        'DELETE',
        Uri.parse('$baseUrl/customer/favorites/remove'),
      );
      request.headers.addAll(headers);
      request.body = jsonEncode({'type': type, 'id': id});

      final streamedResponse = await request.send().timeout(
        Duration(seconds: AppConstants.apiTimeout),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 [FAVORITES] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          print('✅ [FAVORITES] Rimosso con successo');
          return true;
        } else {
          print('⚠️ [FAVORITES] Risposta success=false');
          return false;
        }
      } else {
        print('❌ [FAVORITES] Errore ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ [FAVORITES] Eccezione remove: $e');
      return false;
    }
  }
}
