/// Model per un singolo preferito
class Favorite {
  final int id;
  final int customerId;
  final String type; // 'restaurant' o 'dish'
  final int itemId;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.customerId,
    required this.type,
    required this.itemId,
    required this.createdAt,
  });

  /// Crea un Favorite da JSON dell'API
  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as int,
      customerId: json['customer_id'] as int,
      type: json['favoritable_type'] as String,
      itemId: json['favoritable_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converte in JSON per l'API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'favoritable_type': type,
      'favoritable_id': itemId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Favorite &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          itemId == other.itemId;

  @override
  int get hashCode => type.hashCode ^ itemId.hashCode;

  @override
  String toString() => 'Favorite(type: $type, itemId: $itemId)';
}

/// Model per gruppi di preferiti (per UI)
class FavoriteGroup {
  final RestaurantBasic restaurant;
  final bool isRestaurantFavorite;
  final DateTime? restaurantFavoriteAddedAt;
  final List<DishBasic> favoriteDishes;

  FavoriteGroup({
    required this.restaurant,
    required this.isRestaurantFavorite,
    this.restaurantFavoriteAddedAt,
    required this.favoriteDishes,
  });

  factory FavoriteGroup.fromJson(Map<String, dynamic> json) {
    return FavoriteGroup(
      restaurant: RestaurantBasic.fromJson(
        json['restaurant'] as Map<String, dynamic>,
      ),
      isRestaurantFavorite: json['is_favorite'] as bool? ?? false,
      restaurantFavoriteAddedAt: json['favorite_added_at'] != null
          ? DateTime.parse(json['favorite_added_at'] as String)
          : null,
      favoriteDishes:
          (json['dishes'] as List<dynamic>?)
              ?.map((d) => DishBasic.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Dati basilari di un ristorante (dal gruppo preferiti)
class RestaurantBasic {
  final int id;
  final String name;
  final String? alias;
  final String? description;
  final String? imageUrl;

  RestaurantBasic({
    required this.id,
    required this.name,
    this.alias,
    this.description,
    this.imageUrl,
  });

  factory RestaurantBasic.fromJson(Map<String, dynamic> json) {
    return RestaurantBasic(
      id: json['id'] as int,
      name: json['name'] as String,
      alias: json['alias'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image'] as String?,
    );
  }
}

/// Dati basilari di un piatto (dal gruppo preferiti)
class DishBasic {
  final int id;
  final String name;
  final String? description;
  final double price;
  final double? discountedPrice;
  final String? imageUrl;
  final DateTime favoriteAddedAt;

  DishBasic({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.discountedPrice,
    this.imageUrl,
    required this.favoriteAddedAt,
  });

  factory DishBasic.fromJson(Map<String, dynamic> json) {
    return DishBasic(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: double.parse(json['price'].toString()),
      discountedPrice:
          json['discounted_price'] != null && json['discounted_price'] != '0.00'
          ? double.parse(json['discounted_price'].toString())
          : null,
      imageUrl: json['image'] as String?,
      favoriteAddedAt: DateTime.parse(json['favorite_added_at'] as String),
    );
  }

  double get actualPrice => discountedPrice ?? price;
}
