/// Modello per i piatti del gioco Dish Match
class DishMatchDish {
  final int id;
  final String name;
  final String imageUrl;
  final int restaurantId;
  final String restaurantName;
  final double price;

  DishMatchDish({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.restaurantId,
    required this.restaurantName,
    required this.price,
  });

  factory DishMatchDish.fromJson(Map<String, dynamic> json) {
    return DishMatchDish(
      id: json['id'] as int,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
      restaurantId: json['restaurant_id'] as int,
      restaurantName: json['restaurant_name'] as String,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'price': price,
    };
  }
}
