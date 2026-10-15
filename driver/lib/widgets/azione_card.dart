import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_colors.dart';

/// Banner "PROSSIMA AZIONE" in testa alla card ordine: risponde in mezzo
/// secondo alla domanda "cosa devo fare ADESSO?". Blu per il ritiro,
/// verde per la consegna, ambra per la conferma ricezione.
class AzioneProssima extends StatelessWidget {
  final String verbo; // es. "RITIRA", "CONSEGNA", "CONFERMA"
  final String soggetto; // es. nome ristorante o cliente
  final String? dettaglio; // es. fascia oraria o indirizzo breve
  final String? incasso; // es. "INCASSA €25,40" (solo consegne non pagate)

  /// Numero d'ordine, sempre in vista: al banco del ristorante ci sono
  /// 4-5 sacchetti e il driver deve prendere il suo al primo colpo.
  final String? numero;
  final Color colore;
  final IconData icona;

  const AzioneProssima({
    super.key,
    required this.verbo,
    required this.soggetto,
    this.dettaglio,
    this.incasso,
    this.numero,
    required this.colore,
    required this.icona,
  });

  Widget _pillola(String testo, {double fontSize = 15}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: Text(
      testo,
      style: TextStyle(
        color: colore,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pillole = <Widget>[
      if (numero != null && numero!.isNotEmpty) _pillola('N. $numero'),
      if (incasso != null) _pillola(incasso!),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colore,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.card),
          topRight: Radius.circular(AppRadius.card),
        ),
      ),
      child: Row(
        children: [
          Icon(icona, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verbo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  soggetto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (dettaglio != null && dettaglio!.isNotEmpty)
                  Text(
                    dettaglio!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (pillole.isNotEmpty) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < pillole.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  pillole[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Numero d'ordine in evidenza sulla riga del cliente: il driver lo
/// confronta con lo scontrino sul sacchetto. Grande e contrastato apposta,
/// prima era un "#id" grigio da 11 punti che nessuno vedeva.
class NumeroOrdineChip extends StatelessWidget {
  final String numero;
  final Color colore;

  const NumeroOrdineChip({
    super.key,
    required this.numero,
    this.colore = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colore,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        'N. $numero',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Pulsante NAVIGA agganciato alla RIGA a cui appartiene: sulla riga del
/// ristorante porta al ristorante, su quella del cliente porta dal
/// cliente. Ogni posto ha il suo: il giro lo sceglie il driver, non l'app.
/// Pieno (non tinto) perche' e' l'azione principale della riga.
class NavigaRiga extends StatelessWidget {
  final Color colore;
  final VoidCallback onTap;

  const NavigaRiga({super.key, required this.colore, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Naviga',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colore,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: const Icon(Icons.navigation, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}

/// Pulsante di chiamata agganciato alla RIGA a cui appartiene: sulla riga
/// del ristorante chiama il ristorante, su quella del cliente chiama il
/// cliente. Chi si sta chiamando lo dice la posizione, non l'etichetta.
class ChiamaRiga extends StatelessWidget {
  final String telefono;
  final Color colore;

  const ChiamaRiga({
    super.key,
    required this.telefono,
    required this.colore,
  });

  /// In anagrafica i numeri sono scritti a mano: "339 833 1545",
  /// "+39.33.14.57.52.43", "0549 905280". Spazi e punteggiatura rompono
  /// l'URI tel:, quindi si tiene solo il + iniziale e le cifre.
  static String normalizza(String grezzo) {
    final pulito = grezzo.replaceAll(RegExp(r'[^0-9+]'), '');
    if (pulito.isEmpty) return '';
    final piu = pulito.startsWith('+');
    final cifre = pulito.replaceAll('+', '');
    return piu ? '+$cifre' : cifre;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Chiama $telefono',
      child: InkWell(
        onTap: () async {
          final numero = normalizza(telefono);
          if (numero.isEmpty) return;
          try {
            await launchUrl(Uri.parse('tel:$numero'));
          } catch (_) {/* nessun dialer: niente crash in strada */}
        },
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colore.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: colore.withValues(alpha: 0.55)),
          ),
          child: Icon(Icons.phone, color: colore, size: 21),
        ),
      ),
    );
  }
}

/// Bottone d'azione GRANDE (>=54px): pensato per un pollice col guanto.
class BottoneAzione extends StatelessWidget {
  final IconData icona;
  final String etichetta;
  final Color colore;
  final VoidCallback onTap;
  final bool pieno; // true = riempito, false = solo bordo

  const BottoneAzione({
    super.key,
    required this.icona,
    required this.etichetta,
    required this.colore,
    required this.onTap,
    this.pieno = true,
  });

  @override
  Widget build(BuildContext context) {
    final ButtonStyle stile = pieno
        ? ElevatedButton.styleFrom(
            backgroundColor: colore,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: colore,
            side: BorderSide(color: colore, width: 1.6),
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
          );

    final contenuto = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icona, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            etichetta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );

    return pieno
        ? ElevatedButton(onPressed: onTap, style: stile, child: contenuto)
        : OutlinedButton(onPressed: onTap, style: stile, child: contenuto);
  }
}
