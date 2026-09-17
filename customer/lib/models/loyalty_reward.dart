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
  final double? creditAmount;
  final String? imageUrl;
  final int? stockQuantity;
  final int stockConsumed;
  final bool isActive;
  final int displayOrder;

  // Campi calcolati dall'API
  final bool? canAfford;
  final int? pointsMissing;
  final bool? isAvailable;
  final bool comingSoon;

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
    this.creditAmount,
    this.imageUrl,
    this.stockQuantity,
    required this.stockConsumed,
    required this.isActive,
    required this.displayOrder,
    this.canAfford,
    this.pointsMissing,
    this.isAvailable,
    this.comingSoon = false,
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
          ? int.tryParse(json['coupon_id'].toString())
          : null,
      couponCode: json['coupon_code'],
      couponName: json['coupon_name'],
      creditAmount: json['credit_amount'] != null
          ? double.tryParse(json['credit_amount'].toString())
          : null,
      imageUrl: json['image_url'],
      stockQuantity: json['stock_quantity'] != null
          ? int.tryParse(json['stock_quantity'].toString())
          : null,
      stockConsumed:
          int.tryParse(json['stock_consumed']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      canAfford: json['can_afford'] == true,
      pointsMissing: json['points_missing'] != null
          ? int.tryParse(json['points_missing'].toString())
          : null,
      isAvailable: json['is_available'] == true,
      comingSoon: json['coming_soon'] == true,
    );
  }

  bool get isOutOfStock {
    if (stockQuantity == null) return false;
    return stockConsumed >= stockQuantity!;
  }

  bool get isCoupon => rewardType == 'coupon';
  bool get isCredit => rewardType == 'app_credit';

  /// Dove finisce il premio una volta riscattato.
  String get typeLabel {
    switch (rewardType) {
      case 'app_credit':
        return 'Crediti nel wallet';
      case 'coupon':
        return 'Coupon al checkout';
      case 'partner_voucher':
        return 'Premio partner';
      case 'physical_gift':
        return 'Regalo';
      default:
        return '';
    }
  }

  /// Quanto manca, da 0 a 1, dato il saldo del cliente.
  double progresso(int punti) {
    if (pointsRequired <= 0) return 1;
    return (punti / pointsRequired).clamp(0, 1).toDouble();
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
