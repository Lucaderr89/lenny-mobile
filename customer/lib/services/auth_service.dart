import 'dart:convert';
import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/auth_response.dart';

/// Servizio per gestire le chiamate API di autenticazione
class AuthService {
  final String baseUrl = AppConstants.apiUrl;

  // Headers comuni per tutte le richieste
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Login cliente
  Future<AuthResponse> login({
    required String email,
    required String password,
    String? deviceToken,
  }) async {
    try {
      print('🔐 [LOGIN] Tentativo login per: $email');
      print('📍 [LOGIN] URL: ${AppConstants.loginEndpoint}');

      final requestBody = {
        'email': email, // API customer usa 'email' non 'username'
        'password': password,
        'device_type': Platform.isIOS ? 'ios' : 'android',
        if (deviceToken != null) 'device_token': deviceToken,
      };

      print('📦 [LOGIN] Body richiesta: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse(AppConstants.loginEndpoint),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [LOGIN] Status code: ${response.statusCode}');
      print('📄 [LOGIN] Response body: ${response.body}');

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        print('✅ [LOGIN] Risposta 200 OK');
        final authResponse = AuthResponse.fromJson(jsonResponse);

        // Salva i dati di sessione
        if (authResponse.success && authResponse.data != null) {
          print('💾 [LOGIN] Salvataggio dati utente...');
          await _saveAuthData(authResponse.data!, password: password);
          print('✅ [LOGIN] Dati salvati con successo');
        } else {
          print('⚠️ [LOGIN] Success=false o data=null');
        }

        return authResponse;
      } else {
        print('❌ [LOGIN] Status code diverso da 200');
        final errField = jsonResponse['error'];
        final errMsg = errField is String
            ? errField
            : (errField is Map ? errField['message']?.toString() : null);
        return AuthResponse(
          success: false,
          message:
              errMsg ??
              jsonResponse['message'] as String? ??
              'Errore durante il login',
          error: errMsg,
        );
      }
    } catch (e) {
      print('💥 [LOGIN] ERRORE CATCH: $e');
      return AuthResponse(
        success: false,
        message: 'Errore di connessione: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Registrazione nuovo cliente
  Future<AuthResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    String? address,
    String? smacNumber,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.registerEndpoint),
            headers: _headers,
            body: jsonEncode({
              'first_name': firstName,
              'last_name': lastName,
              'email': email,
              'phone': phone,
              'password': password,
              if (address != null && address.isNotEmpty) 'address': address,
              if (smacNumber != null && smacNumber.isNotEmpty)
                'smac_id': smacNumber,
            }),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse.fromJson(jsonResponse);
      } else {
        final errField = jsonResponse['error'];
        final errMsg = errField is String
            ? errField
            : (errField is Map ? errField['message']?.toString() : null);
        return AuthResponse(
          success: false,
          message:
              errMsg ??
              jsonResponse['message'] as String? ??
              'Errore durante la registrazione',
          error: errMsg,
        );
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Errore di connessione: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Logout
  ///
  /// La chiamata al server non e' una formalita': cancella il token FCM di
  /// questo dispositivo. Senza, il telefono resta agganciato all'account anche
  /// dopo l'uscita, e chi lo usa dopo - dispositivo prestato, di famiglia o
  /// rivenduto - continua a ricevere le notifiche sugli ordini di chi c'era
  /// prima. Va fatta PRIMA di _clearAuthData(), che cancella il token con cui
  /// ci si autentica.
  Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString(AppConstants.keyApiToken);

      if (apiToken != null) {
        await http
            .post(
              Uri.parse(AppConstants.logoutEndpoint),
              headers: {..._headers, 'Authorization': 'Bearer $apiToken'},
            )
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

  /// Recupero password
  Future<AuthResponse> forgotPassword({required String email}) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.forgotPasswordEndpoint),
            headers: _headers,
            body: jsonEncode({'email': email}),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthResponse.fromJson(jsonResponse);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Errore di connessione: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Elimina definitivamente l'account del cliente autenticato.
  /// I dati personali vengono rimossi lato server; gli ordini gia' effettuati
  /// restano in forma anonima per obblighi fiscali.
  Future<AuthResponse> deleteAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      final response = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/customer/account/delete'),
            headers: {..._headers, 'X-API-Token': token ?? ''},
            body: jsonEncode({}),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && decoded['success'] == true) {
        await logout(); // pulisce le preferenze locali
        return AuthResponse.fromJson(decoded);
      }

      final error = decoded['error'];
      return AuthResponse(
        success: false,
        message:
            (error is Map ? error['message'] as String? : null) ??
            decoded['message'] as String? ??
            'Impossibile eliminare l\'account',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Errore di connessione: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Conferma il recupero password: codice ricevuto via email + nuova password.
  Future<AuthResponse> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/auth/reset-password'),
            headers: _headers,
            body: jsonEncode({
              'email': email,
              'code': code,
              'password': password,
            }),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      return AuthResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Errore di connessione: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Salva i dati di autenticazione in locale
  Future<void> _saveAuthData(AuthData data, {String? password}) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(AppConstants.keyIsLoggedIn, true);
    _statoLogin = true;

    // La password NON viene piu' salvata sul dispositivo: SharedPreferences e' un
    // file XML in chiaro, incluso nell'Auto Backup di Google. La sessione la tiene
    // l'api_token, che basta e si puo' revocare. Rimuoviamo anche eventuali password
    // salvate dalle versioni precedenti.
    await prefs.remove(AppConstants.keyUserPassword);

    // Collega i crash a questo utente: in beta permette di risalire a chi ha
    // incontrato il problema e richiamarlo. Nessun dato personale nella chiave,
    // solo l'id numerico.
    try {
      if (data.customer?.id != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(
          data.customer!.id.toString(),
        );
      }
    } catch (_) {
      // Crashlytics non disponibile (es. test): non deve bloccare il login
    }

    if (data.sessionId != null) {
      print('💾 [AUTH] Salvo session_id: ${data.sessionId}');
      await prefs.setString(AppConstants.keySessionId, data.sessionId!);
      print('✅ [AUTH] Session_id salvato in SharedPreferences');
    } else {
      print('⚠️ [AUTH] ATTENZIONE: sessionId è NULL nella risposta!');
    }

    // Salva API token se presente
    if (data.apiToken != null) {
      print('💾 [AUTH] Salvo api_token: ${data.apiToken}');
      await prefs.setString(AppConstants.keyApiToken, data.apiToken!);
      print('✅ [AUTH] API token salvato');
    }

    // Salva magicHash SSO per Spesa
    if (data.spesaMagicHash != null) {
      await prefs.setString(
        AppConstants.keySpesaMagicHash,
        data.spesaMagicHash!,
      );
    }

    if (data.firebaseToken != null) {
      await prefs.setString(AppConstants.keyAccessToken, data.firebaseToken!);
    }

    if (data.customer != null) {
      await prefs.setInt(AppConstants.keyUserId, data.customer!.id);
      await prefs.setString(AppConstants.keyUserEmail, data.customer!.email);
      await prefs.setString(
        AppConstants.keyUserFullname,
        data.customer!.fullName,
      );
      if (data.customer!.phone != null) {
        await prefs.setString(AppConstants.keyUserPhone, data.customer!.phone!);
      }
    } else if (data.customerId != null) {
      await prefs.setInt(AppConstants.keyUserId, data.customerId!);
    }
  }

  /// Pulisce i dati di autenticazione
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyIsLoggedIn);
    _statoLogin = false;
    await prefs.remove(AppConstants.keySessionId);
    await prefs.remove(AppConstants.keyAccessToken);
    await prefs.remove(AppConstants.keyUserId);
    await prefs.remove(AppConstants.keyUserEmail);
    await prefs.remove(AppConstants.keyUserFullname);
    await prefs.remove(AppConstants.keyUserPhone);
    await prefs.remove(AppConstants.keyUserPassword);
    await prefs.remove(AppConstants.keySpesaMagicHash);
  }

  /// Esito dell'ultimo controllo di login, condiviso fra tutte le istanze.
  ///
  /// Il controllo viene chiamato da mezza app a ogni cambio schermata: senza
  /// cache erano otto letture identiche (e otto righe di log) in pochi
  /// secondi. Lo stato cambia solo passando da _saveAuthData o logout, che
  /// lo azzerano: fra un login e un logout la risposta e' per definizione
  /// sempre la stessa.
  static bool? _statoLogin;

  /// Verifica se l'utente è loggato
  /// Controlla la presenza dei dati di sessione salvati localmente
  Future<bool> isLoggedIn() async {
    final noto = _statoLogin;
    if (noto != null) return noto;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
      final sessionId = prefs.getString(AppConstants.keySessionId);
      final userId = prefs.getInt(AppConstants.keyUserId);

      // Verifica che esistano tutti i dati essenziali
      if (isLoggedIn && sessionId != null && userId != null) {
        debugPrint('✅ [AUTH] Utente già loggato - ID: $userId');
        _statoLogin = true;
        return true;
      }

      debugPrint('ℹ️ [AUTH] Nessuna sessione valida trovata');
      _statoLogin = false;
      return false;
    } catch (e) {
      // L'errore non si mette in cache: al prossimo giro si riprova.
      debugPrint('💥 [AUTH] Errore verifica login: $e');
      return false;
    }
  }

  /// Valida la sessione corrente con il backend
  /// NOTA: Attualmente non utilizzato perché le sessioni PHP richiedono cookie
  Future<bool> validateSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(AppConstants.keySessionId);

      if (sessionId == null) {
        print('⚠️ [AUTH] Nessun session_id trovato');
        return false;
      }

      print('🔍 [AUTH] Validazione sessione con backend...');

      final response = await http
          .get(
            Uri.parse(AppConstants.meEndpoint),
            headers: {..._headers, 'X-Session-Id': sessionId},
          )
          .timeout(Duration(seconds: 10));

      print('📡 [AUTH] Validazione sessione - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          print('✅ [AUTH] Sessione valida');
          return true;
        }
      }

      print('❌ [AUTH] Sessione non valida o utente non trovato');
      return false;
    } catch (e) {
      print('💥 [AUTH] Errore validazione sessione: $e');
      return false;
    }
  }

  /// Forza la pulizia completa dei dati locali (per debug)
  Future<void> forceLogout() async {
    print('🧹 [AUTH] Pulizia forzata dati locali...');
    await _clearAuthData();
    print('✅ [AUTH] Dati locali cancellati');
  }

  /// Aggiorna profilo cliente
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      print('📝 [UPDATE_PROFILE] Aggiornamento profilo...');

      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString(AppConstants.keyApiToken);

      if (apiToken == null) {
        throw Exception('Token non trovato');
      }

      final response = await http
          .put(
            Uri.parse(AppConstants.updateProfileEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-API-Token': apiToken,
            },
            body: jsonEncode({
              'first_name': firstName,
              'last_name': lastName,
              'phone': phone,
            }),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      print('📡 [UPDATE_PROFILE] Status: ${response.statusCode}');
      print('📄 [UPDATE_PROFILE] Response: ${response.body}');

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        print('✅ [UPDATE_PROFILE] Profilo aggiornato con successo');

        // Aggiorna SharedPreferences
        final fullName = '$firstName $lastName';
        await prefs.setString(AppConstants.keyUserFullname, fullName);
        await prefs.setString(AppConstants.keyUserPhone, phone);

        return {
          'success': true,
          'message': jsonResponse['message'] ?? 'Profilo aggiornato',
        };
      } else {
        return {
          'success': false,
          'message': jsonResponse['message'] ?? 'Errore aggiornamento profilo',
        };
      }
    } catch (e) {
      print('💥 [UPDATE_PROFILE] ERRORE: $e');
      return {
        'success': false,
        'message': 'Errore di connessione: ${e.toString()}',
      };
    }
  }

  /// Verifica se è il primo avvio
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsFirstLaunch) ?? true;
  }

  /// Segna che l'app è stata avviata
  Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsFirstLaunch, false);
  }
}
