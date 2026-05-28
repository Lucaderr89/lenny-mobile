/// Modello per i dati del driver
class Driver {
  final int id;
  final String name;
  final String email;
  final String? apiToken; // Token per autenticazione API
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? zip;
  final String? country;
  final String employmentStatus; // active, inactive, suspended
  final String? startingPoint;
  final double? startingPointLng;
  final double? startingPointLat;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    this.apiToken,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.zip,
    this.country,
    required this.employmentStatus,
    this.startingPoint,
    this.startingPointLng,
    this.startingPointLat,
    this.createdAt,
    this.updatedAt,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      apiToken: json['api_token'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zip: json['zip'] as String?,
      country: json['country'] as String?,
      employmentStatus: json['employment_status'] as String? ?? 'active',
      startingPoint: json['starting_point'] as String?,
      startingPointLng: json['starting_point_lng'] != null
          ? double.tryParse(json['starting_point_lng'].toString())
          : null,
      startingPointLat: json['starting_point_lat'] != null
          ? double.tryParse(json['starting_point_lat'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'api_token': apiToken,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'zip': zip,
      'country': country,
      'employment_status': employmentStatus,
      'starting_point': startingPoint,
      'starting_point_lng': startingPointLng,
      'starting_point_lat': startingPointLat,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isActive => employmentStatus == 'active';
  bool get hasStartingPoint =>
      startingPointLat != null && startingPointLng != null;
}
