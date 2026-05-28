class LoyaltyReward {
  final int id;
  final String name;
  final String description;
  final int pointsRequired;
  final String rewardType;
  final String category;
  final int? couponId;
  final String? couponCode;
  final String? couponName;
  final String? imageUrl;
  final int? stockQuantity;
  final int stockConsumed;
  final bool isActive;
  final int displayOrder;
  
  // Campi calcolati dall'API
  final bool? canAfford;
  final int? pointsMissing;
  final bool? isAvailable;

  LoyaltyReward({
    required this.id,
    required this.name,
    required this.description,
    required this.pointsRequired,
    required this.rewardType,
    required this.category,
    this.couponId,
    this.couponCode,
    this.couponName,
    this.imageUrl,
    this.stockQuantity,
    required this.stockConsumed,
    required this.isActive,
    required this.displayOrder,
    this.canAfford,
    this.pointsMissing,
    this.isAvailable,
  });

  factory LoyaltyReward.fromJson(Map<String, dynamic> json) {
    return LoyaltyReward(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      pointsRequired: int.parse(json['points_required'].toString()),
      rewardType: json['reward_type'] ?? 'coupon',
      category: json['category'] ?? 'general',
      couponId: json['coupon_id'] != null 
          ? int.parse(json['coupon_id'].toString()) 
          : null,
      couponCode: json['coupon_code'],
      couponName: json['coupon_name'],
      imageUrl: json['image_url'],
      stockQuantity: json['stock_quantity'] != null 
          ? int.parse(json['stock_quantity'].toString()) 
          : null,
      stockConsumed: int.parse(json['stock_consumed']?.toString() ?? '0'),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      displayOrder: int.parse(json['display_order']?.toString() ?? '0'),
      canAfford: json['can_afford'],
      pointsMissing: json['points_missing'] != null 
          ? int.parse(json['points_missing'].toString()) 
          : null,
      isAvailable: json['is_available'],
    );
  }

  bool get isOutOfStock {
    if (stockQuantity == null) return false;
    return stockConsumed >= stockQuantity!;
  }

  String get categoryLabel {
    switch (category) {
      case 'discount':
        return 'Sconto';
      case 'free_delivery':
        return 'Consegna Gratis';
      case 'free_item':
        return 'Prodotto Gratis';
      case 'experience':
        return 'Esperienza';
      default:
        return 'Altro';
    }
  }
}
