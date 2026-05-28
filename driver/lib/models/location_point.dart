/// Modello per rappresentare una posizione GPS tracciata
class LocationPoint {
  final double latitude;
  final double longitude;
  final double? accuracy; // Precisione in metri
  final double? speed; // Velocità in km/h
  final DateTime timestamp;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Factory per creare da JSON
  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracy: json['accuracy'] != null
          ? double.tryParse(json['accuracy'].toString())
          : null,
      speed: json['speed'] != null
          ? double.tryParse(json['speed'].toString())
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Converti a JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null) 'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Coordinate formattate per debug
  String get formattedCoords =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  @override
  String toString() {
    return 'LocationPoint($formattedCoords, accuracy: ${accuracy?.toStringAsFixed(1)}m, speed: ${speed?.toStringAsFixed(1)}km/h)';
  }
}

/// Modello per aggiornamento location da inviare al backend
class LocationUpdate {
  final int driverSessionId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final DateTime timestamp;

  LocationUpdate({
    required this.driverSessionId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Converti a JSON per API request
  Map<String, dynamic> toJson() {
    return {
      'driver_session_id': driverSessionId,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null) 'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
