import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/auth_response.dart';
import 'credenziali_sicure.dart';
import 'firebase_storage_service.dart';

/// Servizio per gestire l'autenticazione dei driver
class AuthService {
  final String baseUrl = AppConstants.apiUrl;
  final FirebaseStorageService _storageService = FirebaseStorageService();

  // Headers comuni per tutte le richieste
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Login driver
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 [DRIVER LOGIN] Tentativo login per: $email');
      print('📍 [DRIVER LOGIN] URL: ${AppConstants.loginEndpoint}');

      final requestBody = {'email': email, 'password': password};

      print('📦 [DRIVER LOGIN] Body richiesta: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse(AppConstants.loginEndpoint),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [DRIVER LOGIN] Status code: ${response.statusCode}');
      print('📄 [DRIVER LOGIN] Response body: ${response.body}');

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        print('✅ [DRIVER LOGIN] Risposta 200 OK');
        final authResponse = AuthResponse.fromJson(jsonResponse);

        // Salva i dati di sessione
        if (authResponse.success && authResponse.data != null) {
          print('💾 [DRIVER LOGIN] Salvataggio dati driver...');
          await _saveAuthData(authResponse.data!);
          print('✅ [DRIVER LOGIN] Dati salvati con successo');
        } else {
          print('⚠️ [DRIVER LOGIN] Success=false o data=null');
        }

        return authResponse;
      } else {
        print('❌ [DRIVER LOGIN] Status code diverso da 200');
        return AuthResponse(
          success: false,
          message:
              jsonResponse['message'] as String? ?? 'Errore durante il login',
          error: jsonResponse['error'] as String?,
        );
      }
    } catch (e) {
      print('💥 [DRIVER LOGIN] ERRORE CATCH: $e');
      return AuthResponse(
        success: false,
        message: 'Errore di connessione: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Registrazione nuovo driver
  Future<AuthResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String iban,
    required String issCode,
    File? documentImage,
  }) async {
    try {
      print('📝 [DRIVER REGISTRATION] Inizio registrazione per: $email');

      String? documentUrl;

      // 1. Carica prima il documento su Firebase Storage
      if (documentImage != null) {
        print('📤 [DRIVER REGISTRATION] Caricamento documento su Firebase...');
        documentUrl = await _storageService.uploadDriverDocument(documentImage);
        print('✅ [DRIVER REGISTRATION] Documento caricato: $documentUrl');
      }

      // 2. Invia i dati della registrazione al backend (JSON, non multipart)
      print('📍 [DRIVER REGISTRATION] URL: ${AppConstants.registerEndpoint}');

      final requestBody = {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'iban': iban,
        'iss_code': issCode,
        'document_url': ?documentUrl,
      };

      print('📦 [DRIVER REGISTRATION] Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse(AppConstants.registerEndpoint),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [DRIVER REGISTRATION] Status code: ${response.statusCode}');
      print('📄 [DRIVER REGISTRATION] Response body: ${response.body}');

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [DRIVER REGISTRATION] Registrazione completata');
        // Successo: estrai il messaggio dalla risposta
        final message =
            jsonResponse['message'] as String? ??
            'Registrazione completata! In attesa di approvazione.';
        return AuthResponse(
          success: true,
          message: message,
          data: null, // Non abbiamo dati utente nella registrazione
        );
      } else {
        print('❌ [DRIVER REGISTRATION] Registrazione fallita');
        return AuthResponse(
          success: false,
          message:
              jsonResponse['message'] as String? ??
              'Errore durante la registrazione',
          error: jsonResponse['error']?.toString(),
        );
      }
    } catch (e) {
      print('💥 [DRIVER REGISTRATION] ERRORE CATCH: $e');
      return AuthResponse(
        success: false,
        message: 'Errore di connessione: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Logout
  Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(AppConstants.keyApiToken);

      if (sessionId != null) {
        await http
            .post(Uri.parse(AppConstants.logoutEndpoint), headers: _headers)
            .timeout(Duration(seconds: AppConstants.apiTimeout));
      }

      // Pulisci i dati locali
      await _clearAuthData();
      return true;
    } catch (e) {
      // Anche in caso di errore, pulisci i dati locali
      await _clearAuthData();
      return false;
    }
  }

  /// Salva i dati di autenticazione in locale
  Future<void> _saveAuthData(AuthData data) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(AppConstants.keyIsLoggedIn, true);

    // Salva API token se presente
    if (data.apiToken != null) {
      print('💾 [DRIVER AUTH] Salvo api_token: ${data.apiToken}');
      await prefs.setString(AppConstants.keyApiToken, data.apiToken!);
      print('✅ [DRIVER AUTH] API token salvato');
    }

    if (data.driver != null) {
      await prefs.setInt(AppConstants.keyDriverId, data.driver!.id);
      await prefs.setString(AppConstants.keyDriverName, data.driver!.name);
      await prefs.setString(AppConstants.keyDriverEmail, data.driver!.email);
      if (data.driver!.phone != null) {
        await prefs.setString(AppConstants.keyDriverPhone, data.driver!.phone!);
      }
    } else if (data.driverId != null) {
      await prefs.setInt(AppConstants.keyDriverId, data.driverId!);
    }
  }

  /// Pulisce i dati di autenticazione
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyIsLoggedIn);
    await prefs.remove(AppConstants.keyApiToken);
    await prefs.remove(AppConstants.keyDriverId);
    await prefs.remove(AppConstants.keyDriverName);
    await prefs.remove(AppConstants.keyDriverEmail);
    await prefs.remove(AppConstants.keyDriverPhone);
    // Anche la password dell'auto-login del pannello: al logout non deve
    // restare sul dispositivo.
    await CredenzialiSicure.cancella();
  }

  /// Verifica se il driver è loggato
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
      final apiToken = prefs.getString(AppConstants.keyApiToken);
      final driverId = prefs.getInt(AppConstants.keyDriverId);

      // Verifica che esistano tutti i dati essenziali
      if (isLoggedIn && apiToken != null && driverId != null) {
        print('✅ [DRIVER AUTH] Driver già loggato - ID: $driverId');
        return true;
      }

      print('⚠️ [DRIVER AUTH] Nessuna sessione valida trovata');
      return false;
    } catch (e) {
      print('💥 [DRIVER AUTH] Errore verifica login: $e');
      return false;
    }
  }

  /// Valida la sessione corrente con il backend
  Future<bool> validateSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString(AppConstants.keyApiToken);

      if (apiToken == null) {
        print('⚠️ [DRIVER AUTH] Nessun api_token trovato');
        return false;
      }

      print('🔍 [DRIVER AUTH] Validazione sessione con backend...');

      final response = await http
          .get(
            Uri.parse(AppConstants.meEndpoint),
            headers: {..._headers, 'Authorization': 'Bearer $apiToken'},
          )
          .timeout(Duration(seconds: 10));

      print(
        '📡 [DRIVER AUTH] Validazione sessione - Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          print('✅ [DRIVER AUTH] Sessione valida');
          return true;
        }
      }

      print('❌ [DRIVER AUTH] Sessione non valida o driver non trovato');
      return false;
    } catch (e) {
      print('💥 [DRIVER AUTH] Errore validazione sessione: $e');
      return false;
    }
  }

  /// Forza la pulizia completa dei dati locali (per debug)
  Future<void> forceLogout() async {
    print('🧹 [DRIVER AUTH] Pulizia forzata dati locali...');
    await _clearAuthData();
    print('✅ [DRIVER AUTH] Dati locali cancellati');
  }

  /// Ottieni il driver ID salvato
  Future<int?> getDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyDriverId);
  }

  /// Ottieni il token API salvato
  Future<String?> getApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyApiToken);
  }
}
