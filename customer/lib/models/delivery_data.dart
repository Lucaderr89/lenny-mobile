/// Model per rappresentare i dati di consegna di un ordine
class DeliveryData {
  final String source; // 'saved_address' | 'current_position'

  // Dati per current_position
  final String? address;
  final String? city;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? notes;

  // Dati per saved_address
  final int? savedAddressId;

  // Opzionale: salva indirizzo per uso futuro
  final bool saveAddress;
  final String? addressAlias;

  DeliveryData({
    required this.source,
    this.address,
    this.city,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.notes,
    this.savedAddressId,
    this.saveAddress = false,
    this.addressAlias,
  }) : assert(
         source == 'saved_address' && savedAddressId != null ||
             source == 'current_position' &&
                 address != null &&
                 latitude != null &&
                 longitude != null,
         'Se source=saved_address serve savedAddressId, se source=current_position servono address, latitude, longitude',
       );

  /// Factory per creare da posizione corrente
  factory DeliveryData.fromCurrentPosition({
    required String address,
    required double latitude,
    required double longitude,
    String? city,
    String? postalCode,
    String? notes,
    bool saveAddress = false,
    String? addressAlias,
  }) {
    return DeliveryData(
      source: 'current_position',
      address: address,
      city: city,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
      saveAddress: saveAddress,
      addressAlias: addressAlias,
    );
  }

  /// Factory per creare da indirizzo salvato
  factory DeliveryData.fromSavedAddress({required int savedAddressId}) {
    return DeliveryData(
      source: 'saved_address',
      savedAddressId: savedAddressId,
    );
  }

  /// Converte in JSON per invio API
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'source': source};

    if (source == 'current_position') {
      json['address'] = address;
      if (city != null) json['city'] = city;
      if (postalCode != null) json['postal_code'] = postalCode;
      json['latitude'] = latitude;
      json['longitude'] = longitude;
      if (notes != null && notes!.isNotEmpty) json['notes'] = notes;
      json['save_address'] = saveAddress;
      if (saveAddress && addressAlias != null) {
        json['address_alias'] = addressAlias;
      }
    } else if (source == 'saved_address') {
      json['saved_address_id'] = savedAddressId;
    }

    return json;
  }

  /// Crea da JSON (per deserializzazione)
  factory DeliveryData.fromJson(Map<String, dynamic> json) {
    return DeliveryData(
      source: json['source'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      notes: json['notes'] as String?,
      savedAddressId: json['saved_address_id'] as int?,
      saveAddress: json['save_address'] as bool? ?? false,
      addressAlias: json['address_alias'] as String?,
    );
  }

  @override
  String toString() {
    return 'DeliveryData(source: $source, address: $address, lat: $latitude, lng: $longitude, savedId: $savedAddressId)';
  }
}
