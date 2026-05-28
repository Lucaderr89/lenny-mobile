import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/loyalty_data.dart';
import '../models/loyalty_reward.dart';
import '../models/loyalty_redemption.dart';

/// Servizio per gestire le chiamate API del programma fedeltà
class LoyaltyService {
  final String baseUrl = AppConstants.apiUrl;

  /// Headers con autenticazione
  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken) ?? '';

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': apiToken,
    };
  }

  /// Recupera dati completi del programma fedeltà
  Future<LoyaltyData?> getLoyaltyData() async {
    try {
      print('🎯 [LOYALTY] Recupero dati programma fedeltà...');

      final headers = await _headers;
      final response = await http
          .get(Uri.parse('$baseUrl/customer/loyalty'), headers: headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [LOYALTY] Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          print('✅ [LOYALTY] Dati ricevuti con successo');
          return LoyaltyData.fromJson(jsonResponse['data']);
        }
      } else if (response.statusCode == 401) {
        print('❌ [LOYALTY] Non autenticato');
        throw Exception('Sessione scaduta');
      }

      print('⚠️ [LOYALTY] Risposta non valida');
      return null;
    } catch (e) {
      print('💥 [LOYALTY] Errore: $e');
      rethrow;
    }
  }

  /// Recupera lista premi disponibili
  Future<List<LoyaltyReward>> getRewards() async {
    try {
      print('🎁 [LOYALTY] Recupero lista premi...');

      final headers = await _headers;
      final response = await http
          .get(Uri.parse('$baseUrl/customer/loyalty/rewards'), headers: headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [LOYALTY REWARDS] Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          final rewardsList = data['rewards'] as List<dynamic>?;

          if (rewardsList != null) {
            print('✅ [LOYALTY REWARDS] ${rewardsList.length} premi ricevuti');
            return rewardsList.map((r) => LoyaltyReward.fromJson(r)).toList();
          }
        }
      } else if (response.statusCode == 401) {
        print('❌ [LOYALTY REWARDS] Non autenticato');
        throw Exception('Sessione scaduta');
      }

      print('⚠️ [LOYALTY REWARDS] Nessun premio trovato');
      return [];
    } catch (e) {
      print('💥 [LOYALTY REWARDS] Errore: $e');
      rethrow;
    }
  }

  /// Recupera storico riscatti del cliente
  Future<List<LoyaltyRedemption>> getRedemptions() async {
    try {
      print('📜 [LOYALTY] Recupero storico riscatti...');

      final headers = await _headers;
      final response = await http
          .get(
            Uri.parse('$baseUrl/customer/loyalty/redemptions'),
            headers: headers,
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [LOYALTY REDEMPTIONS] Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          final redemptionsList = data['redemptions'] as List<dynamic>?;

          if (redemptionsList != null) {
            print(
              '✅ [LOYALTY REDEMPTIONS] ${redemptionsList.length} riscatti ricevuti',
            );
            return redemptionsList
                .map((r) => LoyaltyRedemption.fromJson(r))
                .toList();
          }
        }
      } else if (response.statusCode == 401) {
        print('❌ [LOYALTY REDEMPTIONS] Non autenticato');
        throw Exception('Sessione scaduta');
      }

      print('⚠️ [LOYALTY REDEMPTIONS] Nessun riscatto trovato');
      return [];
    } catch (e) {
      print('💥 [LOYALTY REDEMPTIONS] Errore: $e');
      rethrow;
    }
  }

  /// Riscatta un premio
  Future<Map<String, dynamic>?> redeemReward(int rewardId) async {
    try {
      print('🎁 [LOYALTY] Riscatto premio ID: $rewardId');

      final headers = await _headers;
      final response = await http
          .post(
            Uri.parse('$baseUrl/customer/loyalty/redeem'),
            headers: headers,
            body: jsonEncode({'reward_id': rewardId}),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [LOYALTY REDEEM] Status code: ${response.statusCode}');
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (jsonResponse['success'] == true) {
          print('✅ [LOYALTY REDEEM] Premio riscattato con successo');
          return jsonResponse['data'];
        } else {
          print('❌ [LOYALTY REDEEM] Errore: ${jsonResponse['message']}');
          throw Exception(
            jsonResponse['message'] ?? 'Errore durante il riscatto',
          );
        }
      } else if (response.statusCode == 400) {
        // Errore validazione (es. punti insufficienti)
        print(
          '❌ [LOYALTY REDEEM] Errore validazione: ${jsonResponse['message']}',
        );
        throw Exception(jsonResponse['message'] ?? 'Richiesta non valida');
      } else if (response.statusCode == 401) {
        print('❌ [LOYALTY REDEEM] Non autenticato');
        throw Exception('Sessione scaduta');
      }

      throw Exception('Errore durante il riscatto');
    } catch (e) {
      print('💥 [LOYALTY REDEEM] Errore: $e');
      rethrow;
    }
  }
}
