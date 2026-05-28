/// Model per una consegna completata nello storico
class DeliveryHistory {
  final int id;
  final String dateOrder;
  final int timeSlotId;
  final String timeSlot;
  final int restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String customerName;
  final String customerAddress;
  final double total;
  final String? paymentMethod;
  final String? paymentMethodDescription;
  final String assignedAt;
  final String? pickedUpAt;
  final String deliveredAt;
  final int? deliveryTimeMinutes;
  final List<DeliveryProduct> products;

  DeliveryHistory({
    required this.id,
    required this.dateOrder,
    required this.timeSlotId,
    required this.timeSlot,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.customerName,
    required this.customerAddress,
    required this.total,
    this.paymentMethod,
    this.paymentMethodDescription,
    required this.assignedAt,
    this.pickedUpAt,
    required this.deliveredAt,
    this.deliveryTimeMinutes,
    this.products = const [],
  });

  factory DeliveryHistory.fromJson(Map<String, dynamic> json) {
    return DeliveryHistory(
      id: int.parse(json['id'].toString()),
      dateOrder: json['date_order'] ?? '',
      timeSlotId: int.parse(json['time_slot_id'].toString()),
      timeSlot: json['time_slot'] ?? '',
      restaurantId: int.parse(json['restaurant_id'].toString()),
      restaurantName: json['restaurant_name'] ?? '',
      restaurantAddress: json['restaurant_address'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerAddress: json['customer_address'] ?? '',
      total: double.tryParse(json['total'].toString()) ?? 0.0,
      paymentMethod: json['payment_method']?.toString(),
      paymentMethodDescription: json['payment_method_description']?.toString(),
      assignedAt: json['assigned_at'] ?? '',
      pickedUpAt: json['picked_up_at'],
      deliveredAt: json['delivered_at'] ?? '',
      deliveryTimeMinutes: json['delivery_time_minutes'] != null
          ? int.tryParse(json['delivery_time_minutes'].toString())
          : null,
      products: json['products'] != null && json['products'] is List
          ? (json['products'] as List)
                .map((p) => DeliveryProduct.fromJson(p))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date_order': dateOrder,
      'time_slot_id': timeSlotId,
      'time_slot': timeSlot,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'restaurant_address': restaurantAddress,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'total': total,
      'payment_method': paymentMethod,
      'payment_method_description': paymentMethodDescription,
      'assigned_at': assignedAt,
      'picked_up_at': pickedUpAt,
      'delivered_at': deliveredAt,
      'delivery_time_minutes': deliveryTimeMinutes,
      'products': products.map((p) => p.toJson()).toList(),
    };
  }
}

/// Prodotto in una consegna completata
class DeliveryProduct {
  final String name;
  final int quantity;
  final double price;

  DeliveryProduct({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory DeliveryProduct.fromJson(Map<String, dynamic> json) {
    return DeliveryProduct(
      name: json['name'] ?? '',
      quantity: int.parse(json['quantity'].toString()),
      price: double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'quantity': quantity, 'price': price};
  }
}

/// Model per le statistiche dello storico consegne
class DeliveryStats {
  final StatsTotal total;
  final StatsPeriod today;
  final StatsPeriod thisWeek;
  final StatsPeriod thisMonth;
  final CashToCollect cashToCollect;
  final StatsBestDay? bestDay;
  final StatsTopRestaurant? topRestaurant;

  DeliveryStats({
    required this.total,
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.cashToCollect,
    this.bestDay,
    this.topRestaurant,
  });

  factory DeliveryStats.fromJson(Map<String, dynamic> json) {
    return DeliveryStats(
      total: StatsTotal.fromJson(json['total']),
      today: StatsPeriod.fromJson(json['today']),
      thisWeek: StatsPeriod.fromJson(json['this_week']),
      thisMonth: StatsPeriod.fromJson(json['this_month']),
      cashToCollect: CashToCollect.fromJson(json['cash_to_collect']),
      bestDay: json['best_day'] != null
          ? StatsBestDay.fromJson(json['best_day'])
          : null,
      topRestaurant: json['top_restaurant'] != null
          ? StatsTopRestaurant.fromJson(json['top_restaurant'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total.toJson(),
      'today': today.toJson(),
      'this_week': thisWeek.toJson(),
      'this_month': thisMonth.toJson(),
      'cash_to_collect': cashToCollect.toJson(),
      if (bestDay != null) 'best_day': bestDay!.toJson(),
      if (topRestaurant != null) 'top_restaurant': topRestaurant!.toJson(),
    };
  }
}

/// Statistiche totali
class StatsTotal {
  final int deliveries;
  final double avgDeliveryMinutes;

  StatsTotal({required this.deliveries, required this.avgDeliveryMinutes});

  factory StatsTotal.fromJson(Map<String, dynamic> json) {
    return StatsTotal(
      deliveries: int.parse(json['deliveries'].toString()),
      avgDeliveryMinutes:
          double.tryParse(json['avg_delivery_minutes'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deliveries': deliveries,
      'avg_delivery_minutes': avgDeliveryMinutes,
    };
  }
}

/// Statistiche per periodo (oggi/settimana/mese)
class StatsPeriod {
  final int deliveries;

  StatsPeriod({required this.deliveries});

  factory StatsPeriod.fromJson(Map<String, dynamic> json) {
    return StatsPeriod(deliveries: int.parse(json['deliveries'].toString()));
  }

  Map<String, dynamic> toJson() {
    return {'deliveries': deliveries};
  }
}

/// Incassi da versare divisi per metodo pagamento
class CashToCollect {
  final double cash;
  final double pos;
  final double smac;
  final double total;

  CashToCollect({
    required this.cash,
    required this.pos,
    required this.smac,
    required this.total,
  });

  factory CashToCollect.fromJson(Map<String, dynamic> json) {
    return CashToCollect(
      cash: double.tryParse(json['cash'].toString()) ?? 0.0,
      pos: double.tryParse(json['pos'].toString()) ?? 0.0,
      smac: double.tryParse(json['smac'].toString()) ?? 0.0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'cash': cash, 'pos': pos, 'smac': smac, 'total': total};
  }
}

/// Record personale: giorno con più consegne
class StatsBestDay {
  final String date;
  final int deliveries;

  StatsBestDay({required this.date, required this.deliveries});

  factory StatsBestDay.fromJson(Map<String, dynamic> json) {
    return StatsBestDay(
      date: json['date'] ?? '',
      deliveries: int.parse(json['deliveries'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date, 'deliveries': deliveries};
  }
}

/// Ristorante più frequente
class StatsTopRestaurant {
  final String name;
  final int deliveries;

  StatsTopRestaurant({required this.name, required this.deliveries});

  factory StatsTopRestaurant.fromJson(Map<String, dynamic> json) {
    return StatsTopRestaurant(
      name: json['name'] ?? '',
      deliveries: int.parse(json['deliveries'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'deliveries': deliveries};
  }
}
