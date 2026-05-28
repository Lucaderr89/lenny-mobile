/// Modello per il gioco Recipe Scrambler
library;

/// Rappresenta una singola lettera con la sua posizione
class ScrambledLetter {
  final String letter;
  final int originalIndex; // Posizione nella soluzione corretta
  final int? currentIndex; // Posizione corrente (null se non posizionata)
  final bool isSpace; // True se è uno spazio fisso

  ScrambledLetter({
    required this.letter,
    required this.originalIndex,
    this.currentIndex,
    this.isSpace = false,
  });

  ScrambledLetter copyWith({
    String? letter,
    int? originalIndex,
    int? currentIndex,
    bool? isSpace,
  }) {
    return ScrambledLetter(
      letter: letter ?? this.letter,
      originalIndex: originalIndex ?? this.originalIndex,
      currentIndex: currentIndex,
      isSpace: isSpace ?? this.isSpace,
    );
  }
}

/// Rappresenta un piatto nel gioco Recipe Scrambler
class RecipeScramblerDish {
  final int id;
  final String name; // Nome originale del piatto
  final String imageUrl;
  final int restaurantId;
  final String restaurantName;

  RecipeScramblerDish({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.restaurantId,
    required this.restaurantName,
  });

  factory RecipeScramblerDish.fromJson(Map<String, dynamic> json) {
    return RecipeScramblerDish(
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

/// Rappresenta un round del gioco Recipe Scrambler
class RecipeScramblerRound {
  final RecipeScramblerDish dish;
  final List<String>
  scrambledLetters; // Lettere mischiate (gli spazi rimangono fissi)

  RecipeScramblerRound({required this.dish, required this.scrambledLetters});

  factory RecipeScramblerRound.fromJson(Map<String, dynamic> json) {
    return RecipeScramblerRound(
      dish: RecipeScramblerDish.fromJson(json['dish'] as Map<String, dynamic>),
      scrambledLetters: (json['scrambled_letters'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'dish': dish.toJson(), 'scrambled_letters': scrambledLetters};
  }
}
