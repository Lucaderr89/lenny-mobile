import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import '../models/app_category.dart';

/// Servizio per gestire le categorie dell'app (Spesa, Farmacia, ecc.)
class AppCategoryService {
  final String baseUrl = AppConstants.apiUrl;

  /// Ottieni tutte le categorie attive dall'API
  /// Ritorna solo le categorie con is_active = true
  Future<List<AppCategory>> getActiveCategories() async {
    try {
      print('📱 [APP_CATEGORIES] Richiesta categorie attive...');
      print('📱 [APP_CATEGORIES] baseUrl: $baseUrl');
      print('📱 [APP_CATEGORIES] AppConstants.apiUrl: ${AppConstants.apiUrl}');
      print(
        '📱 [APP_CATEGORIES] AppConstants.baseUrl: ${AppConstants.baseUrl}',
      );

      final url = '$baseUrl/app/categories';
      print('📍 [APP_CATEGORIES] URL COMPLETO COSTRUITO: $url');

      final uri = Uri.parse(url);
      print(
        '📍 [APP_CATEGORIES] URI parsed - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [APP_CATEGORIES] Status: ${response.statusCode}');
      print('📄 [APP_CATEGORIES] Body: ${response.body}');
      print('📄 [APP_CATEGORIES] Headers response: ${response.headers}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final List<dynamic> categoriesJson = jsonResponse['data'] as List;

          final categories = categoriesJson
              .map((json) => AppCategory.fromJson(json as Map<String, dynamic>))
              .toList();

          print('✅ [APP_CATEGORIES] ${categories.length} categorie caricate');

          // Ordina per display_order
          categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

          return categories;
        } else {
          print('⚠️ [APP_CATEGORIES] Risposta senza dati validi');
          return [];
        }
      } else {
        print('❌ [APP_CATEGORIES] Errore HTTP ${response.statusCode}');
        throw Exception(
          'Errore nel caricamento delle categorie: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ [APP_CATEGORIES] Eccezione: $e');
      rethrow;
    }
  }
}
