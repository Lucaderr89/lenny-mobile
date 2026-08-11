import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

/// Profilo del ristorante e chiusure dal-al.
class ProfileService {
  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyApiToken);
    if (token == null) throw Exception('Token non trovato');
    return token;
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Estrae il blocco dati, che puo' arrivare in data o data.data.
  static Map<String, dynamic> _dati(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    return json;
  }

  /// Profilo completo: anagrafica, orari, zone di consegna, chiusure.
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await _token();
      final response = await http
          .get(Uri.parse(AppConstants.profileEndpoint), headers: _headers(token))
          .timeout(const Duration(seconds: AppConstants.apiTimeout));
      if (response.statusCode != 200) {
        throw Exception('Errore caricamento profilo: ${response.statusCode}');
      }
      return _dati(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Errore getProfile: $e');
      rethrow;
    }
  }

  /// Crea una chiusura dal-al. Orari opzionali (fascia ripetuta ogni giorno).
  /// Restituisce la lista aggiornata delle chiusure.
  Future<List<dynamic>> createClosure({
    required String dateStart,
    required String dateEnd,
    String? timeStart,
    String? timeEnd,
    String? note,
  }) async {
    final token = await _token();
    final response = await http
        .post(
          Uri.parse(AppConstants.closureCreateEndpoint),
          headers: _headers(token),
          body: jsonEncode({
            'date_start': dateStart,
            'date_end': dateEnd,
            'time_start': ?timeStart,
            'time_end': ?timeEnd,
            if (note != null && note.isNotEmpty) 'note': note,
          }),
        )
        .timeout(const Duration(seconds: AppConstants.apiTimeout));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(
        json['message']?.toString() ?? 'Errore nel salvataggio della chiusura',
      );
    }
    return (_dati(json)['closures'] as List<dynamic>? ?? []);
  }

  /// Annulla una chiusura (RIAPRE subito se e' in corso).
  Future<List<dynamic>> deleteClosure(int id) async {
    final token = await _token();
    final endpoint = AppConstants.closureDeleteEndpoint.replaceAll(
      '{id}',
      id.toString(),
    );
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: _headers(token),
          // Corpo obbligatorio: una POST json a corpo vuoto viene
          // respinta dal WAF del server con 403 (come confirm-pickup).
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: AppConstants.apiTimeout));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(
        json['message']?.toString() ?? 'Errore nell\'annullamento',
      );
    }
    return (_dati(json)['closures'] as List<dynamic>? ?? []);
  }
}
