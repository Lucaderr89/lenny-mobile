import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import '../models/cuisine.dart';

/// Servizio per gestire le chiamate API delle cucine
class CuisineService {
  final String baseUrl = AppConstants.apiUrl;

  // Headers comuni per tutte le richieste
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Recupera tutte le cucine attive
  Future<List<Cuisine>> getCuisines() async {
    try {
      print('🍕 [CUISINES] Recupero cucine da: $baseUrl/cuisines');

      final response = await http
          .get(Uri.parse('$baseUrl/cuisines'), headers: _headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [CUISINES] Status code: ${response.statusCode}');
      print('📄 [CUISINES] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final List<dynamic> cuisinesJson = jsonResponse['data'] as List;
          final cuisines = cuisinesJson
              .map((json) => Cuisine.fromJson(json))
              .toList();

          // Ordina per display_order
          cuisines.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

          print('✅ [CUISINES] Recuperate ${cuisines.length} cucine');
          return cuisines;
        } else {
          print('⚠️ [CUISINES] Risposta non valida');
          return [];
        }
      } else {
        print('❌ [CUISINES] Errore HTTP: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('💥 [CUISINES] ERRORE: $e');
      return [];
    }
  }
}
