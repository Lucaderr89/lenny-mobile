import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/order.dart';
import 'traccia_stampe_service.dart';

/// Service per gestire gli ordini del partner
class OrderService {
  // Stato del collegamento, per la traccia comande: il server ricostruisce
  // i periodi in cui il tablet non si e' fatto sentire, e la causa gliela
  // dice l'app alla prima richiesta riuscita. Statico perche' riguarda il
  // processo, non la schermata: la home puo' essere ricreata.
  static bool _giaCollegato = false;
  static DateTime? _inizioProblemiRete;

  /// Ottiene gli ordini del ristorante.
  ///
  /// Con la richiesta viaggia lo stato del tablet (stampa automatica,
  /// stampante, rete): e' il "battito" che il server conserva per la
  /// traccia comande. Senza rete il tablet non puo' avvisare nessuno: lo
  /// dice alla prima richiesta che torna a passare.
  Future<List<Order>> getOrders({
    bool? stampaAutomatica,
    String? problemaStampante,
    bool? stampanteIntegrata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      if (token == null) {
        throw Exception('Token non trovato');
      }

      final inizioProblemi = _inizioProblemiRete;
      final statoTablet = <String, String>{
        'device': await TracciaStampe.instance.dispositivo(),
        if (stampaAutomatica != null)
          'autoprint': stampaAutomatica ? '1' : '0',
        if (stampanteIntegrata != null)
          'con_stampante': stampanteIntegrata ? '1' : '0',
        // Vuoto = stampante pronta
        'stampante': problemaStampante ?? '',
        if (!_giaCollegato) 'avvio': '1',
        if (inizioProblemi != null)
          'senza_rete': DateTime.now()
              .difference(inizioProblemi)
              .inSeconds
              .toString(),
      };

      final response = await http
          .get(
            Uri.parse(
              AppConstants.ordersEndpoint,
            ).replace(queryParameters: statoTablet),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        _giaCollegato = true;
        _inizioProblemiRete = null;
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
      _inizioProblemiRete ??= DateTime.now();
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
