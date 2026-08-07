import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Banner "PROSSIMA AZIONE" in testa alla card ordine: risponde in mezzo
/// secondo alla domanda "cosa devo fare ADESSO?". Blu per il ritiro,
/// verde per la consegna, ambra per la conferma ricezione.
class AzioneProssima extends StatelessWidget {
  final String verbo; // es. "RITIRA", "CONSEGNA", "CONFERMA"
  final String soggetto; // es. nome ristorante o cliente
  final String? dettaglio; // es. fascia oraria o indirizzo breve
  final String? incasso; // es. "INCASSA €25,40" (solo consegne non pagate)
  final Color colore;
  final IconData icona;

  const AzioneProssima({
    super.key,
    required this.verbo,
    required this.soggetto,
    this.dettaglio,
    this.incasso,
    required this.colore,
    required this.icona,
  });

  @override
  Widget build(BuildContext context) {
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
          if (incasso != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                incasso!,
                style: TextStyle(
                  color: colore,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
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
