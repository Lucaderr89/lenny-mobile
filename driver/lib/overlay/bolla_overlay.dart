import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../config/app_colors.dart';


/// UI della BOLLA flottante che resta sopra Google Maps durante la
/// navigazione: prossima tappa, note e azioni rapide, senza mai
/// riaprire l'app. Gira in un engine separato (entry point overlayMain).
///
/// ATTENZIONE: questo engine NON ha i plugin dell'app registrati (il
/// plugin overlay lo crea con createAndRunEngine e basta) e nemmeno il
/// canale usato da closeOverlay. Quindi da qui NON si possono aprire
/// url_launcher ne' chiudere la bolla: le azioni si mandano all'app
/// principale con shareData e le esegue lei.
///
/// Riceve i dati come JSON:
/// { verbo, soggetto, indirizzo, note, telefono, margineAlto }
class BollaOverlay extends StatefulWidget {
  const BollaOverlay({super.key});

  @override
  State<BollaOverlay> createState() => _BollaOverlayState();
}

class _BollaOverlayState extends State<BollaOverlay> {
  String _verbo = 'PROSSIMA TAPPA';
  String _soggetto = '';
  String _indirizzo = '';
  String _note = '';
  String _telefono = '';

  /// Quanto scendere dal bordo alto dello schermo. Lo misura l'app
  /// principale sul dispositivo reale (barra di stato / notch) e lo manda
  /// qui: dentro l'overlay il valore non e' affidabile.
  double? _margineAlto;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((dati) {
      try {
        final mappa = dati is String
            ? jsonDecode(dati) as Map<String, dynamic>
            : Map<String, dynamic>.from(dati as Map);
        setState(() {
          _verbo = mappa['verbo']?.toString() ?? 'PROSSIMA TAPPA';
          _soggetto = mappa['soggetto']?.toString() ?? '';
          _indirizzo = mappa['indirizzo']?.toString() ?? '';
          _note = mappa['note']?.toString() ?? '';
          _telefono = mappa['telefono']?.toString() ?? '';
          final m = mappa['margineAlto'];
          if (m is num) _margineAlto = m.toDouble();
        });
      } catch (_) {/* payload inatteso: la bolla resta com'e' */}
    });
  }

  /// Le azioni le esegue l'app principale: qui i plugin non ci sono.
  void _chiediAllApp(Map<String, dynamic> azione) {
    try {
      FlutterOverlayWindow.shareData(jsonEncode(azione));
    } catch (_) {}
  }

  void _chiama() {
    // Stessa ripulitura dell'app: i numeri in anagrafica hanno spazi e punti
    // che rompono l'URI tel:.
    final numero = _telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    if (numero.isEmpty) return;
    _chiediAllApp({'azione': 'chiama', 'telefono': numero});
  }

  @override
  Widget build(BuildContext context) {
    final bool consegna = _verbo.toUpperCase().contains('CONSEGNA');
    final Color colore = consegna ? AppColors.success : AppColors.primary;

    // La finestra parte dal bordo REALE dello schermo (startPosition 0,0):
    // qui si scende dell'inset misurato dal dispositivo, con un minimo di
    // sicurezza per i telefoni che non lo dichiarano.
    final double insetLocale = MediaQuery.of(context).viewPadding.top;
    final double alto = (_margineAlto ?? insetLocale).clamp(24.0, 96.0) + 8;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.fromLTRB(8, alto, 8, 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.nightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colore, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intestazione e CHIAMA restano SEMPRE visibili; a stringersi e'
              // solo il blocco di testo in mezzo. Cosi' la bolla si adatta a
              // qualunque densita' schermo o dimensione carattere di sistema
              // senza mai sforare (e senza mangiare mezzo schermo a Maps).
              Row(
                children: [
                  Icon(
                    consegna ? Icons.location_on : Icons.storefront,
                    color: colore,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _verbo,
                      style: TextStyle(
                        color: colore,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _chiediAllApp({'azione': 'chiudi'}),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close,
                        color: AppColors.nightTextSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _soggetto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.nightText,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_indirizzo.isNotEmpty)
                        Text(
                          _indirizzo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.nightTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                      if (_note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFD28A),
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Solo CHIAMA: "Apri app" faceva uscire dal navigatore e
              // costringeva a rilanciarlo. La bolla serve a VEDERE i dati
              // restando in navigazione; per tornare all'app c'e' il
              // normale cambio applicazione del telefono.
              if (_telefono.isNotEmpty) ...[
                const SizedBox(height: 10),
                _BottoneBolla(
                  icona: Icons.phone,
                  etichetta: 'CHIAMA',
                  colore: colore,
                  onTap: _chiama,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottoneBolla extends StatelessWidget {
  final IconData icona;
  final String etichetta;
  final Color colore;
  final VoidCallback onTap;

  const _BottoneBolla({
    required this.icona,
    required this.etichetta,
    required this.colore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: colore.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colore, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icona, color: colore, size: 19),
            const SizedBox(width: 6),
            Text(
              etichetta,
              style: TextStyle(
                color: colore,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
