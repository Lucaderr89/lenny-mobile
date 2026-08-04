import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/order.dart';

/// Service per gestire gli ordini del partner
class OrderService {
  /// Ottiene gli ordini del ristorante
  Future<List<Order>> getOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      if (token == null) {
        throw Exception('Token non trovato');
      }

      final response = await http
          .get(
            Uri.parse(AppConstants.ordersEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Gli ordini possono essere in data.orders o data.data.orders
        final ordersJson =
            (data['data'] != null && data['data']['orders'] != null)
            ? data['data']['orders'] as List<dynamic>?
            : data['orders'] as List<dynamic>?;

        if (ordersJson == null) return [];

        // Non si logga il contenuto della risposta: contiene nome, telefono e
        // indirizzo dei clienti.
        return ordersJson.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Errore caricamento ordini: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore getOrders: $e');
      rethrow;
    }
  }

  /// Ottieni storico ordini (consegnati + annullati)
  Future<Map<String, dynamic>> getOrderHistory({
    String? status, // 'delivered', 'cancelled', null = entrambi
    int days = 30,
    int page = 1,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);
      if (token == null) throw Exception('Token non trovato');

      final uri = Uri.parse(AppConstants.orderHistoryEndpoint).replace(
        queryParameters: {
          'status': ?status,
          'days': days.toString(),
          'page': page.toString(),
        },
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ordersJson =
            (data['data'] != null && data['data']['orders'] != null)
            ? data['data']['orders'] as List<dynamic>?
            : data['orders'] as List<dynamic>?;

        final pagination =
            (data['data'] != null && data['data']['pagination'] != null)
            ? data['data']['pagination'] as Map<String, dynamic>?
            : data['pagination'] as Map<String, dynamic>?;

        final orders = (ordersJson ?? [])
            .map((j) => Order.fromJson(j))
            .toList();
        return {'orders': orders, 'pagination': pagination ?? {}};
      } else {
        throw Exception('Errore storico ordini: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore getOrderHistory: $e');
      rethrow;
    }
  }

  /// Conferma ritiro asporto → mette l'ordine in stato delivered
  Future<bool> confirmPickup(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);
      if (token == null) throw Exception('Token non trovato');

      final endpoint = AppConstants.confirmPickupEndpoint.replaceAll(
        '{id}',
        orderId.toString(),
      );

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              // Il dollaro NON va escapato: con 'Bearer \$token' Dart manda la
              // stringa letterale invece del token e il server risponde 401.
              'Authorization': 'Bearer $token',
            },
            // Il corpo e' obbligatorio: una POST con Content-Type application/json
            // e corpo vuoto viene respinta dal WAF del server con 403.
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      debugPrint('confirmPickup HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Errore confirmPickup: $e');
      return false;
    }
  }
}
