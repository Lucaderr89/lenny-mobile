import 'dart:convert';

class LoyaltyTier {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final String? color;
  final double unlockLifetimeSpending;
  final int unlockMinOrders;
  final int? windowDays;
  final int? keepDays;
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
    this.windowDays,
    this.keepDays,
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
      unlockLifetimeSpending:
          double.tryParse('${json['unlock_lifetime_spending'] ?? 0}') ?? 0,
      unlockMinOrders: int.tryParse('${json['unlock_min_orders'] ?? 0}') ?? 0,
      windowDays: _intoNull(json['window_days']),
      keepDays: _intoNull(json['keep_days']),
      maintainSpending12m: json['maintain_spending_12m'] != null
          ? double.tryParse(json['maintain_spending_12m'].toString())
          : null,
      maintainMinOrders12m: _intoNull(json['maintain_min_orders_12m']),
      pointsMultiplier:
          double.tryParse('${json['points_multiplier'] ?? 1}') ?? 1,
      description: json['description'],
      benefitsList: json['benefits_list'],
      displayOrder: int.tryParse('${json['display_order'] ?? 0}') ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      customerCount: _intoNull(json['customer_count']),
    );
  }

  static int? _intoNull(dynamic v) {
    if (v == null) return null;
    final n = int.tryParse(v.toString());
    return (n == null || n == 0) ? null : n;
  }

  /// Livello base: e' di tutti, non si conquista.
  bool get isBase => windowDays == null || unlockMinOrders <= 0;

  /// "5 ordini in 30 giorni" oppure "Per tutti, da subito".
  String get requisito {
    if (isBase) return 'Per tutti, da subito';
    return '$unlockMinOrders ordini in $windowDays giorni';
  }

  /// "Vale 60 giorni" oppure stringa vuota.
  String get durata => keepDays == null ? '' : 'Vale $keepDays giorni';

  /// "x1,25" / "x1,5" / "x2": senza zeri inutili, virgola italiana.
  String get moltiplicatoreLabel {
    var s = pointsMultiplier.toStringAsFixed(2);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return 'x${s.replaceAll('.', ',')}';
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
