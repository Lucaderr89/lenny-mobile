class SavedCard {
  final String cardAlias; // numeroContratto Nexi
  final String brand; // VISA, MasterCard
  final String last4; // Ultime 4 cifre
  final String? expiry; // MM/YY
  final bool isDefault;

  SavedCard({
    required this.cardAlias,
    required this.brand,
    required this.last4,
    this.expiry,
    required this.isDefault,
  });

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      cardAlias: json['numeroContratto'] as String,
      brand: json['brand'] as String,
      last4: json['last4'] as String,
      expiry: json['expiry'] as String?,
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }

  /// Ottiene icona del circuito carta
  String get brandIcon {
    switch (brand.toUpperCase()) {
      case 'VISA':
        return '💳'; // Puoi sostituire con asset immagine
      case 'MASTERCARD':
        return '💳';
      case 'MAESTRO':
        return '💳';
      case 'AMEX':
      case 'AMERICAN EXPRESS':
        return '💳';
      default:
        return '💳';
    }
  }

  /// Formatta numero carta con asterischi
  String get maskedNumber {
    return '**** **** **** $last4';
  }
}

class WalletCredit {
  final int id;
  final double amount; // Credito disponibile (dopo utilizzi parziali)
  final double originalAmount; // Credito originale
  final double used; // Quanto già utilizzato
  final String sourceType; // 'refund', 'loyalty_reward', 'birthday_gift', ecc
  final int? sourceId; // ID della fonte
  final String description; // Descrizione del credito
  final DateTime createdAt;
  final DateTime? expiresAt;

  WalletCredit({
    required this.id,
    required this.amount,
    required this.originalAmount,
    required this.used,
    required this.sourceType,
    this.sourceId,
    required this.description,
    required this.createdAt,
    this.expiresAt,
  });

  factory WalletCredit.fromJson(Map<String, dynamic> json) {
    return WalletCredit(
      id: int.parse(json['id'].toString()),
      amount: double.parse(json['amount'].toString()),
      originalAmount: double.parse(json['original_amount'].toString()),
      used: double.parse(json['used'].toString()),
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] != null
          ? int.parse(json['source_id'].toString())
          : null,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }

  /// Icona basata sul tipo di credito
  String get sourceIcon {
    switch (sourceType) {
      case 'refund':
        return 'assets/icons/icons8-ricevere-denaro-32.png';
      case 'loyalty_reward':
        return 'assets/icons/icons8-premi-32.png';
      case 'birthday_gift':
        return 'assets/icons/icons8-regalo-32.png';
      case 'promotion':
        return 'assets/icons/icons8-regalo-32.png';
      case 'manual':
        return 'assets/icons/icons8-debito-32.png';
      default:
        return 'assets/icons/icons8-debito-32.png';
    }
  }

  /// Label leggibile del tipo di credito
  String get sourceLabel {
    switch (sourceType) {
      case 'refund':
        return 'Rimborso';
      case 'loyalty_reward':
        return 'Premio Fedeltà';
      case 'birthday_gift':
        return 'Regalo Compleanno';
      case 'promotion':
        return 'Promozione';
      case 'manual':
        return 'Credito';
      default:
        return 'Credito';
    }
  }

  /// Verifica se il credito è in scadenza (< 7 giorni)
  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    final daysUntilExpiry = expiresAt!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 7;
  }

  /// Verifica se il credito è stato usato parzialmente
  bool get isPartiallyUsed => used > 0 && used < originalAmount;
}
