/// Modello per rappresentare una sessione di turno driver
class DriverSession {
  final int? id;
  final int driverId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // 'online', 'offline', 'busy'
  final double? startLatitude;
  final double? startLongitude;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? lastLocationUpdate;
  final double totalDistanceKm;
  final int totalDeliveries;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DriverSession({
    this.id,
    required this.driverId,
    required this.startTime,
    this.endTime,
    required this.status,
    this.startLatitude,
    this.startLongitude,
    this.currentLatitude,
    this.currentLongitude,
    this.lastLocationUpdate,
    this.totalDistanceKm = 0.0,
    this.totalDeliveries = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory per creare da JSON (response API)
  factory DriverSession.fromJson(Map<String, dynamic> json) {
    return DriverSession(
      id: json['id'] as int?,
      driverId: json['driver_id'] as int,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      status: json['status'] as String,
      startLatitude: json['start_latitude'] != null
          ? double.tryParse(json['start_latitude'].toString())
          : null,
      startLongitude: json['start_longitude'] != null
          ? double.tryParse(json['start_longitude'].toString())
          : null,
      currentLatitude: json['current_latitude'] != null
          ? double.tryParse(json['current_latitude'].toString())
          : null,
      currentLongitude: json['current_longitude'] != null
          ? double.tryParse(json['current_longitude'].toString())
          : null,
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.parse(json['last_location_update'] as String)
          : null,
      totalDistanceKm: json['total_distance_km'] != null
          ? double.tryParse(json['total_distance_km'].toString()) ?? 0.0
          : 0.0,
      totalDeliveries: json['total_deliveries'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converti a JSON (per request API)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'driver_id': driverId,
      'start_time': startTime.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      'status': status,
      if (startLatitude != null) 'start_latitude': startLatitude,
      if (startLongitude != null) 'start_longitude': startLongitude,
      if (currentLatitude != null) 'current_latitude': currentLatitude,
      if (currentLongitude != null) 'current_longitude': currentLongitude,
      if (lastLocationUpdate != null)
        'last_location_update': lastLocationUpdate!.toIso8601String(),
      'total_distance_km': totalDistanceKm,
      'total_deliveries': totalDeliveries,
    };
  }

  /// Verifica se la sessione è attiva
  bool get isActive => endTime == null && status != 'offline';

  /// Verifica se il driver è online (disponibile)
  bool get isOnline => status == 'online' && isActive;

  /// Verifica se il driver è occupato (in consegna)
  bool get isBusy => status == 'busy' && isActive;

  /// Calcola durata turno in minuti
  int get durationMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  /// Calcola durata turno formattata (es: "2h 35m")
  String get formattedDuration {
    final minutes = durationMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Verifica se ha posizione corrente
  bool get hasCurrentLocation =>
      currentLatitude != null && currentLongitude != null;

  /// Copia con modifiche
  DriverSession copyWith({
    int? id,
    int? driverId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    double? startLatitude,
    double? startLongitude,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? lastLocationUpdate,
    double? totalDistanceKm,
    int? totalDeliveries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverSession(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DriverSession(id: $id, driverId: $driverId, status: $status, duration: $formattedDuration, deliveries: $totalDeliveries)';
  }
}
