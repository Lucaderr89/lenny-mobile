import 'loyalty_tier.dart';

class LoyaltyData {
  final CustomerLoyaltyInfo customer;
  final LoyaltyTier? currentTier;
  final LoyaltyTier? nextTier;
  final ProgressToNext? progressToNext;
  final List<LoyaltyTier> allTiers;

  LoyaltyData({
    required this.customer,
    this.currentTier,
    this.nextTier,
    this.progressToNext,
    required this.allTiers,
  });

  factory LoyaltyData.fromJson(Map<String, dynamic> json) {
    return LoyaltyData(
      customer: CustomerLoyaltyInfo.fromJson(json['customer']),
      currentTier: json['current_tier'] != null 
          ? LoyaltyTier.fromJson(json['current_tier']) 
          : null,
      nextTier: json['next_tier'] != null 
          ? LoyaltyTier.fromJson(json['next_tier']) 
          : null,
      progressToNext: json['progress_to_next'] != null 
          ? ProgressToNext.fromJson(json['progress_to_next']) 
          : null,
      allTiers: (json['all_tiers'] as List<dynamic>?)
          ?.map((t) => LoyaltyTier.fromJson(t))
          .toList() ?? [],
    );
  }
}

class CustomerLoyaltyInfo {
  final int id;
  final String name;
  final String surname;
  final int loyaltyPoints;
  final double lifetimeSpending;
  final int totalOrdersCompleted;
  final double spendingLast12m;
  final int ordersLast12m;

  CustomerLoyaltyInfo({
    required this.id,
    required this.name,
    required this.surname,
    required this.loyaltyPoints,
    required this.lifetimeSpending,
    required this.totalOrdersCompleted,
    required this.spendingLast12m,
    required this.ordersLast12m,
  });

  factory CustomerLoyaltyInfo.fromJson(Map<String, dynamic> json) {
    return CustomerLoyaltyInfo(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      loyaltyPoints: int.parse(json['loyalty_points'].toString()),
      lifetimeSpending: double.parse(json['lifetime_spending'].toString()),
      totalOrdersCompleted: int.parse(json['total_orders_completed'].toString()),
      spendingLast12m: double.parse(json['spending_last_12m'].toString()),
      ordersLast12m: int.parse(json['orders_last_12m'].toString()),
    );
  }

  String get fullName => '$name $surname';
}

class ProgressToNext {
  final double spendingNeeded;
  final int ordersNeeded;
  final double spendingProgress;
  final double ordersProgress;

  ProgressToNext({
    required this.spendingNeeded,
    required this.ordersNeeded,
    required this.spendingProgress,
    required this.ordersProgress,
  });

  factory ProgressToNext.fromJson(Map<String, dynamic> json) {
    return ProgressToNext(
      spendingNeeded: double.parse(json['spending_needed'].toString()),
      ordersNeeded: int.parse(json['orders_needed'].toString()),
      spendingProgress: double.parse(json['spending_progress'].toString()),
      ordersProgress: double.parse(json['orders_progress'].toString()),
    );
  }
}
