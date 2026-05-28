import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Service per gestire la stampante Sunmi integrata
class PrinterService {
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
      print('❌ Errore ridimensionamento immagine: $e');
      return null;
    }
  }

  /// Verifica se la stampante è disponibile
  Future<bool> isPrinterAvailable() async {
    try {
      // Prima inizializza la stampante
      await SunmiPrinter.initPrinter();

      // Poi verifica il binding
      final result = await SunmiPrinter.bindingPrinter();
      print('🖨️ Binding stampante: $result');

      // Su alcuni modelli Sunmi, bindingPrinter restituisce null ma la stampante funziona
      // Accettiamo true o null come validi
      return result != false;
    } catch (e) {
      print('❌ Errore verifica stampante: $e');
      return false;
    }
  }

  /// Stampa un ordine completo
  Future<bool> printOrder(Order order, String restaurantName) async {
    try {
      // Verifica disponibilità stampante
      final available = await isPrinterAvailable();
      if (!available) {
        print('❌ Stampante non disponibile');
        return false;
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
        print('⚠️ Impossibile stampare logo: $e');
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
      await SunmiPrinter.printText('Indirizzo: ${order.deliveryAddress}');
      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText('--------------------------------');

      // --- ARTICOLI ---
      await SunmiPrinter.printText(
        'ARTICOLI',
        style: SunmiTextStyle(bold: true, fontSize: 24),
      );
      await SunmiPrinter.lineWrap(1);

      for (final item in order.items) {
        // Nome prodotto
        await SunmiPrinter.printText(
          '${item.quantity}x ${item.name}',
          style: SunmiTextStyle(fontSize: 22),
        );
        // Prezzo su riga separata
        await SunmiPrinter.printText(
          'EUR ${item.price.toStringAsFixed(2)}',
          style: SunmiTextStyle(
            fontSize: 22,
            bold: true,
            align: SunmiPrintAlign.RIGHT,
          ),
        );

        // Stampa extra se presenti
        if (item.extras.isNotEmpty) {
          // Raggruppa extra per categoria
          final Map<String?, List<OrderExtra>> grouped = {};
          for (var extra in item.extras) {
            final groupName = extra.groupName ?? 'Extra';
            if (!grouped.containsKey(groupName)) {
              grouped[groupName] = [];
            }
            grouped[groupName]!.add(extra);
          }

          // Stampa ogni gruppo
          for (var entry in grouped.entries) {
            await SunmiPrinter.printText(
              '  ${entry.key}:',
              style: SunmiTextStyle(fontSize: 20),
            );
            for (var extra in entry.value) {
              final priceText = extra.price > 0
                  ? ' +EUR${extra.price.toStringAsFixed(2)}'
                  : '';
              await SunmiPrinter.printText(
                '    + ${extra.name}$priceText',
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

      // --- TOTALE ---
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText(
        'TOTALE',
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

      print('✅ Ordine #${order.id} stampato con successo');
      return true;
    } catch (e) {
      print('❌ Errore stampa ordine: $e');
      return false;
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
        print('⚠️ Impossibile stampare logo: $e');
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
      print('❌ Errore test stampante: $e');
      return false;
    }
  }
}
