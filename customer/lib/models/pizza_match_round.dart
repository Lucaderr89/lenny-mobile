/// Modello per il gioco Pizza Match
library;

/// Rappresenta una pizza nel gioco Pizza Match
class PizzaMatchPizza {
  final int id;
  final String name;
  final String imageUrl;
  final int restaurantId;
  final String restaurantName;

  PizzaMatchPizza({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.restaurantId,
    required this.restaurantName,
  });

  factory PizzaMatchPizza.fromJson(Map<String, dynamic> json) {
    return PizzaMatchPizza(
      id: json['id'] as int,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
      restaurantId: json['restaurant_id'] as int,
      restaurantName: json['restaurant_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
    };
  }
}

/// Rappresenta un ingrediente nel gioco Pizza Match
class PizzaIngredient {
  final int id;
  final String name;

  PizzaIngredient({required this.id, required this.name});

  factory PizzaIngredient.fromJson(Map<String, dynamic> json) {
    return PizzaIngredient(id: json['id'] as int, name: json['name'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

/// Rappresenta un round del gioco Pizza Match
class PizzaMatchRound {
  final PizzaMatchPizza pizza;
  final List<String> correctIngredients;
  final List<PizzaIngredient> allIngredients;

  PizzaMatchRound({
    required this.pizza,
    required this.correctIngredients,
    required this.allIngredients,
  });

  factory PizzaMatchRound.fromJson(Map<String, dynamic> json) {
    return PizzaMatchRound(
      pizza: PizzaMatchPizza.fromJson(json['pizza'] as Map<String, dynamic>),
      correctIngredients: (json['correct_ingredients'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      allIngredients: (json['all_ingredients'] as List<dynamic>)
          .map((e) => PizzaIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pizza': pizza.toJson(),
      'correct_ingredients': correctIngredients,
      'all_ingredients': allIngredients.map((e) => e.toJson()).toList(),
    };
  }
}
