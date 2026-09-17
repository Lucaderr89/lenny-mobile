import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/wallet_credit.dart';

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
