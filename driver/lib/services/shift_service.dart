import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/driver_shift_info.dart';

/// Service per la gestione dei turni driver (lettura da platform DB via API)
class ShiftService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken);
    return {
      'Content-Type': 'application/json',
      if (apiToken != null) 'Authorization': 'Bearer $apiToken',
    };
  }

  /// Recupera il turno di oggi + stato availability dal server.
  /// Ritorna null se il server è irraggiungibile.
  Future<DriverShiftInfo?> getShiftToday() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${AppConstants.apiUrl}/driver/shift/today'),
            headers: headers,
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          return DriverShiftInfo.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      print('❌ [ShiftService] getShiftToday error: $e');
      return null;
    }
  }

  /// Recupera i turni in un range di date (per la schermata Turni).
  /// Ritorna lista piatta di shift.
  Future<List<Map<String, String>>> getShiftsRange({
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${AppConstants.apiUrl}/driver/shifts?date_from=$dateFrom&date_to=$dateTo',
      );
      final response = await http
          .get(uri, headers: headers)
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          final shifts = body['data']['shifts'] as List<dynamic>? ?? [];
          return shifts
              .map(
                (e) => Map<String, String>.from(
                  (e as Map<String, dynamic>).map(
                    (k, v) => MapEntry(k, v.toString()),
                  ),
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ [ShiftService] getShiftsRange error: $e');
      return [];
    }
  }
}
