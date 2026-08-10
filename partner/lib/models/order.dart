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
  final int? paymentMethodId;
  final String? paymentMethodName; // 'Contanti', 'Bancomat', 'Online', ...
  final List<OrderItem> items;

  /// Somma delle righe articolo. Il totale dell'ordine comprende anche consegna,
  /// commissione e sconti, quindi da solo non quadra con gli articoli.
  final double itemsTotal;
  final double deliveryFee;
  final double orderFee;
  final double discountAmount;
  final double appCreditsUsed;

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
    this.paymentMethodId,
    this.paymentMethodName,
    required this.items,
    this.itemsTotal = 0,
    this.deliveryFee = 0,
    this.orderFee = 0,
    this.discountAmount = 0,
    this.appCreditsUsed = 0,
  });

  bool get isDelivery => pickupDelivery == 'delivery';
  bool get isPickup => pickupDelivery == 'pickup';
  bool get isCancelled => status == 'cancelled';

  /// Etichetta pagamento per la stampa
  String get paymentLabel {
    if (paymentStatus == 'paid') return 'PAGATO';
    return 'DA PAGARE';
  }

  /// Impronta del pagamento cosi' com'e' stato stampato: se cambia dopo la
  /// stampa (es. da contanti a pagato online) il ristorante va avvisato,
  /// altrimenti in cassa tornano i conti sbagliati. Il nome del metodo e'
  /// incluso per poter descrivere il "prima" nell'avviso.
  String get paymentFingerprint =>
      '${paymentStatus ?? ''}|${paymentMethodId ?? ''}|${paymentMethodName ?? ''}';

  /// Descrizione leggibile del pagamento, per gli avvisi.
  String get paymentDescription {
    final metodo = (paymentMethodName ?? '').trim();
    if (metodo.isEmpty) return paymentLabel;
    return '$paymentLabel ($metodo)';
  }

  /// Descrizione leggibile di un'impronta pagamento salvata.
  static String descriviPagamento(String impronta) {
    final parti = impronta.split('|');
    final stato = parti.isNotEmpty ? parti[0] : '';
    final metodo = parti.length > 2 ? parti[2].trim() : '';
    final etichetta = stato == 'paid' ? 'PAGATO' : 'DA PAGARE';
    return metodo.isEmpty ? etichetta : '$etichetta ($metodo)';
  }

  /// Quota del totale non spiegata da articoli, consegna, servizio e sconti.
  /// Negli ordini importati alcune componenti non sono itemizzate: senza
  /// questa voce la comanda non quadrerebbe mai con il totale.
  double get altreVoci {
    final residuo = total -
        itemsTotal -
        deliveryFee -
        orderFee +
        discountAmount +
        appCreditsUsed;
    return (residuo * 100).roundToDouble() / 100;
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

  static double _num(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0.0;

  factory Order.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] is List)
        ? (json['items'] as List<dynamic>)
              .map((item) => OrderItem.fromJson(item))
              .toList()
        : <OrderItem>[];

    // items_total lo calcola il server; se manca (risposta vecchia) lo si
    // ricava dalle righe, cosi' la comanda resta corretta comunque.
    final itemsTotal = json['items_total'] != null
        ? _num(json['items_total'])
        : items.fold<double>(0, (s, i) => s + i.lineTotal);

    return Order(
      itemsTotal: itemsTotal,
      deliveryFee: _num(json['delivery_fee']),
      orderFee: _num(json['order_fee']),
      discountAmount: _num(json['discount_amount']),
      appCreditsUsed: _num(json['app_credits_used']),
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
      paymentMethodId: int.tryParse(json['payment_method_id']?.toString() ?? ''),
      paymentMethodName: json['payment_method_name']?.toString(),
      items: items,
    );
  }
}

/// Item di un ordine
class OrderItem {
  final int id;
  final String name;
  final int quantity;

  /// Prezzo di UNA unita', gia' comprensivo degli extra scelti.
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

  /// Importo della riga: e' questo che va stampato accanto alla quantita'.
  double get lineTotal => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: double.tryParse(
            (json['unit_price'] ?? json['price'])?.toString() ?? '0',
          ) ??
          0.0,
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
