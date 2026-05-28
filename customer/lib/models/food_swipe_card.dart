class FoodSwipeCard {
  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final int restaurantId;
  final String restaurantName;
  final double price;

  FoodSwipeCard({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.restaurantId,
    required this.restaurantName,
    required this.price,
  });

  factory FoodSwipeCard.fromJson(Map<String, dynamic> json) {
    return FoodSwipeCard(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String,
      restaurantId: json['restaurant_id'] as int,
      restaurantName: json['restaurant_name'] as String,
      price: (json['price'] as num).toDouble(),
    );
  }
}
