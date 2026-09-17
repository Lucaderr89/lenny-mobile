import 'loyalty_tier.dart';

class LoyaltyData {
  final CustomerLoyaltyInfo customer;
  final LoyaltyTier? currentTier;
  final DateTime? tierValidUntil;
  final LoyaltyTier? nextTier;
  final NextTierWindow? nextTierWindow;
  final ProgressToNext? progressToNext;
  final List<LoyaltyTier> allTiers;
  final NextReward? nextReward;
  final int affordableRewards;
  final double pointsPerEuro;
  final double pointsMultiplier;

  LoyaltyData({
    required this.customer,
    this.currentTier,
    this.tierValidUntil,
    this.nextTier,
    this.nextTierWindow,
    this.progressToNext,
    required this.allTiers,
    this.nextReward,
    this.affordableRewards = 0,
    this.pointsPerEuro = 1,
    this.pointsMultiplier = 1,
  });

  factory LoyaltyData.fromJson(Map<String, dynamic> json) {
    return LoyaltyData(
      customer: CustomerLoyaltyInfo.fromJson(json['customer']),
      currentTier: json['current_tier'] != null
          ? LoyaltyTier.fromJson(json['current_tier'])
          : null,
      tierValidUntil: _data(json['tier_valid_until']),
      nextTier: json['next_tier'] != null
          ? LoyaltyTier.fromJson(json['next_tier'])
          : null,
      nextTierWindow: json['next_tier_window'] != null
          ? NextTierWindow.fromJson(json['next_tier_window'])
          : null,
      progressToNext: json['progress_to_next'] != null
          ? ProgressToNext.fromJson(json['progress_to_next'])
          : null,
      allTiers:
          (json['all_tiers'] as List<dynamic>?)
              ?.map((t) => LoyaltyTier.fromJson(t))
              .toList() ??
          [],
      nextReward: json['next_reward'] != null
          ? NextReward.fromJson(json['next_reward'])
          : null,
      affordableRewards:
          int.tryParse('${json['affordable_rewards'] ?? 0}') ?? 0,
      pointsPerEuro: double.tryParse('${json['points_per_euro'] ?? 1}') ?? 1,
      pointsMultiplier:
          double.tryParse('${json['points_multiplier'] ?? 1}') ?? 1,
    );
  }

  static DateTime? _data(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
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
      name: json['name'] ?? json['first_name'] ?? '',
      surname: json['surname'] ?? json['last_name'] ?? '',
      loyaltyPoints: int.parse(json['loyalty_points'].toString()),
      lifetimeSpending: double.parse(json['lifetime_spending'].toString()),
      totalOrdersCompleted: int.parse(
        json['total_orders_completed'].toString(),
      ),
      spendingLast12m: double.parse(json['spending_last_12m'].toString()),
      ordersLast12m: int.parse(json['orders_last_12m'].toString()),
    );
  }

  String get fullName => '$name $surname';
}

/// Il prossimo livello si conquista con N ordini consegnati in una finestra
/// di giorni: il progresso e' in ordini recenti, non in euro di una vita.
class NextTierWindow {
  final String tierName;
  final int ordersInWindow;
  final int ordersRequired;
  final int ordersMissing;
  final int windowDays;
  final int keepDays;

  NextTierWindow({
    required this.tierName,
    required this.ordersInWindow,
    required this.ordersRequired,
    required this.ordersMissing,
    required this.windowDays,
    required this.keepDays,
  });

  factory NextTierWindow.fromJson(Map<String, dynamic> json) {
    return NextTierWindow(
      tierName: json['tier_name'] ?? '',
      ordersInWindow: int.tryParse('${json['orders_in_window'] ?? 0}') ?? 0,
      ordersRequired: int.tryParse('${json['orders_required'] ?? 0}') ?? 0,
      ordersMissing: int.tryParse('${json['orders_missing'] ?? 0}') ?? 0,
      windowDays: int.tryParse('${json['window_days'] ?? 0}') ?? 0,
      keepDays: int.tryParse('${json['keep_days'] ?? 0}') ?? 0,
    );
  }

  double get progress =>
      ordersRequired > 0 ? (ordersInWindow / ordersRequired).clamp(0, 1) : 1;
}

/// Il primo premio che il cliente non puo' ancora permettersi.
class NextReward {
  final String name;
  final int pointsRequired;
  final int pointsMissing;

  NextReward({
    required this.name,
    required this.pointsRequired,
    required this.pointsMissing,
  });

  factory NextReward.fromJson(Map<String, dynamic> json) {
    return NextReward(
      name: json['name'] ?? '',
      pointsRequired: int.tryParse('${json['points_required'] ?? 0}') ?? 0,
      pointsMissing: int.tryParse('${json['points_missing'] ?? 0}') ?? 0,
    );
  }
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
