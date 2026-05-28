import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';

/// Servizio per calcolare i costi di consegna dinamici
class DeliveryFeeService {
  final String baseUrl = AppConstants.apiUrl;

  /// Calcola il costo di consegna chiamando l'API backend
  ///
  /// Richiede ALMENO uno tra:
  /// - [postalCode] - CAP di consegna (preferito)
  /// - [latitude] + [longitude] - Coordinate GPS (fallback)
  ///
  /// Parametri obbligatori:
  /// - [restaurantId] - ID ristorante
  /// - [subtotal] - Subtotale ordine (per calcolo consegna gratuita)
  Future<DeliveryFeeResult> calculateDeliveryFee({
    required int restaurantId,
    String? postalCode,
    double? latitude,
    double? longitude,
    required double subtotal,
  }) async {
    try {
      print('🚚 [DELIVERY FEE] Calcolo costo consegna...');
      print('🚚 [DELIVERY FEE] Restaurant: $restaurantId');
      print('🚚 [DELIVERY FEE] CAP: $postalCode');
      print('🚚 [DELIVERY FEE] GPS: $latitude, $longitude');
      print('🚚 [DELIVERY FEE] Subtotal: €$subtotal');

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
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [DELIVERY FEE] Status: ${response.statusCode}');
      print('📄 [DELIVERY FEE] Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        if (jsonResponse['success'] == true) {
          final result = DeliveryFeeResult.fromJson(
            jsonResponse['data'] as Map<String, dynamic>,
          );
          print('✅ [DELIVERY FEE] Risultato: ${result.toString()}');
          return result;
        } else {
          throw Exception(
            jsonResponse['message'] ?? 'Errore nel calcolo del costo',
          );
        }
      } else {
        throw Exception('Errore server (${response.statusCode})');
      }
    } catch (e) {
      print('❌ [DELIVERY FEE] Errore: $e');
      rethrow;
    }
  }
}

/// Risultato del calcolo del costo di consegna
class DeliveryFeeResult {
  final bool isDeliverable;
  final double deliveryFee;
  final double minOrder;
  final bool minOrderMet;
  final double? freeOver;
  final bool freeDelivery;
  final double finalDeliveryFee;
  final String? matchedRule;
  final String? ruleType;
  final String? reason; // Solo se non deliverable

  DeliveryFeeResult({
    required this.isDeliverable,
    required this.deliveryFee,
    required this.minOrder,
    required this.minOrderMet,
    this.freeOver,
    required this.freeDelivery,
    required this.finalDeliveryFee,
    this.matchedRule,
    this.ruleType,
    this.reason,
  });

  factory DeliveryFeeResult.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeResult(
      isDeliverable: json['is_deliverable'] as bool,
      deliveryFee: (json['delivery_fee'] as num).toDouble(),
      minOrder: (json['min_order'] as num).toDouble(),
      minOrderMet: json['min_order_met'] as bool,
      freeOver: json['free_over'] != null
          ? (json['free_over'] as num).toDouble()
          : null,
      freeDelivery: json['free_delivery'] as bool,
      finalDeliveryFee: (json['final_delivery_fee'] as num).toDouble(),
      matchedRule: json['matched_rule'] as String?,
      ruleType: json['rule_type'] as String?,
      reason: json['reason'] as String?,
    );
  }

  @override
  String toString() {
    if (!isDeliverable) {
      return 'NON DELIVERABLE: $reason';
    }
    return 'Deliverable: €$finalDeliveryFee (base: €$deliveryFee, min: €$minOrder, free: $freeDelivery) - $matchedRule';
  }
}
