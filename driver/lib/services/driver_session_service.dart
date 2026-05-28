import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/driver_session.dart';
import '../models/location_point.dart';
import '../config/app_constants.dart';
import 'driver_location_service.dart';

/// Service per gestire i turni del driver e il tracking GPS
class DriverSessionService {
  final DriverLocationService _locationService = DriverLocationService();
  DriverSession? _currentSession;
  StreamSubscription<LocationPoint>? _locationSubscription;
  Timer? _locationUpdateTimer;

  /// Sessione attiva corrente
  DriverSession? get currentSession => _currentSession;

  /// Verifica se c'è una sessione attiva
  bool get hasActiveSession =>
      _currentSession != null && _currentSession!.isActive;

  /// Status corrente (online/offline/busy)
  String get currentStatus => _currentSession?.status ?? 'offline';

  /// ========================================================================
  /// INIZIO TURNO (GO ONLINE)
  /// ========================================================================
  Future<DriverSession?> startShift() async {
    print('🚀 [DRIVER SESSION] Avvio turno...');

    try {
      // 1. Ottieni posizione corrente
      final location = await _locationService.getCurrentLocation();
      print(
        '📍 [DRIVER SESSION] Posizione iniziale: ${location.formattedCoords}',
      );

      // 2. Ottieni driver ID da SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getInt(AppConstants.keyDriverId);
      final apiToken = prefs.getString(AppConstants.keyApiToken);

      if (driverId == null || apiToken == null) {
        throw Exception('Driver non autenticato');
      }

      // 3. Chiama API backend per creare sessione
      final response = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/driver/session/start'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiToken',
            },
            body: jsonEncode({
              'driver_id': driverId,
              'start_latitude': location.latitude,
              'start_longitude': location.longitude,
              'current_latitude': location.latitude,
              'current_longitude': location.longitude,
            }),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);

        // Il backend ora ritorna: {success: true, data: {session: {...}}}
        if (body['success'] == true &&
            body['data'] != null &&
            body['data']['session'] != null) {
          _currentSession = DriverSession.fromJson(body['data']['session']);

          // 4. Avvia tracking GPS continuo
          await _startLocationTracking();

          print('✅ [DRIVER SESSION] Turno avviato: ${_currentSession!.id}');
          return _currentSession;
        } else {
          throw Exception('Risposta backend non valida');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error']?['message'] ?? 'Errore avvio turno');
      }
    } catch (e) {
      print('❌ [DRIVER SESSION] Errore avvio turno: $e');
      rethrow;
    }
  }

  /// ========================================================================
  /// FINE TURNO (GO OFFLINE)
  /// ========================================================================
  Future<void> endShift() async {
    if (_currentSession == null) {
      print('⚠️ [DRIVER SESSION] Nessuna sessione attiva da terminare');
      return;
    }

    print('🛑 [DRIVER SESSION] Termine turno...');

    try {
      // 1. Ferma tracking GPS
      await _stopLocationTracking();

      // 2. Ottieni API token
      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString(AppConstants.keyApiToken);

      if (apiToken == null) {
        throw Exception('Token API non trovato');
      }

      // 3. Chiama API backend per terminare sessione
      final response = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/driver/session/end'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiToken',
            },
            body: jsonEncode({'session_id': _currentSession!.id}),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        print('✅ [DRIVER SESSION] Turno terminato');
        _currentSession = null;
      } else {
        throw Exception('Errore termine turno: ${response.body}');
      }
    } catch (e) {
      print('❌ [DRIVER SESSION] Errore termine turno: $e');
      rethrow;
    }
  }

  /// ========================================================================
  /// AGGIORNA STATUS (online/busy)
  /// ========================================================================
  Future<void> updateStatus(String newStatus) async {
    if (_currentSession == null) {
      print('⚠️ [DRIVER SESSION] Nessuna sessione attiva');
      return;
    }

    print('🔄 [DRIVER SESSION] Aggiornamento status: $newStatus');

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString(AppConstants.keyApiToken);

      final response = await http
          .put(
            Uri.parse('${AppConstants.apiUrl}/driver/session/status'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiToken',
            },
            body: jsonEncode({
              'session_id': _currentSession!.id,
              'status': newStatus,
            }),
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        _currentSession = _currentSession!.copyWith(status: newStatus);
        print('✅ [DRIVER SESSION] Status aggiornato: $newStatus');
      }
    } catch (e) {
      print('❌ [DRIVER SESSION] Errore aggiornamento status: $e');
      rethrow;
    }
  }

  /// ========================================================================
  /// TRACKING GPS CONTINUO
  /// ========================================================================
  Future<void> _startLocationTracking() async {
    print('🎯 [DRIVER SESSION] Avvio tracking GPS...');

    // Avvia stream GPS
    await _locationService.startTracking();

    // Ascolta aggiornamenti posizione ogni 10 secondi
    _locationSubscription = _locationService.locationStream.listen(
      (LocationPoint location) async {
        await _updateLocationToServer(location);
      },
      onError: (error) {
        print('❌ [DRIVER SESSION] Errore stream GPS: $error');
      },
    );

    print('✅ [DRIVER SESSION] Tracking GPS avviato');
  }

  Future<void> _stopLocationTracking() async {
    print('🛑 [DRIVER SESSION] Arresto tracking GPS...');
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _locationService.stopTracking();
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    print('✅ [DRIVER SESSION] Tracking GPS arrestato');
  }

  /// Invia posizione al backend
  Future<void> _updateLocationToServer(LocationPoint location) async {
    if (_currentSession == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString(AppConstants.keyApiToken);

      await http
          .put(
            Uri.parse('${AppConstants.apiUrl}/driver/session/location'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiToken',
            },
            body: jsonEncode({
              'session_id': _currentSession!.id,
              'latitude': location.latitude,
              'longitude': location.longitude,
              'accuracy': location.accuracy,
              'speed': location.speed,
              'timestamp': location.timestamp.toIso8601String(),
            }),
          )
          .timeout(Duration(seconds: 10));

      print(
        '📡 [DRIVER SESSION] Posizione inviata: ${location.formattedCoords}',
      );
    } catch (e) {
      print('⚠️ [DRIVER SESSION] Errore invio posizione: $e');
      // Non bloccare il flusso per errori di rete
    }
  }

  /// ========================================================================
  /// RECUPERA SESSIONE ATTIVA (al riavvio app)
  /// ========================================================================
  Future<DriverSession?> fetchActiveSession() async {
    print('🔍 [DRIVER SESSION] Recupero sessione attiva...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getInt(AppConstants.keyDriverId);
      final apiToken = prefs.getString(AppConstants.keyApiToken);

      if (driverId == null || apiToken == null) {
        return null;
      }

      final response = await http
          .get(
            Uri.parse(
              '${AppConstants.apiUrl}/driver/session/active?driver_id=$driverId',
            ),
            headers: {'Authorization': 'Bearer $apiToken'},
          )
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        // Il backend ora ritorna: {success: true, data: {session: {...} o null}}
        if (body['success'] == true && body['data'] != null) {
          final sessionData = body['data']['session'];

          if (sessionData != null && sessionData is Map<String, dynamic>) {
            _currentSession = DriverSession.fromJson(sessionData);

            // Riavvia tracking se sessione attiva
            if (_currentSession!.isActive) {
              await _startLocationTracking();
            }

            print(
              '✅ [DRIVER SESSION] Sessione recuperata: ${_currentSession!.id}',
            );
            return _currentSession;
          }
        }
      }

      print('ℹ️ [DRIVER SESSION] Nessuna sessione attiva trovata');
      return null;
    } catch (e) {
      print('❌ [DRIVER SESSION] Errore recupero sessione: $e');
      return null;
    }
  }

  /// Pulisci risorse
  void dispose() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _locationService.dispose();
    print('🧹 [DRIVER SESSION] Risorse pulite');
  }
}
