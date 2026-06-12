import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/delivery_data.dart';

/// Servizio per gestire le chiamate API degli ordini
class OrderService {
  final String baseUrl = AppConstants.apiUrl;

  // Headers comuni con API token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken) ?? '';

    print(
      '🔐 [HEADERS] API Token: ${apiToken.isEmpty ? "VUOTO!" : "${apiToken.substring(0, 10)}..."}',
    );

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': apiToken,
    };
  }

  /// Crea un nuovo ordine
  Future<Map<String, dynamic>> createOrder({
    required int restaurantId,
    required String dateOrder,
    required int timeSlotId,
    required String durationSlot,
    String? slotStartTime, // "HH:MM:SS" esatto scelto dal cliente (necessario per fasce da 20 min)
    required String pickupDelivery,
    DeliveryData? delivery, // NUOVO: oggetto delivery con coordinate
    @Deprecated('Usa delivery invece') int? deliveryAddressId,
    String? phone,
    String? allergents,
    required List<Map<String, dynamic>> items,
    required int paymentMethodId,
    required double subtotal,
    required double deliveryFee,
    required double total,
    double taxAmount = 0,
    double orderFee = 0,
    double discountAmount = 0,
    double appCreditsUsed = 0,
    double extraFee = 0,
    String? note,
  }) async {
    try {
      print('📦 [ORDER] Creazione ordine...');
      print('📍 [ORDER] Restaurant ID: $restaurantId');
      print('📅 [ORDER] Data: $dateOrder, Slot: $timeSlotId');
      print('🛵 [ORDER] Tipo: $pickupDelivery');
      print('💰 [ORDER] Totale: €$total');

      final requestBody = {
        'restaurant_id': restaurantId,
        'date_order': dateOrder,
        'time_slot_id': timeSlotId,
        'duration_slot': durationSlot,
        // Orario esatto scelto: il server lo preferisce a time_slot_id (indice a 15 min,
        // impreciso per le fasce da 20 min). Retro-compatibile: se assente si usa time_slot_id.
        if (slotStartTime != null) 'slot_start_time': slotStartTime,
        'pickup_delivery': pickupDelivery,

        // NUOVO: delivery con coordinate (se fornito)
        if (delivery != null && pickupDelivery == 'delivery')
          'delivery': delivery.toJson(),

        // DEPRECATED: supporto vecchio formato per retrocompatibilità
        if (delivery == null && deliveryAddressId != null)
          'delivery_address_id': deliveryAddressId,

        if (phone != null) 'phone': phone,
        if (allergents != null && allergents.isNotEmpty)
          'allergents': allergents,
        'items': items,
        'payment_method_id': paymentMethodId,
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'tax_amount': taxAmount,
        'order_fee': orderFee,
        'discount_amount': discountAmount,
        'app_credits_used': appCreditsUsed,
        'extra_fee': extraFee,
        if (note != null && note.isNotEmpty) 'note': note,
      };

      if (delivery != null) {
        print('📍 [ORDER] Delivery: ${delivery.toString()}');
      }

      print('📦 [ORDER] Body: ${jsonEncode(requestBody)}');

      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/customer/orders'),
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: 30));

      print('📡 [ORDER] Status: ${response.statusCode}');
      print('📄 [ORDER] Response: ${response.body}');

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ [ORDER] Ordine creato con successo!');
        return jsonResponse;
      } else {
        print(
          '❌ [ORDER] Errore: ${jsonResponse['message'] ?? 'Errore sconosciuto'}',
        );
        throw Exception(
          jsonResponse['message'] ?? 'Errore nella creazione dell\'ordine',
        );
      }
    } catch (e) {
      print('❌ [ORDER] Eccezione: $e');
      rethrow;
    }
  }

  /// Recupera ordini del cliente
  Future<List<Map<String, dynamic>>> getCustomerOrders() async {
    try {
      print('📋 [ORDER] Recupero ordini cliente...');

      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/customer/orders'), headers: headers)
          .timeout(Duration(seconds: 15));

      print('📡 [ORDER] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final orders =
            (jsonResponse['data']['orders'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        print('✅ [ORDER] ${orders.length} ordini recuperati');
        return orders;
      } else {
        print('❌ [ORDER] Errore recupero ordini');
        throw Exception('Errore nel recupero degli ordini');
      }
    } catch (e) {
      print('❌ [ORDER] Eccezione: $e');
      rethrow;
    }
  }

  /// Recupera metodi di pagamento abilitati
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      print('💳 [PAYMENT] Recupero metodi pagamento...');

      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/customer/payment-methods'), headers: headers)
          .timeout(Duration(seconds: 10));

      print('📡 [PAYMENT] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final methods =
            (jsonResponse['data']['methods'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        print('✅ [PAYMENT] ${methods.length} metodi disponibili');
        return methods;
      } else {
        print('❌ [PAYMENT] Errore recupero metodi');
        throw Exception('Errore nel recupero dei metodi di pagamento');
      }
    } catch (e) {
      print('❌ [PAYMENT] Eccezione: $e');
      rethrow;
    }
  }

  /// Ottiene gli indirizzi di consegna del cliente
  Future<List<Map<String, dynamic>>> getAddresses() async {
    try {
      print('🏠 [ADDRESSES] Recupero indirizzi cliente...');

      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/customer/addresses'), headers: headers)
          .timeout(const Duration(seconds: 10));

      print('📡 [ADDRESSES] Status: ${response.statusCode}');
      print('📄 [ADDRESSES] Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final addresses =
            (jsonResponse['data'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        print('✅ [ADDRESSES] ${addresses.length} indirizzi disponibili');
        return addresses;
      } else {
        print('❌ [ADDRESSES] Errore recupero indirizzi');
        throw Exception('Errore nel recupero degli indirizzi');
      }
    } catch (e) {
      print('❌ [ADDRESSES] Eccezione: $e');
      rethrow;
    }
  }

  /// Ottiene gli slot disponibili per un ristorante in una data specifica
  Future<List<Map<String, dynamic>>> getAvailableSlots({
    required int restaurantId,
    required String date,
  }) async {
    try {
      print('🕐 [SLOTS] Recupero slot disponibili...');
      print('📍 [SLOTS] Ristorante: $restaurantId, Data: $date');

      final headers = await _getHeaders();
      final url = Uri.parse(
        '$baseUrl/customer/restaurants/$restaurantId/available-slots?date=$date',
      );

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      print('🌐 [SLOTS] Status: ${response.statusCode}');
      print('📄 [SLOTS] Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Nuovo formato con periodi
        if (jsonResponse['data'].containsKey('periods')) {
          final periods =
              (jsonResponse['data']['periods'] as List?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];

          print('✅ [SLOTS] ${periods.length} periodi disponibili');
          return periods;
        }

        // Fallback per vecchio formato con slots diretti
        final slots =
            (jsonResponse['data']['slots'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        print('✅ [SLOTS] ${slots.length} slot disponibili');
        return slots;
      } else {
        print('❌ [SLOTS] Errore recupero slot: ${response.statusCode}');
        throw Exception('Errore nel recupero degli slot disponibili');
      }
    } catch (e) {
      print('❌ [SLOTS] Eccezione: $e');
      rethrow;
    }
  }
}
