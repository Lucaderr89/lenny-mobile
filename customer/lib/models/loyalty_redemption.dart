class LoyaltyRedemption {
  final int id;
  final int customerId;
  final int rewardId;
  final int pointsSpent;
  final String status;
  final DateTime redeemedAt;
  final DateTime? usedAt;
  final DateTime? couponUsedAt;
  final DateTime? expiresAt;
  final int? orderId;
  final String? couponCode;
  final String? notes;

  // Dati del premio (se inclusi nella risposta)
  final String? rewardName;
  final String? rewardDescription;
  final String? rewardImage;

  LoyaltyRedemption({
    required this.id,
    required this.customerId,
    required this.rewardId,
    required this.pointsSpent,
    required this.status,
    required this.redeemedAt,
    this.usedAt,
    this.couponUsedAt,
    this.expiresAt,
    this.orderId,
    this.couponCode,
    this.notes,
    this.rewardName,
    this.rewardDescription,
    this.rewardImage,
  });

  factory LoyaltyRedemption.fromJson(Map<String, dynamic> json) {
    return LoyaltyRedemption(
      id: int.parse(json['id'].toString()),
      customerId: int.parse(json['customer_id'].toString()),
      rewardId: int.parse(json['reward_id'].toString()),
      pointsSpent: int.parse(json['points_spent'].toString()),
      status: json['status'] ?? 'approved',
      redeemedAt:
          DateTime.tryParse(json['redeemed_at']?.toString() ?? '') ??
          DateTime.now(),
      usedAt: _data(json['used_at']),
      couponUsedAt: _data(json['coupon_used_at']),
      expiresAt: _data(json['expires_at']),
      orderId: json['order_id'] != null
          ? int.tryParse(json['order_id'].toString())
          : null,
      couponCode: json['generated_coupon_code'],
      notes: json['admin_notes'] ?? json['notes'],
      rewardName: json['reward_name'],
      rewardDescription: json['reward_description'],
      rewardImage: json['reward_image'],
    );
  }

  static DateTime? _data(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isExpired => status == 'expired';
  bool get isUsed => status == 'used' || usedAt != null || couponUsedAt != null;

  /// Riscattato e ancora spendibile: i crediti sono gia' nel wallet, il
  /// coupon aspetta il prossimo checkout.
  bool get isActive => !isUsed && (status == 'active' || status == 'approved');

  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    final daysUntilExpiry = expiresAt!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry > 0;
  }

  String get statusLabel {
    if (isUsed) return 'Utilizzato';
    switch (status) {
      case 'active':
      case 'approved':
        return 'Riscattato';
      case 'pending':
        return 'In attesa';
      case 'rejected':
        return 'Rifiutato';
      case 'expired':
        return 'Scaduto';
      default:
        return status;
    }
  }
}
