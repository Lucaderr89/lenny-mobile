/// Model per rappresentare un indirizzo di consegna salvato
class AddressModel {
  final int? id;
  final String aliasAddress; // 'Casa', 'Ufficio', 'Altro'
  final String? name;
  final String? description;
  final String? phone;
  final String address;
  final String? city;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final bool isActive;
  final String? noteForDriver;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AddressModel({
    this.id,
    required this.aliasAddress,
    this.name,
    this.description,
    this.phone,
    required this.address,
    this.city,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.isActive = true,
    this.noteForDriver,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory da JSON (risposta API)
  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as int?,
      aliasAddress: json['alias_address'] as String? ?? 'Altro',
      name: json['name'] as String?,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String,
      city: json['city'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: json['latitude'] != null
          ? double.parse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.parse(json['longitude'].toString())
          : null,
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      noteForDriver: json['note_for_driver'] as String?,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converte in JSON per invio API
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'alias_address': aliasAddress,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (phone != null) 'phone': phone,
      'address': address,
      if (city != null) 'city': city,
      if (postalCode != null) 'postal_code': postalCode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      if (noteForDriver != null) 'note_for_driver': noteForDriver,
      if (note != null) 'note': note,
    };
  }

  /// Crea una copia con modifiche
  AddressModel copyWith({
    int? id,
    String? aliasAddress,
    String? name,
    String? description,
    String? phone,
    String? address,
    String? city,
    String? postalCode,
    double? latitude,
    double? longitude,
    bool? isDefault,
    bool? isActive,
    String? noteForDriver,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      aliasAddress: aliasAddress ?? this.aliasAddress,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      noteForDriver: noteForDriver ?? this.noteForDriver,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Indirizzo formattato per visualizzazione
  String get formattedAddress {
    // Restituisce solo l'indirizzo senza il name/alias
    // perché ora viene mostrato separatamente come titolo
    return address;
  }

  /// Emoji per tipo indirizzo
  String get emoji {
    final alias = aliasAddress.toLowerCase();
    if (alias.contains('casa') || alias.contains('home')) return '🏠';
    if (alias.contains('lavoro') ||
        alias.contains('ufficio') ||
        alias.contains('work')) {
      return '💼';
    }
    if (alias.contains('scuola') || alias.contains('università')) return '🎓';
    return '📍';
  }

  @override
  String toString() {
    return 'AddressModel(id: $id, alias: $aliasAddress, address: $address, default: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddressModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
