import 'package:geolocator/geolocator.dart';

/// Servizio per gestire la geolocalizzazione del dispositivo
class LocationService {
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

  /// Ottiene la posizione corrente
  ///
  /// Gestisce automaticamente controlli su permessi e servizi
  /// Lancia eccezioni dettagliate in caso di errori
  Future<Position> getCurrentPosition() async {
    print('📍 [LOCATION] Richiesta posizione corrente...');

    // 1. Verifica se il servizio di localizzazione è abilitato
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ [LOCATION] Servizio di localizzazione disabilitato');
      throw LocationServiceDisabledException(
        'Il servizio di localizzazione è disabilitato. Attivalo nelle impostazioni del dispositivo.',
      );
    }

    // 2. Controlla i permessi
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      print('⚠️ [LOCATION] Permesso negato, richiesta...');
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ [LOCATION] Permesso negato dall\'utente');
        throw LocationPermissionDeniedException(
          'Permesso di localizzazione negato. Concedi il permesso per continuare.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ [LOCATION] Permesso negato permanentemente');
      throw LocationPermissionDeniedException(
        'Permesso di localizzazione negato permanentemente. Attivalo manualmente nelle impostazioni del dispositivo.',
      );
    }

    // 3. Ottieni la posizione
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

      print(
        '✅ [LOCATION] Posizione ottenuta: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      print('❌ [LOCATION] Errore: $e');
      rethrow;
    }
  }

  /// Calcola la distanza tra due coordinate (in metri)
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Stream della posizione in tempo reale
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}

/// Eccezione quando il servizio di localizzazione è disabilitato
class LocationServiceDisabledException implements Exception {
  final String message;
  LocationServiceDisabledException(this.message);

  @override
  String toString() => message;
}

/// Eccezione quando i permessi sono negati
class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException(this.message);

  @override
  String toString() => message;
}

/// Eccezione per timeout
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
