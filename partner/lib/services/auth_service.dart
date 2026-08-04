import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/auth_response.dart';

/// Service per gestire l'autenticazione del partner
class AuthService {
  /// Login partner
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.loginEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: AppConstants.apiTimeout));

      final data = jsonDecode(response.body);
      final authResponse = AuthResponse.fromJson(data);

      // Salva i dati in local storage se il login ha successo
      if (authResponse.success && authResponse.token != null) {
        await _saveAuthData(authResponse);
      }

      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Errore di connessione: ${e.toString()}',
      );
    }
  }

  /// Salva i dati di autenticazione in SharedPreferences
  Future<void> _saveAuthData(AuthResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsLoggedIn, true);
    await prefs.setString(AppConstants.keyApiToken, response.token ?? '');

    if (response.partner != null) {
      await prefs.setInt(AppConstants.keyPartnerId, response.partner!.id);
      await prefs.setString(
        AppConstants.keyPartnerName,
        response.partner!.name,
      );
      await prefs.setString(
        AppConstants.keyPartnerEmail,
        response.partner!.email,
      );

      if (response.partner!.restaurantId != null) {
        await prefs.setInt(
          AppConstants.keyRestaurantId,
          response.partner!.restaurantId!,
        );
      }
      if (response.partner!.restaurantName != null) {
        await prefs.setString(
          AppConstants.keyRestaurantName,
          response.partner!.restaurantName!,
        );
      }
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      if (token != null) {
        await http
            .post(
              Uri.parse(AppConstants.logoutEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: AppConstants.apiTimeout));
      }
    } catch (e) {
      // Ignora errori di logout API
      debugPrint('Errore logout API: $e');
    } finally {
      // Pulisci sempre i dati locali
      await _clearAuthData();
    }
  }

  /// Pulisce i dati di autenticazione
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyIsLoggedIn);
    await prefs.remove(AppConstants.keyApiToken);
    await prefs.remove(AppConstants.keyPartnerId);
    await prefs.remove(AppConstants.keyPartnerName);
    await prefs.remove(AppConstants.keyPartnerEmail);
    await prefs.remove(AppConstants.keyRestaurantId);
    await prefs.remove(AppConstants.keyRestaurantName);
  }

  /// Verifica se l'utente è loggato
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
  }

  /// Ottiene il token API
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyApiToken);
  }
}
