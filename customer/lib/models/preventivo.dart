/// Preventivo del server per un carrello (POST /api/customer/order/quote):
/// gli importi ESATTI che verranno scritti sull'ordine e addebitati. Il
/// checkout mostra questi numeri, non un calcolo fatto sul telefono.
class Preventivo {
  final double subtotale;
  final double costoConsegna;
  final double costoServizio;
  final double sconto;
  final double creditiUsati;
  final double totale;
  final bool couponValido;
  final String? erroreCoupon;

  /// Righe prezzate dal server, nell'ordine in cui sono state mandate.
  /// Una riga rifiutata (piatto tolto dal menu, opzione non valida) manca:
  /// in quel caso le posizioni non corrispondono piu' al carrello.
  final List<RigaPreventivo> righe;

  /// False se il server ha rifiutato qualche riga o qualche sua opzione (i
  /// suoi errori iniziano con "items[N]:"). Allora prezzi e subtotale non
  /// descrivono il carrello, e l'ordine verrebbe comunque rifiutato.
  final bool righeValide;

  const Preventivo({
    required this.subtotale,
    required this.costoConsegna,
    required this.costoServizio,
    required this.sconto,
    required this.creditiUsati,
    required this.totale,
    required this.couponValido,
    required this.erroreCoupon,
    required this.righe,
    required this.righeValide,
  });

  factory Preventivo.fromJson(Map<String, dynamic> json) {
    double importo(String chiave) => (json[chiave] as num?)?.toDouble() ?? 0.0;

    return Preventivo(
      subtotale: importo('subtotal'),
      costoConsegna: importo('delivery_fee'),
      costoServizio: importo('service_fee'),
      sconto: importo('discount_amount'),
      creditiUsati: importo('app_credits_used'),
      totale: importo('total'),
      couponValido: json['coupon_valid'] == true,
      erroreCoupon: json['coupon_error'] as String?,
      righe: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((r) => RigaPreventivo.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      righeValide: !(json['errors'] as List<dynamic>? ?? const []).any(
        (errore) => errore.toString().startsWith('items['),
      ),
    );
  }
}

class RigaPreventivo {
  final int foodId;

  /// Prezzo unitario del piatto senza le scelte a pagamento (scontato, se
  /// il piatto e' in sconto): nel preventivo si chiama `base_price`.
  final double prezzoPiatto;

  /// Somma unitaria delle scelte a pagamento (extra e opzioni).
  final double prezzoScelte;

  const RigaPreventivo({
    required this.foodId,
    required this.prezzoPiatto,
    required this.prezzoScelte,
  });

  factory RigaPreventivo.fromJson(Map<String, dynamic> json) {
    return RigaPreventivo(
      foodId: (json['food_id'] as num?)?.toInt() ?? 0,
      prezzoPiatto: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      prezzoScelte: (json['extras_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
