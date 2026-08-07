import '../models/order.dart';

/// Regole di scelta della home, estratte dalla schermata per poterle
/// verificare con test veri invece che a occhio sul telefono.
class RegoleHome {
  RegoleHome._();

  /// Ordine che la BOLLA deve seguire.
  ///
  /// Comanda la SCELTA DEL DRIVER: se ha premuto NAVIGA su un ordine, la
  /// bolla resta su quello finche' quell'ordine e' ancora in carico, anche
  /// se un altro nel frattempo passa in consegna. Prima vinceva sempre
  /// "il piu' avanti nel flusso" e la bolla saltava da sola su un ordine
  /// diverso da quello verso cui il driver stava guidando.
  ///
  /// Senza una scelta esplicita (o se quell'ordine non c'e' piu': consegnato,
  /// riassegnato) si ripiega sul piu' avanti nel flusso:
  /// in consegna > in ritiro > primo confermato.
  static Order? ordinePerBolla(List<Order> ordini, int? sceltoId) {
    if (sceltoId != null) {
      for (final o in ordini) {
        if (o.id == sceltoId) return o;
      }
    }

    Order? attivo;
    for (final o in ordini) {
      if (o.confirmedAt == null) continue;
      if (o.isInDelivery) return o;
      if (attivo == null || (o.isPickingUp && !attivo.isPickingUp)) {
        attivo = o;
      }
    }
    return attivo;
  }

  /// Ordini confermati raggruppati per fascia, fasce in ordine crescente.
  ///
  /// UN GIRO STA DENTRO UNA FASCIA: ordini di fasce diverse si fanno in
  /// momenti diversi della giornata e non vanno mai interlacciati.
  static Map<String, List<Order>> giriPerFascia(List<Order> candidati) {
    final perFascia = <String, List<Order>>{};
    for (final o in candidati) {
      if (o.confirmedAt == null) continue;
      perFascia.putIfAbsent(o.formattedTimeSlot, () => []).add(o);
    }
    final ordinate = perFascia.keys.toList()..sort();
    return {for (final f in ordinate) f: perFascia[f]!};
  }
}
