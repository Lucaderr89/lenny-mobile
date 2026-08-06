class LiveOrder {
  final int id;
  final DateTime createdAt;
  final String dateOrder;
  final int statusId;
  final String statusCode;
  final String statusLabel;
  final String pickupDelivery;
  final double subtotal;
  final double total;
  final double deliveryFee;
  final double? orderFee;
  final double? discountAmount;
  final String? deliveryAddressText;
  final String? deliveryNotes;
  final String? aliasAddressOrder;
  final String? note;
  final String paymentStatus;
  final String? paymentMethod;
  final String? paymentMethodSlug;
  final int restaurantId;
  final String? restaurantName;
  final String? restaurantImage;
  final String? restaurantAddress;
  final String? startTime;
  final String? endTime;
  final int? driverId;
  final String? driverName;
  final String? driverPhone;
  final List<LiveOrderItem> items;
  final bool canCancel; // Calcolato dal backend

  LiveOrder({
    required this.id,
    required this.createdAt,
    required this.dateOrder,
    required this.statusId,
    required this.statusCode,
    required this.statusLabel,
    required this.pickupDelivery,
    required this.subtotal,
    required this.total,
    required this.deliveryFee,
    this.orderFee,
    this.discountAmount,
    this.deliveryAddressText,
    this.deliveryNotes,
    this.aliasAddressOrder,
    this.note,
    required this.paymentStatus,
    this.paymentMethod,
    this.paymentMethodSlug,
    required this.restaurantId,
    this.restaurantName,
    this.restaurantImage,
    this.restaurantAddress,
    this.startTime,
    this.endTime,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.items,
    this.canCancel = false, // Default false
  });

  factory LiveOrder.fromJson(Map<String, dynamic> json) {
    return LiveOrder(
      id: int.parse(json['id'].toString()),
      createdAt: DateTime.parse(json['created_at']),
      dateOrder: json['date_order'],
      statusId: int.parse(json['status_id'].toString()),
      statusCode: json['status_code'],
      statusLabel: json['status_label'],
      pickupDelivery: json['pickup_delivery'],
      subtotal: double.parse(json['subtotal'].toString()),
      total: double.parse(json['total'].toString()),
      deliveryFee: double.parse(json['delivery_fee'].toString()),
      orderFee: json['order_fee'] != null
          ? double.parse(json['order_fee'].toString())
          : null,
      discountAmount: json['discount_amount'] != null
          ? double.parse(json['discount_amount'].toString())
          : null,
      deliveryAddressText: json['delivery_address_text'],
      deliveryNotes: json['delivery_notes'],
      aliasAddressOrder: json['alias_address_order'],
      note: json['note'],
      paymentStatus: json['payment_status'],
      paymentMethod: json['payment_method'],
      paymentMethodSlug: json['payment_method_slug'],
      restaurantId: int.parse(json['restaurant_id'].toString()),
      restaurantName: json['restaurant_name'],
      restaurantImage: json['restaurant_image'],
      restaurantAddress: json['restaurant_address'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      driverId: json['driver_id'] != null
          ? int.parse(json['driver_id'].toString())
          : null,
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => LiveOrderItem.fromJson(item))
              .toList() ??
          [],
      canCancel: json['can_cancel'] == true || json['can_cancel'] == 1,
    );
  }

  /// Restituisce solo il nome (prima parola) del driver
  String get driverFullName {
    if (driverName == null || driverName!.isEmpty) return '';
    final parts = driverName!.split(' ');
    return parts.isNotEmpty ? parts[0] : '';
  }
}

class LiveOrderItem {
  final int id;

  /// Id del piatto (dishes.id): serve al "Riordina" per ritrovare il piatto
  /// nel menu attuale. Null se l'API non lo fornisce.
  final int? foodId;
  final int quantity;
  final double price;
  final double? discountAmount;
  final String? foodName;
  final String? foodDescription;
  final String? extras;

  LiveOrderItem({
    required this.id,
    this.foodId,
    required this.quantity,
    required this.price,
    this.discountAmount,
    this.foodName,
    this.foodDescription,
    this.extras,
  });

  factory LiveOrderItem.fromJson(Map<String, dynamic> json) {
    return LiveOrderItem(
      id: int.parse(json['id'].toString()),
      foodId: json['food_id'] != null
          ? int.tryParse(json['food_id'].toString())
          : null,
      quantity: int.parse(json['quantity'].toString()),
      price: double.parse(json['price'].toString()),
      discountAmount: json['discount_amount'] != null
          ? double.parse(json['discount_amount'].toString())
          : null,
      foodName: json['food_name'],
      foodDescription: json['food_description'],
      extras: json['extras'],
    );
  }
}
