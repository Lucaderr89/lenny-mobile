import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/saved_card.dart';

class WalletService {
  /// Headers comuni con API token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken) ?? '';

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': apiToken,
    };
  }

  /// Recupera tutte le carte salvate del cliente
  Future<List<SavedCard>> getSavedCards() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/nexi/check-saved-card'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> cardsJson =
              jsonData['data']['cards'] as List<dynamic>;
          return cardsJson.map((json) => SavedCard.fromJson(json)).toList();
        }
      }

      throw Exception(
        'Errore caricamento carte: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      print('❌ WalletService.getSavedCards error: $e');
      rethrow;
    }
  }

  /// Imposta carta predefinita
  Future<bool> setDefaultCard(String cardAlias) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/nexi/set-default-card'),
        headers: headers,
        body: jsonEncode({'card_alias': cardAlias}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      }

      return false;
    } catch (e) {
      print('❌ WalletService.setDefaultCard error: $e');
      return false;
    }
  }

  /// Rimuove carta salvata
  Future<bool> removeSavedCard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/nexi/remove-saved-card'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      }

      return false;
    } catch (e) {
      print('❌ WalletService.removeSavedCard error: $e');
      return false;
    }
  }

  /// Recupera crediti Lenny (rimborsi app_credit)
  Future<Map<String, dynamic>> getWalletCredits() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/customer/wallet/credits'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['data'] != null) {
          final data = jsonData['data'];
          final List<dynamic> creditsJson =
              data['credits'] as List<dynamic>? ?? [];

          return {
            'total_credits': double.parse(data['total_credits'].toString()),
            'credits': creditsJson
                .map((json) => WalletCredit.fromJson(json))
                .toList(),
            'count': data['count'] as int,
          };
        }
      }

      throw Exception(
        'Errore caricamento crediti: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      print('❌ WalletService.getWalletCredits error: $e');
      rethrow;
    }
  }
}
