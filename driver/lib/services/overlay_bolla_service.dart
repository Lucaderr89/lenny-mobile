import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_colors.dart';
import '../models/order.dart';

/// Regia della bolla flottante (Android): permesso, apertura,
/// aggiornamento dati e chiusura. Su iOS non fa nulla (il sistema non
/// permette overlay): resta la notifica dell'ordine.
///
/// La bolla gira in un engine Flutter separato SENZA i plugin dell'app:
/// da li' non si puo' comporre un numero ne' chiudere la finestra. Le sue
/// azioni arrivano qui come messaggi e le esegue l'app.
class OverlayBollaService {
  OverlayBollaService._();
  static final OverlayBollaService _instance = OverlayBollaService._();
  factory OverlayBollaService() => _instance;

  bool get supportata => Platform.isAndroid;

  StreamSubscription<dynamic>? _ascoltoAzioni;

  /// Inset reale del dispositivo (barra di stato / notch), misurato
  /// dall'app e passato alla bolla: dentro l'overlay non e' affidabile e
  /// un margine "a occhio" finisce sotto la barra su alcuni telefoni.
  double _insetAlto = 28;

  /// Mostra (o aggiorna) la bolla con la tappa ATTIVA di [ordine].
  /// Se manca il permesso overlay, lo chiede UNA volta con spiegazione.
  Future<void> mostraPerOrdine(BuildContext context, Order ordine) async {
    if (!supportata) return;

    _insetAlto = MediaQuery.of(context).viewPadding.top;
    _ascoltaAzioniBolla();

    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        if (!context.mounted) return;
        final accetta = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Bolla sopra il navigatore'),
            content: const Text(
              'Con questo permesso la prossima tappa resta visibile SOPRA '
              'Google Maps: cliente, indirizzo e note sempre in vista, '
              'senza riaprire l\'app.\n\nNella schermata che si apre, '
              'attiva il permesso per Lenny Driver.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Non ora'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Attiva'),
              ),
            ],
          ),
        );
        if (accetta != true) return;
        final concesso = await FlutterOverlayWindow.requestPermission();
        if (concesso != true) return;
      }

      if (await FlutterOverlayWindow.isActive()) {
        await _condividiDati(ordine);
        return;
      }

      await FlutterOverlayWindow.showOverlay(
        // Pixel FISICI, non logici: a 640 la finestra lasciava ~130px logici
        // di spazio utile e il contenuto (soggetto + indirizzo + note +
        // CHIAMA) ne chiede ~185, da cui l'overflow. 820 basta con margine,
        // restando comunque una bolla e non mezzo schermo su Maps.
        height: 820,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Lenny Driver',
        overlayContent: 'Prossima tappa in vista',
        // Senza posizione esplicita il plugin alza la finestra di una
        // barra di stato "da manuale" (24dp), che sui telefoni con notch o
        // barra piu' alta non corrisponde: la bolla finiva mezza fuori.
        // Ancorandola a 0,0 il bordo e' quello vero e a scendere ci pensa
        // il margine calcolato sull'inset reale.
        startPosition: const OverlayPosition(0, 0),
      );
      await _condividiDati(ordine);
    } catch (_) {/* la bolla e' un aiuto: mai bloccare la navigazione */}
  }

  /// Esegue le azioni che la bolla non puo' fare da sola.
  void _ascoltaAzioniBolla() {
    _ascoltoAzioni ??= FlutterOverlayWindow.overlayListener.listen((
      dati,
    ) async {
      try {
        final mappa = dati is String
            ? jsonDecode(dati) as Map<String, dynamic>
            : Map<String, dynamic>.from(dati as Map);
        switch (mappa['azione']?.toString()) {
          case 'chiama':
            final numero = mappa['telefono']?.toString() ?? '';
            if (numero.isEmpty) return;
            await launchUrl(
              Uri.parse('tel:$numero'),
              mode: LaunchMode.externalApplication,
            );
            break;
          case 'chiudi':
            await chiudi();
            break;
        }
      } catch (_) {}
    });
  }

  /// Aggiorna i dati se la bolla e' aperta (chiamare a ogni refresh ordini).
  Future<void> aggiorna(Order? ordineAttivo) async {
    if (!supportata) return;
    try {
      if (!await FlutterOverlayWindow.isActive()) return;
      if (ordineAttivo == null) {
        await FlutterOverlayWindow.closeOverlay();
        return;
      }
      await _condividiDati(ordineAttivo);
    } catch (_) {}
  }

  /// Chiude la bolla se aperta. Silenziosa se non c'e' nulla da chiudere.
  Future<void> chiudi() async {
    if (!supportata) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (_) {}
  }

  Future<void> _condividiDati(Order o) async {
    final inConsegna = o.isInDelivery;
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'verbo': inConsegna ? 'CONSEGNA A' : 'RITIRA DA',
        'soggetto': inConsegna ? o.customerName : o.restaurantName,
        'indirizzo': inConsegna ? o.deliveryAddress : o.restaurantAddress,
        'note': inConsegna ? (o.deliveryNotes ?? '') : 'Fascia ${o.timeSlot}',
        'telefono': inConsegna ? o.customerPhone : (o.restaurantPhone ?? ''),
        'margineAlto': _insetAlto,
      }),
    );
  }
}
