/// Modello per piatti trending (popolare ora)
class TrendingDish {
  final int dishId;
  final String dishName;
  final double price;
  final String? imageUrl;
  final String restaurantName;
  final String? restaurantLogo;
  final int orderCount;
  final DateTime? lastOrdered;
  final int spicyLevel; // Per badge piccante

  TrendingDish({
    required this.dishId,
    required this.dishName,
    required this.price,
    this.imageUrl,
    required this.restaurantName,
    this.restaurantLogo,
    required this.orderCount,
    this.lastOrdered,
    this.spicyLevel = 0,
  });

  String get hotBadge {
    if (orderCount >= 10) return '🔥🔥🔥';
    if (orderCount >= 5) return '🔥🔥';
    if (orderCount >= 1) return '🔥';
    return ''; // No badge per piatti senza ordini
  }

  String get timeAgo {
    // Se non c'è ordine reale, non mostrare tempo
    if (lastOrdered == null || orderCount == 0) {
      return 'Popolare';
    }

    final diff = DateTime.now().difference(lastOrdered!);

    // Minuti (< 60 min)
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min fa';
    }

    // Ore (< 24 ore)
    if (diff.inHours < 24) {
      return '${diff.inHours}h fa';
    }

    // Giorni
    final days = diff.inDays;
    if (days == 1) {
      return '1 giorno fa';
    }
    return '$days giorni fa';
  }

  factory TrendingDish.fromJson(Map<String, dynamic> json) {
    // Parse lastOrdered solo se presente e non null
    DateTime? lastOrdered;
    if (json['last_ordered'] != null) {
      try {
        lastOrdered = DateTime.parse(json['last_ordered'] as String);
      } catch (e) {
        lastOrdered = null;
      }
    }

    return TrendingDish(
      dishId: json['dish_id'] as int,
      dishName: json['dish_name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: _extractImageUrl(json),
      restaurantName: json['restaurant_name'] as String,
      restaurantLogo: json['restaurant_logo'] as String?,
      orderCount: json['order_count'] as int,
      lastOrdered: lastOrdered,
      spicyLevel: json['spicy_level'] as int? ?? 0,
    );
  }

  /// Estrae l'URL dell'immagine dal JSON (stesso pattern di MenuItem)
  static String? _extractImageUrl(Map<String, dynamic> json) {
    // Prova con cover_image (struttura API come MenuItem)
    if (json['cover_image'] != null && json['cover_image'] is Map) {
      final coverImage = json['cover_image'] as Map<String, dynamic>;
      // Usa 'url' se disponibile (URL Firebase)
      return coverImage['url']?.toString() ??
          coverImage['file_path']?.toString();
    }

    // Fallback a image_url diretto
    return json['image_url'] as String?;
  }
}
