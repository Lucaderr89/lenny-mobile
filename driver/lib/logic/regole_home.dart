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

  // ── Cursore tappa del giro ─────────────────────────────────────────────
  // Stato di ogni tappa DEDOTTO dallo stato (geofencing) del relativo
  // ordine, senza una macchina a stati propria. Stesse regole della card
  // giro e della schermata di navigazione: estratte qui perche' le due
  // viste non divergano mai.
  //
  // [statiOverride] = stati piu' freschi degli oggetti Order (es. letti
  // dalla risposta di track-location): {orderId: status}. Vince sul campo
  // status dell'ordine, cosi' la navigazione avanza la tappa senza
  // aspettare il polling ordini.

  static String _stato(Order o, Map<int, String> statiOverride) =>
      statiOverride[o.id] ?? o.status;

  /// Tappa completata: ritiro fatto o consegna avvenuta.
  static bool tappaChiusa(
    RouteStop st,
    Order? o, {
    Map<int, String> statiOverride = const {},
  }) {
    if (o == null) return true; // ordine non piu' tra gli attivi → consegnato
    final stato = _stato(o, statiOverride);
    if (st.isPickup) {
      return o.pickedUpAt != null ||
          stato == 'in_delivery' ||
          stato == 'delivered';
    }
    return stato == 'delivered';
  }

  /// Tappa in corso adesso (geofencing: al ristorante / verso il cliente).
  static bool tappaInCorso(
    RouteStop st,
    Order? o, {
    Map<int, String> statiOverride = const {},
  }) {
    if (o == null) return false;
    final stato = _stato(o, statiOverride);
    return st.isPickup ? stato == 'picking_up' : stato == 'in_delivery';
  }

  /// PROSSIMA TAPPA = prima non completata. E' il perno della card giro e
  /// il bersaglio della navigazione; si sposta da sola man mano che le
  /// tappe si chiudono.
  static RouteStop? prossimaTappa(
    List<RouteStop> steps,
    Map<int, Order> orderById, {
    Map<int, String> statiOverride = const {},
  }) {
    for (final st in steps) {
      if (!tappaChiusa(st, orderById[st.orderId],
          statiOverride: statiOverride)) {
        return st;
      }
    }
    return null;
  }

  /// Sequenza di tappe per ordini SENZA route_plan dal pannello: ritiro e
  /// consegna di ogni ordine, nell'ordine dato. E' il giro sintetico della
  /// home, riusato dalla navigazione per ordini singoli e gruppi.
  static List<RouteStop> stepsSintetici(List<Order> ordini) {
    final steps = <RouteStop>[];
    for (final o in ordini) {
      steps.add(RouteStop(
        type: 'pickup',
        orderId: o.id,
        lat: o.restaurantLat,
        lng: o.restaurantLng,
        cumTime: 0,
      ));
      steps.add(RouteStop(
        type: 'delivery',
        orderId: o.id,
        lat: o.deliveryLat,
        lng: o.deliveryLng,
        cumTime: 0,
      ));
    }
    return steps;
  }
}
