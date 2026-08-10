import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Esito di una stampa: oltre al successo porta il motivo del fallimento in
/// forma leggibile, perche' il ristorante deve poter capire cosa fare
/// (rimettere la carta, chiudere il coperchio) senza guardare i log.
class EsitoStampa {
  final bool ok;
  final String? motivo;

  const EsitoStampa.riuscita() : ok = true, motivo = null;
  const EsitoStampa.fallita(this.motivo) : ok = false;
}

/// Service per gestire la stampante Sunmi integrata
class PrinterService {
  /// Traduce lo stato grezzo della stampante in un messaggio per l'operatore.
  /// Restituisce null quando la stampante e' pronta.
  static String? _motivoDaStato(String? stato) {
    if (stato == null) return null;
    final s = stato.toUpperCase();
    if (s.contains('READY')) return null;
    if (s.contains('PAPER_OUT') || s.contains('PICK_PAPER')) {
      return 'Carta finita: inserisci un nuovo rotolo';
    }
    if (s.contains('PAPER_JAM')) return 'Carta inceppata';
    if (s.contains('PAPER')) return 'Problema con la carta';
    if (s.contains('COVER')) return 'Coperchio della stampante aperto';
    if (s.contains('HOT')) return 'Stampante surriscaldata: attendi un minuto';
    if (s.contains('CUTTER')) return 'Taglierina bloccata';
    if (s.contains('CARTRIDGE')) return 'Problema con la cartuccia';
    if (s.contains('OFFLINE') || s.contains('COMM')) {
      return 'Stampante non raggiungibile';
    }
    return null;
  }

  /// Stato corrente della stampante, null se tutto a posto.
  Future<String?> problemaCorrente() async {
    try {
      return _motivoDaStato(await SunmiConfig.getStatus());
    } catch (_) {
      return null;
    }
  }

  /// Ridimensiona un'immagine per la stampante termica 55mm
  Future<Uint8List?> _resizeImageForPrinter(
    Uint8List imageBytes,
    int targetWidth,
  ) async {
    try {
      // Decodifica l'immagine
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      // Calcola altezza proporzionale
      final double aspectRatio = originalImage.height / originalImage.width;
      final int targetHeight = (targetWidth * aspectRatio).round();

      // Crea un recorder per ridisegnare l'immagine
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // Ridimensiona e disegna
      final Paint paint = Paint()..filterQuality = FilterQuality.high;

      canvas.drawImageRect(
        originalImage,
        Rect.fromLTWH(
          0,
          0,
          originalImage.width.toDouble(),
          originalImage.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        paint,
      );

      // Converti in immagine
      final ui.Image resizedImage = await recorder.endRecording().toImage(
        targetWidth,
        targetHeight,
      );

      // Converti in bytes PNG
      final ByteData? byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Errore ridimensionamento immagine: $e');
      return null;
    }
  }

  /// Riga del riepilogo importi: etichetta a sinistra, cifra a destra.
  Future<void> _riga(String etichetta, double importo) async {
    await SunmiPrinter.printText(etichetta, style: SunmiTextStyle(fontSize: 20));
    await SunmiPrinter.printText(
      'EUR ${importo.toStringAsFixed(2)}',
      style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.RIGHT),
    );
  }

  /// Verifica se la stampante è disponibile
  Future<bool> isPrinterAvailable() async {
    try {
      // Prima inizializza la stampante
      await SunmiPrinter.initPrinter();

      // Poi verifica il binding
      final result = await SunmiPrinter.bindingPrinter();


      // Su alcuni modelli Sunmi, bindingPrinter restituisce null ma la stampante funziona
      // Accettiamo true o null come validi
      return result != false;
    } catch (e) {
      debugPrint('Errore verifica stampante: $e');
      return false;
    }
  }

  /// Stampa un ordine completo
  Future<EsitoStampa> printOrder(Order order, String restaurantName) async {
    try {
      // Verifica disponibilità stampante
      final available = await isPrinterAvailable();
      if (!available) {
        return const EsitoStampa.fallita(
          'Stampante non disponibile: controlla che sia accesa e collegata',
        );
      }

      // Stato carta/coperchio: se c'e' un problema si esce subito con il
      // motivo, cosi' l'ordine puo' essere ristampato dopo averlo risolto.
      final problema = await problemaCorrente();
      if (problema != null) {
        return EsitoStampa.fallita(problema);
      }

      // --- LOGO ---
      try {
        // Carica il logo dagli assets
        final ByteData data = await rootBundle.load(
          'assets/images/logo_lenny.png',
        );
        final Uint8List originalBytes = data.buffer.asUint8List();

        // Ridimensiona per stampante 55mm (200px larghezza)
        final Uint8List? resizedBytes = await _resizeImageForPrinter(
          originalBytes,
          200,
        );

        if (resizedBytes != null) {
          await SunmiPrinter.printImage(resizedBytes);
          await SunmiPrinter.lineWrap(1);
        }
      } catch (e) {
        debugPrint('Impossibile stampare logo: $e');
      }

      // --- HEADER ---
      await SunmiPrinter.printText(
        restaurantName,
        style: SunmiTextStyle(
          fontSize: 32,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      // Data e ora
      final dateFormatter = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();
      await SunmiPrinter.printText(
        '${dateFormatter.format(now)} - ${DateFormat('HH:mm').format(now)}',
        style: SunmiTextStyle(fontSize: 20, align: SunmiPrintAlign.CENTER),
      );

      await SunmiPrinter.printText(
        '================================',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(1);

      // --- INFO ORDINE ---
      await SunmiPrinter.printText(
        'ORDINE #${order.id}',
        style: SunmiTextStyle(fontSize: 28, bold: true),
      );
      await SunmiPrinter.lineWrap(2);

      // Tipo ordine - BEN IN EVIDENZA (bianco su nero)
      final orderType = order.isDelivery ? '  CONSEGNA  ' : '  ASPORTO  ';

      await SunmiPrinter.printText(
        orderType,
        style: SunmiTextStyle(
          fontSize: 40,
          bold: true,
          align: SunmiPrintAlign.CENTER,
          reverse: true,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      // Data ordine - BEN IN EVIDENZA
      await SunmiPrinter.printText(
        order.formattedDate,
        style: SunmiTextStyle(
          fontSize: 60,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      // Orario consegna/ritiro - BEN IN EVIDENZA
      await SunmiPrinter.printText(
        order.timeSlot,
        style: SunmiTextStyle(
          fontSize: 60,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(2);

      // Pagamento - evidenziato in negativo (sfondo nero)
      final String paymentText = (order.paymentStatus == 'paid')
          ? '  PAGATO  '
          : '  DA PAGARE  ';
      await SunmiPrinter.printText(
        paymentText,
        style: SunmiTextStyle(
          fontSize: 40,
          bold: true,
          align: SunmiPrintAlign.CENTER,
          reverse: true,
        ),
      );
      // Metodo di pagamento: per la cassa "DA PAGARE" da solo non basta,
      // contanti e bancomat si gestiscono in modo diverso.
      final metodoPagamento = (order.paymentMethodName ?? '').trim();
      if (metodoPagamento.isNotEmpty) {
        await SunmiPrinter.printText(
          metodoPagamento,
          style: SunmiTextStyle(
            fontSize: 28,
            bold: true,
            align: SunmiPrintAlign.CENTER,
          ),
        );
      }
      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText('--------------------------------');

      // --- CLIENTE ---
      await SunmiPrinter.printText(
        'CLIENTE',
        style: SunmiTextStyle(bold: true),
      );
      await SunmiPrinter.printText('Nome: ${order.customerName}');
      if (order.customerPhone.isNotEmpty) {
        await SunmiPrinter.printText('Tel: ${order.customerPhone}');
      }
      // Sugli asporti l'indirizzo non c'e': non si stampa un'etichetta vuota.
      if (order.isDelivery && order.deliveryAddress.trim().isNotEmpty) {
        await SunmiPrinter.printText('Indirizzo: ${order.deliveryAddress}');
      }
      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText('--------------------------------');

      // --- ARTICOLI ---
      await SunmiPrinter.printText(
        'ARTICOLI',
        style: SunmiTextStyle(bold: true, fontSize: 24),
      );
      await SunmiPrinter.lineWrap(1);

      for (final item in order.items) {
        // Quantita' e nome, poi l'importo DELLA RIGA allineato a destra.
        // Stampare il prezzo unitario da solo si legge come importo di riga:
        // con 4 pezzi da 3,10 la riga vale 12,40, non 3,10.
        await SunmiPrinter.printText(
          '${item.quantity}x ${item.name}',
          style: SunmiTextStyle(fontSize: 22),
        );
        await SunmiPrinter.printText(
          'EUR ${item.lineTotal.toStringAsFixed(2)}',
          style: SunmiTextStyle(
            fontSize: 22,
            bold: true,
            align: SunmiPrintAlign.RIGHT,
          ),
        );
        // Il prezzo unitario si mostra solo quando puo' servire, cioe' con piu'
        // di un pezzo, e in piccolo per non confonderlo con l'importo di riga.
        if (item.quantity > 1) {
          await SunmiPrinter.printText(
            '(${item.quantity} x EUR ${item.price.toStringAsFixed(2)})',
            style: SunmiTextStyle(fontSize: 18, align: SunmiPrintAlign.RIGHT),
          );
        }

        // Stampa extra se presenti
        if (item.extras.isNotEmpty) {
          // Raggruppa extra per categoria
          final Map<String?, List<OrderExtra>> grouped = {};
          for (var extra in item.extras) {
            final groupName = extra.groupName ?? 'Aggiunte';
            if (!grouped.containsKey(groupName)) {
              grouped[groupName] = [];
            }
            grouped[groupName]!.add(extra);
          }

          // Stampa ogni gruppo. NB: il prezzo degli extra e' GIA' compreso nel
          // prezzo unitario, quindi non va stampato accanto: sembrerebbe da
          // sommare una seconda volta.
          for (var entry in grouped.entries) {
            await SunmiPrinter.printText(
              '  ${entry.key}:',
              style: SunmiTextStyle(fontSize: 20),
            );
            for (var extra in entry.value) {
              await SunmiPrinter.printText(
                '    + ${extra.name}',
                style: SunmiTextStyle(fontSize: 20),
              );
            }
          }
        }

        // Note prodotto
        if (item.notes != null && item.notes!.isNotEmpty) {
          await SunmiPrinter.printText(
            '  Note: ${item.notes}',
            style: SunmiTextStyle(fontSize: 20),
          );
        }

        await SunmiPrinter.lineWrap(1);
      }

      await SunmiPrinter.printText('--------------------------------');

      // --- RIEPILOGO IMPORTI ---
      // Il totale dell'ordine comprende consegna, commissione e sconti: senza
      // il dettaglio non quadrerebbe con la somma delle righe qui sopra.
      await SunmiPrinter.lineWrap(1);
      await _riga('Totale articoli', order.itemsTotal);
      if (order.deliveryFee > 0) {
        await _riga('Consegna', order.deliveryFee);
      }
      if (order.orderFee > 0) {
        await _riga('Servizio', order.orderFee);
      }
      if (order.discountAmount > 0) {
        await _riga('Sconto', -order.discountAmount);
      }
      if (order.appCreditsUsed > 0) {
        await _riga('Crediti usati', -order.appCreditsUsed);
      }
      // Componenti non itemizzate (tipico degli ordini importati): senza
      // questa voce le righe stampate non sommerebbero al totale.
      if (order.altreVoci.abs() >= 0.01) {
        await _riga('Altre voci', order.altreVoci);
      }
      await SunmiPrinter.printText('--------------------------------');
      await SunmiPrinter.printText(
        order.isDelivery ? 'TOTALE CLIENTE' : 'TOTALE DA INCASSARE',
        style: SunmiTextStyle(bold: true, fontSize: 28),
      );
      await SunmiPrinter.printText(
        'EUR ${order.total.toStringAsFixed(2)}',
        style: SunmiTextStyle(
          bold: true,
          fontSize: 32,
          align: SunmiPrintAlign.RIGHT,
        ),
      );

      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('================================');

      // --- NOTE ---
      if (order.note != null && order.note!.isNotEmpty) {
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText(
          'NOTE CLIENTE:',
          style: SunmiTextStyle(bold: true),
        );
        await SunmiPrinter.printText(
          order.note!,
          style: SunmiTextStyle(fontSize: 24),
        );
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText('================================');
      }

      // --- FOOTER ---
      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.printText(
        'Grazie per la tua scelta!',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
      );
      await SunmiPrinter.lineWrap(1);

      // QR Code per tracciamento
      await SunmiPrinter.printQRCode(
        'ORDER-${order.id}',
        style: SunmiQrcodeStyle(
          qrcodeSize: 4,
          errorLevel: SunmiQrcodeLevel.LEVEL_M,
        ),
      );

      await SunmiPrinter.lineWrap(3);

      // Taglia la carta
      await SunmiPrinter.cutPaper();

      return const EsitoStampa.riuscita();
    } catch (e) {
      debugPrint('Errore stampa ordine: $e');
      // Se la stampa si e' interrotta a meta', spesso il motivo e' leggibile
      // dallo stato: meglio quello di un messaggio tecnico.
      final problema = await problemaCorrente();
      return EsitoStampa.fallita(
        problema ?? 'Errore durante la stampa della comanda',
      );
    }
  }

  /// Stampa un test per verificare la stampante
  Future<bool> printTest() async {
    try {
      final available = await isPrinterAvailable();
      if (!available) return false;

      // Stampa logo
      try {
        final ByteData data = await rootBundle.load(
          'assets/images/logo_lenny.png',
        );
        final Uint8List originalBytes = data.buffer.asUint8List();

        // Ridimensiona per stampante 55mm (200px larghezza)
        final Uint8List? resizedBytes = await _resizeImageForPrinter(
          originalBytes,
          200,
        );

        if (resizedBytes != null) {
          await SunmiPrinter.printImage(resizedBytes);
          await SunmiPrinter.lineWrap(1);
        }
      } catch (e) {
        debugPrint('Impossibile stampare logo: $e');
      }

      await SunmiPrinter.printText(
        'TEST STAMPANTE',
        style: SunmiTextStyle(
          fontSize: 32,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText(
        'La stampante funziona correttamente!',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.lineWrap(2);

      final now = DateTime.now();
      await SunmiPrinter.printText(
        DateFormat('dd/MM/yyyy HH:mm:ss').format(now),
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20),
      );

      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.cutPaper();

      return true;
    } catch (e) {
      debugPrint('Errore test stampante: $e');
      return false;
    }
  }
}
