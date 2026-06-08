import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/location_point.dart';
import 'driver_location_service.dart';

/// Tracking GPS legato alla PRESENZA DI ORDINI ATTIVI (non ai turni).
///
/// Regola unica: il tracking è acceso finché il driver ha ≥1 ordine attivo
/// (food o partner). Parte all'assegnazione del primo ordine, si ferma quando
/// l'ultimo viene consegnato. Così non si traccia mai un driver fermo/a casa,
/// ma il geofencing funziona per chiunque abbia un ordine — anche fuori turno
/// (urgenze) — e per entrambi i tipi (food e partner).
///
/// Le posizioni vengono inviate a POST /api/driver/track-location, che salva la
/// posizione real-time e fa girare il geofencing lato server.
///
/// IMPORTANTE: il permesso GPS NON viene richiesto qui. Si chiede una sola volta
/// al primo login (come Google Maps). Qui si CONTROLLA solo, in silenzio, se è
/// già concesso: se sì il tracking parte senza alcun popup.
class GeofenceTrackingService {
  GeofenceTrackingService._internal();
  static final GeofenceTrackingService _instance =
      GeofenceTrackingService._internal();
  factory GeofenceTrackingService() => _instance;

  final DriverLocationService _locationService = DriverLocationService();
  StreamSubscription<LocationPoint>? _subscription;
  Timer? _heartbeat;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  /// Allinea lo stato del tracking alla presenza di ordini attivi.
  /// Va chiamato ad ogni refresh ordini (polling 30s + push FCM).
  Future<void> sync({required bool hasActiveOrders}) async {
    if (hasActiveOrders && !_isTracking) {
      await _start();
    } else if (!hasActiveOrders && _isTracking) {
      await _stop();
    }
  }

  Future<void> _start() async {
    // Controlla in SILENZIO se il permesso è già concesso. NON lo richiede:
    // il prompt viene mostrato una sola volta al login.
    final permission = await _locationService.checkPermission();
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!granted) {
      print('⚠️ [TRACKING] Permesso GPS non concesso: tracking non avviato');
      return;
    }

    if (!await _locationService.isLocationServiceEnabled()) {
      print('⚠️ [TRACKING] GPS di sistema disattivo: tracking non avviato');
      return;
    }

    try {
      await _locationService.startTracking();
      _subscription = _locationService.locationStream.listen(
        _sendLocation,
        onError: (e) => print('❌ [TRACKING] Errore stream GPS: $e'),
        cancelOnError: false,
      );
      _isTracking = true;

      // Heartbeat a tempo: invia un punto anche da FERMO (il filtro a 15m da solo
      // non manda nulla se il driver è immobile). Serve a misurare la permanenza
      // al ristorante (dwell anti drive-by) e a tenere fresca la posizione.
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) async {
        try {
          final loc = await _locationService.getCurrentLocation();
          await _sendLocation(loc);
        } catch (e) {
          print('⚠️ [TRACKING] Heartbeat fallito: $e');
        }
      });

      print('✅ [TRACKING] Avviato (ordine attivo presente)');
    } catch (e) {
      print('❌ [TRACKING] Errore avvio tracking: $e');
      _isTracking = false;
    }
  }

  Future<void> _stop() async {
    try {
      _heartbeat?.cancel();
      _heartbeat = null;
      await _subscription?.cancel();
      _subscription = null;
      await _locationService.stopTracking();
    } catch (e) {
      print('❌ [TRACKING] Errore stop tracking: $e');
    } finally {
      _isTracking = false;
      print('🛑 [TRACKING] Fermato (nessun ordine attivo)');
    }
  }

  /// Ferma forzatamente il tracking (es. al logout).
  Future<void> shutdown() async {
    if (_isTracking) {
      await _stop();
    }
  }

  Future<void> _sendLocation(LocationPoint location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString(AppConstants.keyApiToken);
      if (apiToken == null) return;

      await http
          .post(
            Uri.parse(AppConstants.trackLocationEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiToken',
            },
            body: jsonEncode({
              'latitude': location.latitude,
              'longitude': location.longitude,
              'accuracy': location.accuracy,
              'speed': location.speed,
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [TRACKING] Posizione inviata: ${location.formattedCoords}');
    } catch (e) {
      // Non bloccare il flusso per errori di rete: riproverà al prossimo update.
      print('⚠️ [TRACKING] Errore invio posizione: $e');
    }
  }
}
