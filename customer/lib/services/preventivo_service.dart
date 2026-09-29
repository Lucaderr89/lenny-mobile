import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/preventivo.dart';

/// Errore restituito dal server sul preventivo, con il suo messaggio.
class PreventivoException implements Exception {
  final String messaggio;
  const PreventivoException(this.messaggio);

  @override
  String toString() => messaggio;
}

/// Preventivo del server: stessi importi che la creazione dell'ordine
/// scrivera' e addebitera' (listino, zona, costo servizio, coupon, crediti).
class PreventivoService {
  /// Null se il cliente non ha fatto l'accesso (il server lo chiede).
  /// [PreventivoException] se il server rifiuta la richiesta; errori di rete
  /// e timeout arrivano cosi' come sono.
  Future<Preventivo?> richiedi({
    required int restaurantId,
    required String pickupDelivery,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? delivery,
    String? couponCode,
    double appCreditsUsed = 0.0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyApiToken);
    if (token == null || token.isEmpty) return null;

    final body = <String, dynamic>{
      'restaurant_id': restaurantId,
      'pickup_delivery': pickupDelivery,
      'items': items,
      'delivery': ?delivery,
      if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
      if (appCreditsUsed > 0) 'app_credits_used': appCreditsUsed,
    };

    final response = await http
        .post(
          Uri.parse('${AppConstants.apiUrl}/customer/order/quote'),
          headers: {'Content-Type': 'application/json', 'X-API-Token': token},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = json.decode(response.body);
    final data = decoded is Map ? decoded['data'] : null;

    if (response.statusCode == 200 && data is Map) {
      return Preventivo.fromJson(Map<String, dynamic>.from(data));
    }

    final errore = decoded is Map && decoded['error'] is Map
        ? decoded['error']['message'] as String?
        : null;
    throw PreventivoException(errore ?? 'Errore server (${response.statusCode})');
  }
}
