import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/location_point.dart';

/// Servizio per gestire la geolocalizzazione del driver
/// Basato su location_service.dart della customer app ma con tracking continuo
class DriverLocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<LocationPoint> _locationController =
      StreamController<LocationPoint>.broadcast();

  /// Stream per ascoltare le posizioni in tempo reale
  Stream<LocationPoint> get locationStream => _locationController.stream;

  /// Controlla se il servizio di localizzazione è abilitato
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Controlla lo stato dei permessi di localizzazione
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Richiede i permessi di localizzazione
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Ottiene la posizione corrente una sola volta
  Future<LocationPoint> getCurrentLocation() async {
    print('📍 [DRIVER LOCATION] Richiesta posizione corrente...');

    // 1. Verifica servizio localizzazione
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ [DRIVER LOCATION] Servizio di localizzazione disabilitato');
      throw LocationServiceDisabledException(
        'Il servizio di localizzazione è disabilitato. Attivalo nelle impostazioni.',
      );
    }

    // 2. Verifica permessi
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      print('⚠️ [DRIVER LOCATION] Permesso negato, richiesta...');
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ [DRIVER LOCATION] Permesso negato dall\'utente');
        throw LocationPermissionDeniedException(
          'Permesso di localizzazione negato. Concedi il permesso per continuare.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ [DRIVER LOCATION] Permesso negato permanentemente');
      throw LocationPermissionDeniedException(
        'Permesso negato permanentemente. Attivalo nelle impostazioni del dispositivo.',
      );
    }

    // 3. Ottieni posizione
    try {
      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Timeout durante la ricerca della posizione',
              );
            },
          );

      final locationPoint = LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed * 3.6, // m/s to km/h
        timestamp: DateTime.now(),
      );

      print(
        '✅ [DRIVER LOCATION] Posizione ottenuta: ${locationPoint.formattedCoords}',
      );
      return locationPoint;
    } catch (e) {
      print('❌ [DRIVER LOCATION] Errore: $e');
      rethrow;
    }
  }

  /// Avvia il tracking continuo della posizione in background
  /// Aggiorna posizione ogni 10 secondi o quando si sposta di 10 metri
  Future<void> startTracking() async {
    print('🎯 [DRIVER LOCATION] Avvio tracking continuo...');

    // Verifica servizio localizzazione
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ [DRIVER LOCATION] Servizio di localizzazione disabilitato');
      throw LocationServiceDisabledException(
        'Attiva il GPS nelle impostazioni del dispositivo.',
      );
    }

    // Verifica permessi
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      print('⚠️ [DRIVER LOCATION] Richiesta permessi GPS...');
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ [DRIVER LOCATION] Permesso negato dall\'utente');
        throw LocationPermissionDeniedException(
          'Permesso GPS negato. È necessario per il tracking.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ [DRIVER LOCATION] Permesso negato permanentemente');
      throw LocationPermissionDeniedException(
        'Permesso GPS negato permanentemente. Attivalo nelle impostazioni.',
      );
    }

    // Configura le impostazioni di tracking
    // IMPORTANTE: NO timeLimit per evitare che lo stream si chiuda
    // Il GPS deve rimanere sempre attivo per il geofencing
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // Aggiorna ogni 15 metri (risparmio batteria)
      // timeLimit rimosso: lo stream rimane attivo anche senza aggiornamenti
    );

    // Avvia lo stream
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            final locationPoint = LocationPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              speed: position.speed * 3.6, // m/s to km/h
              timestamp: DateTime.now(),
            );

            print(
              '📍 [DRIVER LOCATION] Aggiornamento: ${locationPoint.formattedCoords} (±${position.accuracy.toStringAsFixed(0)}m)',
            );
            _locationController.add(locationPoint);
          },
          onError: (error) {
            print('❌ [DRIVER LOCATION] Errore stream: $error');
            // Non fermare lo stream in caso di errore temporaneo
            // Lo stream rimarrà attivo e riproverà automaticamente
          },
          cancelOnError:
              false, // IMPORTANTE: non chiudere lo stream per errori temporanei
        );

    print('✅ [DRIVER LOCATION] Tracking avviato con successo');
  }

  /// Ferma il tracking della posizione
  Future<void> stopTracking() async {
    print('🛑 [DRIVER LOCATION] Arresto tracking...');
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    print('✅ [DRIVER LOCATION] Tracking arrestato');
  }

  /// Verifica se il tracking è attivo
  bool get isTracking => _positionStreamSubscription != null;

  /// Calcola distanza tra due coordinate (in metri)
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Calcola distanza tra due LocationPoint (in km)
  double distanceBetweenPoints(LocationPoint start, LocationPoint end) {
    final meters = distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    return meters / 1000; // converti in km
  }

  /// Pulisci risorse
  void dispose() {
    _positionStreamSubscription?.cancel();
    _locationController.close();
    print('🧹 [DRIVER LOCATION] Risorse pulite');
  }
}

/// Eccezioni personalizzate
class LocationServiceDisabledException implements Exception {
  final String message;
  LocationServiceDisabledException(this.message);

  @override
  String toString() => message;
}

class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException(this.message);

  @override
  String toString() => message;
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
