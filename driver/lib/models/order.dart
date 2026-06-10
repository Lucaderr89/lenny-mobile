import 'dart:convert';

/// Una tappa del giro ottimizzato (ritiro o consegna di un ordine).
class RouteStop {
  final String type; // 'pickup' | 'delivery'
  final int orderId;
  final double lat;
  final double lng;
  final double cumTime; // minuti cumulati dall'inizio del giro

  RouteStop({
    required this.type,
    required this.orderId,
    required this.lat,
    required this.lng,
    required this.cumTime,
  });

  bool get isPickup => type == 'pickup';
  bool get isDelivery => type == 'delivery';

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      type: json['type']?.toString() ?? '',
      orderId: int.tryParse(json['order_id']?.toString() ?? '0') ?? 0,
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0.0,
      cumTime: double.tryParse(json['cumtime']?.toString() ?? '0') ?? 0.0,
    );
  }
}

/// Model per un ordine assegnato al driver
class Order {
  final int id;
  final String dateOrder;
  final int timeSlotId;
  final int restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String? restaurantPhone;
  final double restaurantLat;
  final double restaurantLng;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final String? deliveryNotes;
  final double total;
  final String status;
  final String assignedAt;
  final String? pickedUpAt;
  final String? confirmedAt;
  final String timeSlot;
  final String batchId;
  final int paymentMethodId;
  final String? paymentMethod;
  final String? paymentMethodDescription;
  final List<OrderProduct> products;
  final String orderSource; // 'food' | 'partner'
  final String?
  partnerType; // 'supermarket' | 'shop' | 'wareshop' | 'other' | null
  // ── Giro ottimizzato (multi-ritiro da ristoranti diversi) ───────────────────
  final int? deliverySequence; // posizione di consegna nel giro (1..N)
  final String? routePlanRaw; // JSON grezzo del giro: chiave di raggruppamento
  final List<RouteStop> routeSteps; // sequenza ritiro/consegna del giro completo

  Order({
    required this.id,
    required this.dateOrder,
    required this.timeSlotId,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    this.restaurantPhone,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    this.deliveryNotes,
    required this.total,
    required this.status,
    required this.assignedAt,
    this.pickedUpAt,
    this.confirmedAt,
    required this.timeSlot,
    required this.batchId,
    required this.paymentMethodId,
    this.paymentMethod,
    this.paymentMethodDescription,
    this.products = const [],
    this.orderSource = 'food',
    this.partnerType,
    this.deliverySequence,
    this.routePlanRaw,
    this.routeSteps = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderProduct> productsList = [];
    if (json['products'] != null && json['products'] is List) {
      productsList = (json['products'] as List)
          .map((p) => OrderProduct.fromJson(p))
          .toList();
    }

    // Giro ottimizzato: route_plan arriva come stringa JSON {"sequence":[...]}
    String? routePlanRaw;
    List<RouteStop> steps = [];
    final rawRoutePlan = json['route_plan'];
    if (rawRoutePlan != null && rawRoutePlan.toString().isNotEmpty) {
      try {
        final decoded = rawRoutePlan is String
            ? jsonDecode(rawRoutePlan)
            : rawRoutePlan;
        if (decoded is Map && decoded['sequence'] is List) {
          routePlanRaw = rawRoutePlan is String
              ? rawRoutePlan
              : jsonEncode(rawRoutePlan);
          steps = (decoded['sequence'] as List)
              .whereType<Map>()
              .map((s) => RouteStop.fromJson(Map<String, dynamic>.from(s)))
              .toList();
        }
      } catch (_) {
        /* route_plan malformato: ignora, l'ordine resta singolo */
      }
    }

    return Order(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      dateOrder: json['date_order'] ?? '',
      timeSlotId: int.tryParse(json['time_slot_id']?.toString() ?? '0') ?? 0,
      restaurantId: int.tryParse(json['restaurant_id']?.toString() ?? '0') ?? 0,
      restaurantName: json['restaurant_name'] ?? '',
      restaurantAddress: json['restaurant_address'] ?? '',
      restaurantPhone: json['restaurant_phone'],
      restaurantLat:
          double.tryParse(json['restaurant_lat']?.toString() ?? '0') ?? 0.0,
      restaurantLng:
          double.tryParse(json['restaurant_lng']?.toString() ?? '0') ?? 0.0,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryLat:
          double.tryParse(json['delivery_lat']?.toString() ?? '0') ?? 0.0,
      deliveryLng:
          double.tryParse(json['delivery_lng']?.toString() ?? '0') ?? 0.0,
      deliveryNotes: json['delivery_notes'],
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? '',
      assignedAt: json['assigned_at'] ?? '',
      pickedUpAt: json['picked_up_at'],
      confirmedAt: json['confirmed_at'],
      timeSlot: json['time_slot'] ?? '',
      batchId: json['batch_id'] ?? '',
      paymentMethodId:
          int.tryParse(json['payment_method_id']?.toString() ?? '0') ?? 0,
      paymentMethod: json['payment_method'],
      paymentMethodDescription: json['payment_method_description'],
      products: productsList,
      orderSource: json['order_source'] ?? 'food',
      partnerType: json['partner_type'],
      deliverySequence: int.tryParse(
        json['delivery_sequence']?.toString() ?? '',
      ),
      routePlanRaw: routePlanRaw,
      routeSteps: steps,
    );
  }

  /// Restituisce il time slot formattato (es: "18:00 - 18:15")
  String get formattedTimeSlot {
    final hour = (timeSlotId ~/ 4).toString().padLeft(2, '0');
    final minute = ((timeSlotId % 4) * 15).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Indica se l'ordine è in stato "assigned" (nuovo, da confermare)
  bool get isNew => status == 'assigned';

  /// Indica se l'ordine partner è pronto al ritiro (merce preparata)
  bool get isReadyForPickup => status == 'ready_for_pickup';

  /// Indica se l'ordine è in fase di ritiro
  bool get isPickingUp => status == 'picking_up';

  /// Indica se l'ordine è in consegna
  bool get isInDelivery => status == 'in_delivery';

  /// PAGATO = pagato online (Stripe/Nexi, payment_method_id 4-5). NON PAGATO =
  /// pagamento offline da incassare alla consegna (Contanti/POS/Smac, id 1-3).
  /// Stessa condizione della guardia in _confirmOrderDelivered: per gli online
  /// (isPaid == true) la conferma consegna NON chiede il metodo di pagamento.
  bool get isPaid => !(paymentMethodId >= 1 && paymentMethodId <= 3);

  /// Indica se è un ordine partner (non food)
  bool get isPartnerOrder => orderSource == 'partner';

  /// Indica se è un ordine supermercato
  bool get isSupermarket => partnerType == 'supermarket';

  /// Indica se è un negozio generico
  bool get isShop => partnerType == 'shop' || partnerType == 'wareshop';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date_order': dateOrder,
      'time_slot_id': timeSlotId,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'restaurant_address': restaurantAddress,
      'restaurant_phone': restaurantPhone,
      'restaurant_lat': restaurantLat,
      'restaurant_lng': restaurantLng,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'delivery_lat': deliveryLat,
      'delivery_lng': deliveryLng,
      'delivery_notes': deliveryNotes,
      'total': total,
      'status': status,
      'assigned_at': assignedAt,
      'picked_up_at': pickedUpAt,
      'confirmed_at': confirmedAt,
      'time_slot': timeSlot,
      'payment_method_id': paymentMethodId,
      'payment_method': paymentMethod,
      'payment_method_description': paymentMethodDescription,
      'products': products.map((p) => p.toJson()).toList(),
    };
  }
}

/// Model per un prodotto dell'ordine
class OrderProduct {
  final String name;
  final int quantity;
  final double price;
  final double total;

  OrderProduct({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      name: json['name'] ?? '',
      quantity: int.tryParse(json['quantity'].toString()) ?? 0,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      total: double.tryParse(json['total'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'quantity': quantity, 'price': price, 'total': total};
  }
}
