class Restaurant {
  final int id;
  final String name;
  final String cuisine;
  final int? cuisineId; // ID numerico per filtro client-side
  final double rating;
  final String deliveryTime;
  final String deliveryCost;
  final String minOrder;
  final String? promoText;
  final String imageUrl;
  final String? logoUrl;
  final String priceRange;
  final bool isPremium;
  final List<String> tags;
  final String description;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;

  // 🆕 Dati reali da delivery_zone_roles
  bool? isDeliverable; // null = non ancora caricato
  double? actualDeliveryFee;
  double? actualMinOrder;
  double? actualFreeOver;
  bool? freeDelivery;

  // 🆕 Info disponibilità oraria
  bool? isOpenNow; // true = aperto ora, false = chiuso ora
  String? opensAt; // "HH:MM" prossimo orario apertura oggi
  String? closesAt; // "HH:MM" orario chiusura corrente
  bool? hasAvailabilityRules; // true = ha regole configurate

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    this.cuisineId,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryCost,
    required this.minOrder,
    this.promoText,
    required this.imageUrl,
    this.logoUrl,
    this.priceRange = '€€',
    this.isPremium = false,
    this.tags = const [],
    this.description = '',
    this.address = '',
    this.phone = '',
    this.latitude,
    this.longitude,
    this.isDeliverable,
    this.actualDeliveryFee,
    this.actualMinOrder,
    this.actualFreeOver,
    this.freeDelivery,
    this.isOpenNow,
    this.opensAt,
    this.closesAt,
    this.hasAvailabilityRules,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // Formatta delivery time
    String deliveryTime = '30 min';
    if (json['delivery_settings'] != null &&
        json['delivery_settings']['estimated_time'] != null) {
      final time = json['delivery_settings']['estimated_time'];
      deliveryTime = '$time min';
    }

    // Formatta delivery cost
    String deliveryCost = '€0';
    if (json['delivery_settings'] != null &&
        json['delivery_settings']['base_price'] != null) {
      final cost = json['delivery_settings']['base_price'];
      deliveryCost = cost == 0 || cost == '0' ? 'Gratis' : '€$cost';
    }

    // Formatta min order
    String minOrder = '€0';
    if (json['delivery_settings'] != null &&
        json['delivery_settings']['min_order'] != null) {
      final min = json['delivery_settings']['min_order'];
      minOrder = '€$min';
    }

    // Estrai nome e ID cucina
    String cuisine = 'Cucina varia';
    int? cuisineId;
    if (json['cuisine'] != null && json['cuisine'] is Map) {
      cuisine = json['cuisine']['name']?.toString() ?? cuisine;
      cuisineId = json['cuisine']['id'] as int?;
    } else if (json['cuisine'] != null && json['cuisine'] is String) {
      cuisine = json['cuisine'];
    }

    // Tags da categories
    List<String> tags = [];
    if (json['categories'] != null && json['categories'] is List) {
      tags = (json['categories'] as List)
          .map((c) => c is Map ? (c['name']?.toString() ?? '') : c.toString())
          .where((name) => name.isNotEmpty)
          .toList();
    }
    if (json['is_featured'] == true) {
      tags.add('In evidenza');
    }

    // Estrai URL immagini Firebase
    String? coverUrl;
    if (json['cover_image'] != null && json['cover_image'] is Map) {
      // Usa 'url' se disponibile (URL pubblico Firebase), altrimenti 'file_path'
      coverUrl =
          json['cover_image']['url']?.toString() ??
          json['cover_image']['file_path']?.toString();
    }

    String? logoUrl;
    if (json['logo_image'] != null && json['logo_image'] is Map) {
      // Usa 'url' se disponibile (URL pubblico Firebase), altrimenti 'file_path'
      logoUrl =
          json['logo_image']['url']?.toString() ??
          json['logo_image']['file_path']?.toString();
    }

    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      cuisine: cuisine,
      cuisineId: cuisineId,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      deliveryTime: deliveryTime,
      deliveryCost: deliveryCost,
      minOrder: minOrder,
      promoText: json['promo_text'] as String?,
      imageUrl: coverUrl ?? json['image_url'] as String? ?? '',
      logoUrl: logoUrl,
      priceRange: json['price_range'] as String? ?? '€€',
      isPremium: json['is_featured'] == true,
      tags: tags,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      // 🆕 Info disponibilità oraria dal backend
      isOpenNow: json['is_open_now'] as bool?,
      opensAt: json['opens_at'] as String?,
      closesAt: json['closes_at'] as String?,
      hasAvailabilityRules: json['has_availability_rules'] as bool?,
    );
  }
}
