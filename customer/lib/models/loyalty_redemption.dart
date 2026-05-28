class LoyaltyRedemption {
  final int id;
  final int customerId;
  final int rewardId;
  final int pointsSpent;
  final String status;
  final DateTime redeemedAt;
  final DateTime? usedAt;
  final DateTime? expiresAt;
  final int? orderId;
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
    this.expiresAt,
    this.orderId,
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
      status: json['status'] ?? 'active',
      redeemedAt: DateTime.parse(json['redeemed_at']),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at']) : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      orderId: json['order_id'] != null
          ? int.parse(json['order_id'].toString())
          : null,
      notes: json['notes'],
      rewardName: json['reward_name'],
      rewardDescription: json['reward_description'],
      rewardImage: json['reward_image'],
    );
  }

  bool get isActive => status == 'active';
  bool get isUsed => status == 'used';
  bool get isExpired => status == 'expired';

  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    final daysUntilExpiry = expiresAt!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry > 0;
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Attivo';
      case 'used':
        return 'Utilizzato';
      case 'expired':
        return 'Scaduto';
      default:
        return status;
    }
  }
}
