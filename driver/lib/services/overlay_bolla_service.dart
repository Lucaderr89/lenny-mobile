import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../config/app_colors.dart';
import '../models/order.dart';

/// Regia della bolla flottante (Android): permesso, apertura,
/// aggiornamento dati e chiusura. Su iOS non fa nulla (il sistema non
/// permette overlay): resta la notifica dell'ordine.
class OverlayBollaService {
  OverlayBollaService._();
  static final OverlayBollaService _instance = OverlayBollaService._();
  factory OverlayBollaService() => _instance;

  bool get supportata => Platform.isAndroid;

  /// Mostra (o aggiorna) la bolla con la tappa ATTIVA di [ordine].
  /// Se manca il permesso overlay, lo chiede UNA volta con spiegazione.
  Future<void> mostraPerOrdine(BuildContext context, Order ordine) async {
    if (!supportata) return;

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
        height: 640, // pixel fisici: bolla compatta, non a tutto schermo
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Lenny Driver',
        overlayContent: 'Prossima tappa in vista',
      );
      await _condividiDati(ordine);
    } catch (_) {/* la bolla e' un aiuto: mai bloccare la navigazione */}
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
      }),
    );
  }
}
