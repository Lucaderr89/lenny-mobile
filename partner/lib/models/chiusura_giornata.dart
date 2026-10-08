/// Totali di un giorno di servizio, calcolati dal server
/// (GET /api/partner/chiusura, e chiave chiusura_da_stampare della lista
/// ordini per quella automatica). Le stesse colonne che il ristorante vede
/// sul pannello Lenny Platform: Subtotale, Rincaro, Consegna, Tassa, Totale.
class ChiusuraGiornata {
  /// Giorno di servizio chiuso, AAAA-MM-GG. Lo decide il server: l'orologio
  /// del Sunmi non e' affidabile.
  final String data;
  final String ristorante;
  final int ordini;
  final int domicilio;
  final int asporto;
  final int consegnati;

  /// Non ancora consegnati al momento del calcolo (chiusura manuale a fine
  /// servizio): contano lo stesso, il ristorante li ha preparati.
  final int inCorso;

  /// Annullati del giorno, esclusi da conteggi e importi.
  final int annullati;

  /// Righe d'ordine ("Voci" sul pannello) e pezzi.
  final int voci;
  final int pezzi;
  final double subtotale;
  final double rincaro;
  final double consegna;
  final double tassa;
  final double sconto;
  final double totale;

  /// Ora del server in cui i totali sono stati calcolati (AAAA-MM-GG HH:MM:SS).
  final String generatoAlle;

  /// Firma dei numeri: il server non ripropone in automatico una chiusura
  /// gia' stampata a mano con la stessa impronta.
  final String impronta;

  const ChiusuraGiornata({
    required this.data,
    required this.ristorante,
    required this.ordini,
    required this.domicilio,
    required this.asporto,
    required this.consegnati,
    required this.inCorso,
    required this.annullati,
    required this.voci,
    required this.pezzi,
    required this.subtotale,
    required this.rincaro,
    required this.consegna,
    required this.tassa,
    required this.sconto,
    required this.totale,
    required this.generatoAlle,
    required this.impronta,
  });

  static double _num(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0.0;
  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

  factory ChiusuraGiornata.fromJson(Map<String, dynamic> json) {
    return ChiusuraGiornata(
      data: json['data']?.toString() ?? '',
      ristorante: json['ristorante']?.toString() ?? '',
      ordini: _int(json['ordini']),
      domicilio: _int(json['domicilio']),
      asporto: _int(json['asporto']),
      consegnati: _int(json['consegnati']),
      inCorso: _int(json['in_corso']),
      annullati: _int(json['annullati']),
      voci: _int(json['voci']),
      pezzi: _int(json['pezzi']),
      subtotale: _num(json['subtotale']),
      rincaro: _num(json['rincaro']),
      consegna: _num(json['consegna']),
      tassa: _num(json['tassa']),
      sconto: _num(json['sconto']),
      totale: _num(json['totale']),
      generatoAlle: json['generato_alle']?.toString() ?? '',
      impronta: json['impronta']?.toString() ?? '',
    );
  }

  /// Giorno in formato gg/mm/aaaa.
  String get dataFormattata {
    final p = data.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : data;
  }

  /// Ora del calcolo in formato gg/mm/aaaa HH:MM.
  String get generatoFormattato {
    final parti = generatoAlle.split(' ');
    if (parti.length != 2) return generatoAlle;
    final g = parti[0].split('-');
    final giorno = g.length == 3 ? '${g[2]}/${g[1]}/${g[0]}' : parti[0];
    final ora = parti[1].length >= 5 ? parti[1].substring(0, 5) : parti[1];
    return '$giorno $ora';
  }
}
