import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/order.dart';
import '../services/tap_to_pay_service.dart';

/// Il foglio del POS: il telefono del driver fa da lettore di carte.
///
/// Tre momenti che il driver vede: "preparo il POS", "avvicina la carta" e
/// l'esito. Quando riesce il foglio si chiude da solo e restituisce true: chi
/// lo ha aperto conferma la consegna, e l'ordine e' gia' segnato pagato dal
/// server.
class FoglioTapToPay extends StatefulWidget {
  final Order order;

  const FoglioTapToPay({super.key, required this.order});

  /// Apre il foglio e parte subito: il driver ha appena toccato il pulsante,
  /// non deve premere altro. Ritorna true se l'incasso e' riuscito.
  static Future<bool?> apri(BuildContext context, {required Order order}) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => FoglioTapToPay(order: order),
    );
  }

  @override
  State<FoglioTapToPay> createState() => _FoglioTapToPayState();
}

class _FoglioTapToPayState extends State<FoglioTapToPay> {
  final TapToPayService _servizio = TapToPayService();

  @override
  void initState() {
    super.initState();
    _servizio.stato.addListener(_suCambioStato);
    _servizio.incassa(widget.order.id);
  }

  @override
  void dispose() {
    _servizio.stato.removeListener(_suCambioStato);
    _servizio.interrompi();
    super.dispose();
  }

  void _suCambioStato() {
    if (!mounted) return;
    setState(() {});
    if (_servizio.stato.value.stato == TapToPayStato.riuscito) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
    }
  }

  void _chiudi([bool? esito]) {
    _servizio.interrompi();
    if (mounted) Navigator.of(context).pop(esito);
  }

  void _riprova() {
    _servizio.azzera();
    _servizio.incassa(widget.order.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = _servizio.stato.value;
    final tema = Theme.of(context);
    final sfondo = tema.cardColor;
    final testo = tema.textTheme.bodyLarge?.color ?? AppColors.dark;
    final secondario = tema.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
        AppColors.grayDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: BoxDecoration(
        color: sfondo,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: secondario.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.order.customerName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondario,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '€${widget.order.total.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: testo,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 26),
            ..._corpo(context, s, testo, secondario),
          ],
        ),
      ),
    );
  }

  List<Widget> _corpo(
      BuildContext context, TapToPayState s, Color testo, Color secondario) {
    switch (s.stato) {
      case TapToPayStato.inattivo:
      case TapToPayStato.verifica:
        return [
          const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          _testo('Preparo il POS', testo, grande: true),
          const SizedBox(height: 6),
          _testo('Un momento, senza toccare niente.', secondario),
          const SizedBox(height: 22),
          _secondario('Annulla', secondario, () => _chiudi()),
        ];
      case TapToPayStato.avvicinaCarta:
        return [
          const Center(
            child: Icon(Icons.contactless_outlined,
                color: AppColors.primary, size: 64),
          ),
          const SizedBox(height: 16),
          _testo('Avvicina la carta al retro del telefono', testo,
              grande: true),
          const SizedBox(height: 6),
          _testo(
              'Vale anche il telefono o l\'orologio del cliente. Tienila ferma finche\' non vibra. Sopra i 50 euro il cliente digita il PIN qui.',
              secondario),
          const SizedBox(height: 22),
          _secondario('Annulla', secondario, () => _chiudi()),
        ];
      case TapToPayStato.conferma:
        return [
          const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          _testo('Carta letta, registro l\'incasso', testo, grande: true),
          const SizedBox(height: 6),
          _testo('Ancora un attimo.', secondario),
        ];
      case TapToPayStato.riuscito:
        return [
          const Center(
            child: Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 64),
          ),
          const SizedBox(height: 16),
          _testo('Pagato', AppColors.success, grande: true),
          const SizedBox(height: 6),
          _testo('L\'ordine e\' segnato pagato con carta.', secondario),
        ];
      case TapToPayStato.nonDisponibile:
      case TapToPayStato.fallito:
        final bool riprovabile = s.stato == TapToPayStato.fallito;
        return [
          Center(
            child: Icon(Icons.error_outline_rounded, color: secondario, size: 52),
          ),
          const SizedBox(height: 16),
          _testo(riprovabile ? 'Non e\' andata' : 'POS non disponibile', testo,
              grande: true),
          const SizedBox(height: 8),
          _testo(s.motivo ?? '', secondario),
          const SizedBox(height: 22),
          if (riprovabile) ...[
            _primario('Riprova', _riprova),
            const SizedBox(height: 10),
          ],
          _secondario('Riscuoto in contanti', secondario, () => _chiudi(false)),
        ];
    }
  }

  Widget _testo(String t, Color colore, {bool grande = false}) => Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colore,
          fontSize: grande ? 18 : 13.5,
          fontWeight: grande ? FontWeight.w700 : FontWeight.w400,
          height: 1.4,
        ),
      );

  Widget _primario(String t, VoidCallback onTap) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(t,
            style:
                const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
      );

  Widget _secondario(String t, Color colore, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: colore,
          minimumSize: const Size(0, 48),
        ),
        child: Text(t,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      );
}
