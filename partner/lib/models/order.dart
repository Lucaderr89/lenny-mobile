/// Model per un ordine nel sistema partner
class Order {
  final int id;
  final String status;
  final String statusLabel;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double total;
  final String? note;
  final DateTime? createdAt;
  final String timeSlotStart;
  final String timeSlotEnd;
  final String? dateOrder;
  final String pickupDelivery; // 'pickup' o 'delivery'
  final String? paymentStatus; // 'paid', 'pending', ecc.
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.total,
    this.note,
    this.createdAt,
    required this.timeSlotStart,
    required this.timeSlotEnd,
    this.dateOrder,
    required this.pickupDelivery,
    this.paymentStatus,
    required this.items,
  });

  bool get isDelivery => pickupDelivery == 'delivery';
  bool get isPickup => pickupDelivery == 'pickup';

  /// Etichetta pagamento per la stampa
  String get paymentLabel {
    if (paymentStatus == 'paid') return 'PAGATO';
    return 'DA PAGARE';
  }

  String get timeSlot {
    // Difensivo: lo slot può essere assente (es. vecchi ordini import senza
    // fascia denormalizzata) → evita RangeError su substring di stringa vuota.
    String hhmm(String t) => t.length >= 5 ? t.substring(0, 5) : t;
    final start = hhmm(timeSlotStart); // HH:MM
    final end = hhmm(timeSlotEnd); // HH:MM
    if (start.isEmpty && end.isEmpty) return '';
    return '$start-$end';
  }

  String get formattedDate {
    if (dateOrder == null) return '';

    final orderDate = DateTime.parse(dateOrder!);
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    if (orderDate.year == today.year &&
        orderDate.month == today.month &&
        orderDate.day == today.day) {
      return 'Oggi';
    } else if (orderDate.year == tomorrow.year &&
        orderDate.month == tomorrow.month &&
        orderDate.day == tomorrow.day) {
      return 'Domani';
    } else {
      // Formato: Lun 23/12
      final weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
      final weekday = weekdays[orderDate.weekday - 1];
      return '$weekday ${orderDate.day.toString().padLeft(2, '0')}/${orderDate.month.toString().padLeft(2, '0')}';
    }
  }

  // Badge per la visualizzazione nel ristorante
  String get partnerBadgeLabel {
    // Per il ristorante, pending (1) e assigned (2) sono entrambi "nuovi"
    if (status == 'pending' || status == 'assigned') {
      return 'NUOVO';
    } else if (status == 'picking_up') {
      return 'IN RITIRO';
    } else if (status == 'in_delivery') {
      return 'IN CONSEGNA';
    }
    return statusLabel.toUpperCase();
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      status: json['status_name'] ?? 'pending',
      statusLabel: json['status_label'] ?? 'Nuovo',
      customerName: json['customer_name'] ?? 'Cliente',
      customerPhone: json['customer_phone'] ?? '',
      deliveryAddress: json['delivery_address_text'] ?? '',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      note: json['note'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      timeSlotStart: json['time_slot_start'] ?? '',
      timeSlotEnd: json['time_slot_end'] ?? '',
      dateOrder: json['date_order'],
      pickupDelivery: json['pickup_delivery'] ?? 'delivery',
      paymentStatus: json['payment_status']?.toString(),
      items: (json['items'] is List)
          ? (json['items'] as List<dynamic>)
                .map((item) => OrderItem.fromJson(item))
                .toList()
          : [],
    );
  }
}

/// Item di un ordine
class OrderItem {
  final int id;
  final String name;
  final int quantity;
  final double price;
  final String? notes;
  final List<OrderExtra> extras;

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.notes,
    this.extras = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'],
      extras: (json['extras'] is List)
          ? (json['extras'] as List<dynamic>)
                .map((e) => OrderExtra.fromJson(e))
                .toList()
          : [],
    );
  }
}

/// Extra di un item
class OrderExtra {
  final int id;
  final String name;
  final double price;
  final String? groupName;

  OrderExtra({
    required this.id,
    required this.name,
    required this.price,
    this.groupName,
  });

  factory OrderExtra.fromJson(Map<String, dynamic> json) {
    return OrderExtra(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      groupName: json['group_name'],
    );
  }
}
