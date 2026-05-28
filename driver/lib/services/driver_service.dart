import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/order.dart';
import '../models/delivery_history.dart';

/// Service per gestire le operazioni del Driver
class DriverService {
  /// Ottiene gli headers con autenticazione
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken);

    return {
      'Content-Type': 'application/json',
      if (apiToken != null) 'Authorization': 'Bearer $apiToken',
    };
  }

  /// Recupera gli ordini assegnati al driver
  Future<List<Order>> getAssignedOrders() async {
    try {
      final headers = await _getHeaders();
      final url = '${AppConstants.apiUrl}/driver/orders';

      print('🔵 API Request: GET $url');
      print('🔵 Headers: $headers');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('🔵 Response Status: ${response.statusCode}');
      print('🔵 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // L'API restituisce direttamente l'array di ordini o within data?
        final List<dynamic> ordersJson = responseData is List
            ? responseData
            : (responseData['data'] as List<dynamic>? ?? []);

        return ordersJson.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception(
          'Errore caricamento ordini: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Exception in getAssignedOrders: $e');
      throw Exception('Errore connessione: $e');
    }
  }

  /// Conferma la ricezione di un ordine da parte del driver
  Future<void> confirmOrderReceived(
    int orderId, {
    String orderSource = 'food',
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${AppConstants.apiUrl}/driver/orders/$orderId/confirm';

      print('🔵 API Request: POST $url');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({'order_id': orderId, 'order_source': orderSource}),
      );

      print('🔵 Response Status: ${response.statusCode}');
      print('🔵 Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Errore conferma ordine: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Exception in confirmOrderReceived: $e');
      throw Exception('Errore connessione: $e');
    }
  }

  /// Conferma la consegna di un ordine
  Future<void> confirmOrderDelivered(
    int orderId, {
    int? paymentMethodId,
    String orderSource = 'food',
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${AppConstants.apiUrl}/driver/orders/$orderId/deliver';

      final body = <String, dynamic>{
        'order_id': orderId,
        'order_source': orderSource,
      };
      if (paymentMethodId != null) {
        body['payment_method_id'] = paymentMethodId;
      }

      print('🔵 API Request: POST $url');
      print('🔵 Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      print('🔵 Response Status: ${response.statusCode}');
      print('🔵 Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Errore conferma consegna: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Exception in confirmOrderDelivered: $e');
      throw Exception('Errore connessione: $e');
    }
  }

  /// Aggiorna lo stato di un ordine partner (picking_up | in_delivery).
  /// Chiamato dal driver quando arriva dal partner o quando parte con la merce.
  Future<void> setPartnerOrderStatus(
    int orderId,
    String status, // 'picking_up' | 'in_delivery'
  ) async {
    try {
      final headers = await _getHeaders();
      final url =
          '${AppConstants.apiUrl}/driver/orders/$orderId/partner-status';

      print('🔵 API Request: POST $url  status=$status');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({'order_id': orderId, 'status': status}),
      );

      print('🔵 Response Status: \${response.statusCode}');
      print('🔵 Response Body: \${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final body = json.decode(response.body);
        throw Exception(
          body['error']?['message'] ??
              'Errore aggiornamento stato: \${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Exception in setPartnerOrderStatus: $e');
      throw Exception('Errore connessione: $e');
    }
  }

  /// Ottiene i dettagli completi del driver
  Future<Map<String, dynamic>> getDriverDetails(int driverId) async {
    try {
      final headers = await _getHeaders();
      final url = '${AppConstants.baseUrl}/api/drivers/$driverId';

      print('🔵 API Request: GET $url');
      print('🔵 Headers: $headers');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('🔵 Response Status: ${response.statusCode}');
      print('🔵 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('🔵 Parsed Data: $responseData');

        // L'API restituisce i dati in data.driver
        if (responseData['data'] != null &&
            responseData['data']['driver'] != null) {
          return responseData['data']['driver'];
        } else {
          // Fallback per formato diretto
          return responseData;
        }
      } else {
        throw Exception(
          'Errore caricamento dati driver: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Exception in getDriverDetails: $e');
      throw Exception('Errore connessione: $e');
    }
  }

  /// Aggiorna l'IBAN del driver
  Future<void> updateDriverIban(int driverId, String iban) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/drivers/$driverId/iban'),
        headers: headers,
        body: json.encode({'iban': iban}),
      );

      if (response.statusCode != 200) {
        throw Exception('Errore aggiornamento IBAN');
      }
    } catch (e) {
      throw Exception('Errore connessione: $e');
    }
  }

  /// Aggiunge un documento al driver
  Future<void> addDriverDocument(
    int driverId,
    String documentUrl,
    String documentName,
  ) async {
    try {
      final headers = await _getHeaders();
      final url = '${AppConstants.baseUrl}/api/drivers/$driverId/documents';
      final body = json.encode({
        'document_url': documentUrl,
        'document_name': documentName,
      });

      print('🔵 Upload Document API Request: POST $url');
      print('🔵 Headers: $headers');
      print('🔵 Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('🔵 Upload Response Status: ${response.statusCode}');
      print('🔵 Upload Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Errore caricamento documento: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Exception in addDriverDocument: $e');
      throw Exception('Errore connessione: $e');
    }
  }

  /// Recupera lo storico delle consegne completate con statistiche
  Future<Map<String, dynamic>> getDeliveryHistory({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${AppConstants.apiUrl}/driver/history';

      // Aggiungi parametri query se presenti
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }

      print('🔵 API Request: GET $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('🔵 Response Status: ${response.statusCode}');
      print('🔵 Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Errore recupero storico: Status ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);

      if (data['success'] != true) {
        throw Exception('Errore API: ${data['message'] ?? 'Unknown error'}');
      }

      // Parse deliveries
      final List<DeliveryHistory> deliveries = [];
      if (data['data']['deliveries'] != null) {
        for (var item in data['data']['deliveries']) {
          deliveries.add(DeliveryHistory.fromJson(item));
        }
      }

      // Parse stats
      final DeliveryStats stats = DeliveryStats.fromJson(data['data']['stats']);

      return {'deliveries': deliveries, 'stats': stats};
    } catch (e) {
      print('❌ Exception in getDeliveryHistory: $e');
      throw Exception('Errore connessione: $e');
    }
  }
}
