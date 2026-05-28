import 'dart:convert';

class LoyaltyTier {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final String? color;
  final double unlockLifetimeSpending;
  final int unlockMinOrders;
  final double? maintainSpending12m;
  final int? maintainMinOrders12m;
  final double pointsMultiplier;
  final String? description;
  final String? benefitsList;
  final int displayOrder;
  final bool isActive;
  final int? customerCount;

  LoyaltyTier({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.color,
    required this.unlockLifetimeSpending,
    required this.unlockMinOrders,
    this.maintainSpending12m,
    this.maintainMinOrders12m,
    required this.pointsMultiplier,
    this.description,
    this.benefitsList,
    required this.displayOrder,
    required this.isActive,
    this.customerCount,
  });

  factory LoyaltyTier.fromJson(Map<String, dynamic> json) {
    return LoyaltyTier(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      icon: json['icon'],
      color: json['color'],
      unlockLifetimeSpending: double.parse(
        json['unlock_lifetime_spending'].toString(),
      ),
      unlockMinOrders: int.parse(json['unlock_min_orders'].toString()),
      maintainSpending12m: json['maintain_spending_12m'] != null
          ? double.parse(json['maintain_spending_12m'].toString())
          : null,
      maintainMinOrders12m: json['maintain_min_orders_12m'] != null
          ? int.parse(json['maintain_min_orders_12m'].toString())
          : null,
      pointsMultiplier: double.parse(json['points_multiplier'].toString()),
      description: json['description'],
      benefitsList: json['benefits_list'],
      displayOrder: int.parse(json['display_order'].toString()),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      customerCount: json['customer_count'] != null
          ? int.parse(json['customer_count'].toString())
          : null,
    );
  }

  List<String> get benefits {
    if (benefitsList == null || benefitsList!.isEmpty) {
      return [];
    }

    // Prova a parsare come JSON array
    if (benefitsList!.trim().startsWith('[')) {
      try {
        final List<dynamic> parsed = json.decode(benefitsList!);
        return parsed
            .map((e) => e.toString())
            .where((b) => b.trim().isNotEmpty)
            .toList();
      } catch (e) {
        // Se fallisce il parse JSON, continua con lo split normale
      }
    }

    // Altrimenti split su newline
    return benefitsList!.split('\n').where((b) => b.trim().isNotEmpty).toList();
  }
}
