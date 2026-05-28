import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/live_order.dart';

class LiveOrderService {
  // Headers comuni con API token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken) ?? '';

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': apiToken,
    };
  }

  /// Recupera tutti gli ordini attivi del customer (status 1-4)
  Future<List<LiveOrder>> getActiveOrders() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/customer/orders/active'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> ordersJson = jsonData['data'] as List<dynamic>;
          return ordersJson.map((json) => LiveOrder.fromJson(json)).toList();
        }
      }

      throw Exception(
        'Errore nel caricamento ordini attivi: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      print('❌ LiveOrderService.getActiveOrders error: $e');
      rethrow;
    }
  }

  /// Recupera lo storico ordini completati/annullati (status 5-6)
  Future<List<LiveOrder>> getOrderHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/customer/orders/history'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> ordersJson = jsonData['data'] as List<dynamic>;
          return ordersJson.map((json) => LiveOrder.fromJson(json)).toList();
        }
      }

      throw Exception(
        'Errore nel caricamento storico ordini: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      print('❌ LiveOrderService.getOrderHistory error: $e');
      rethrow;
    }
  }

  /// Annulla un ordine (solo se status < 3)
  Future<bool> cancelOrder(int orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/api/customer/orders/$orderId/cancel',
        ),
        headers: headers,
        body: jsonEncode({'order_id': orderId}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      }

      return false;
    } catch (e) {
      print('❌ LiveOrderService.cancelOrder error: $e');
      return false;
    }
  }
}
