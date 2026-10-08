import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../models/chiusura_giornata.dart';
import '../models/order.dart';
import 'traccia_stampe_service.dart';
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

  /// Verifica se la stampante e' disponibile.
  /// Su sunmi_printer_plus 4.x initPrinter/bindingPrinter sono no-op
  /// deprecati (restituivano sempre null e il vecchio check era sempre
  /// vero anche su dispositivi non Sunmi): l'unico segnale reale e' che
  /// il servizio di stampa risponda a una richiesta di stato.
  Future<bool> isPrinterAvailable() async {
    try {
      final stato = await SunmiConfig.getStatus();
      return stato != null;
    } catch (e) {
      debugPrint('Stampante Sunmi non disponibile: $e');
      return false;
    }
  }

  /// Stampa un ordine completo
  /// Logo gia' ridimensionato per la comanda, preparato una volta sola.
  static Uint8List? _logoComanda;

  /// Prepara il logo mentre lo schermo e' acceso. Va chiamato all'avvio:
  /// `_resizeImageForPrinter` usa `Picture.toImage()`, che a schermo spento
  /// non viene mai completato perche' il rasterizzatore e' in pausa.
  Future<void> precaricaLogo() async {
    if (_logoComanda != null) return;
    try {
      final ByteData data = await rootBundle.load(
        'assets/images/logo_lenny.png',
      );
      _logoComanda = await _resizeImageForPrinter(
        data.buffer.asUint8List(),
        200,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Logo comanda non precaricato: $e');
    }
  }

  /// Stampa la comanda di un ordine e ne manda l'esito alla traccia sul
  /// server. [origine] e' obbligatoria apposta: ogni nuovo punto da cui si
  /// stampa deve dichiarare da dove parte, cosi' nessuna stampa sfugge.
  Future<EsitoStampa> printOrder(
    Order order,
    String restaurantName, {
    required OrigineStampa origine,
  }) async {
    final esito = await _stampaComanda(order, restaurantName);
    await TracciaStampe.instance.registra(
      orderId: order.id,
      ok: esito.ok,
      motivo: esito.motivo,
      origine: origine,
    );
    return esito;
  }

  /// Quanto si osserva la stampante dopo il taglio, e ogni quanto.
  static const Duration _osservazioneDopoStampa = Duration(seconds: 3);
  static const Duration _passoOsservazione = Duration(milliseconds: 500);

  /// Controlli prima di mandare qualcosa alla stampante: null = via libera,
  /// altrimenti l'esito fallito con il motivo per l'operatore. Con un
  /// problema di carta o coperchio si esce subito, cosi' la stampa puo'
  /// essere rifatta dopo averlo risolto.
  Future<EsitoStampa?> _problemaPrimaDiStampare() async {
    final available = await isPrinterAvailable();
    if (!available) {
      return const EsitoStampa.fallita(
        'Stampante non disponibile: controlla che sia accesa e collegata',
      );
    }
    final problema = await problemaCorrente();
    if (problema != null) {
      return EsitoStampa.fallita(problema);
    }
    return null;
  }

  /// Il servizio di stampa Sunmi accoda i comandi e risponde subito "ok":
  /// la carta che finisce a meta' stampa non produce errori. Si osserva la
  /// stampante mentre il foglio esce: se in quel tempo finisce la carta o si
  /// apre il coperchio, la stampa non si da' per riuscita e resta da rifare.
  /// Meglio una stampa doppia che una mezza stampa segnata come uscita.
  Future<EsitoStampa> _osservaDopoIlTaglio(String interrotta) async {
    final fine = DateTime.now().add(_osservazioneDopoStampa);
    while (DateTime.now().isBefore(fine)) {
      await Future.delayed(_passoOsservazione);
      final problemaDopo = await problemaCorrente();
      if (problemaDopo != null) {
        return EsitoStampa.fallita('$interrotta $problemaDopo');
      }
    }
    return const EsitoStampa.riuscita();
  }

  Future<EsitoStampa> _stampaComanda(Order order, String restaurantName) async {
    try {
      final bloccata = await _problemaPrimaDiStampare();
      if (bloccata != null) return bloccata;

      // --- LOGO ---
      // Si stampa SOLO dalla cache preparata da precaricaLogo(): il
      // ridimensionamento passa dal rasterizzatore di Flutter, fermo a schermo
      // spento, e calcolarlo qui terrebbe la comanda appesa fino alla
      // riaccensione. Senza cache si stampa comunque, solo senza logo.
      final Uint8List? logo = _logoComanda;
      if (logo != null) {
        try {
          await SunmiPrinter.printImage(logo);
          await SunmiPrinter.lineWrap(1);
        } catch (e) {
          debugPrint('Impossibile stampare logo: $e');
        }
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

      return await _osservaDopoIlTaglio('Comanda interrotta.');
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

  /// Stampa la chiusura di giornata (i totali del giorno) e ne manda l'esito
  /// alla traccia sul server. Solo totali, niente elenco ordini: la carta e'
  /// a 32 colonne e l'elenco il ristorante ce l'ha sul pannello.
  Future<EsitoStampa> printChiusura(
    ChiusuraGiornata chiusura, {
    required OrigineStampa origine,
  }) async {
    final esito = await _stampaChiusura(chiusura);
    await TracciaStampe.instance.registraChiusura(
      data: chiusura.data,
      impronta: chiusura.impronta,
      ok: esito.ok,
      motivo: esito.motivo,
      origine: origine,
    );
    return esito;
  }

  Future<EsitoStampa> _stampaChiusura(ChiusuraGiornata c) async {
    try {
      final bloccata = await _problemaPrimaDiStampare();
      if (bloccata != null) return bloccata;

      final Uint8List? logo = _logoComanda;
      if (logo != null) {
        try {
          await SunmiPrinter.printImage(logo);
          await SunmiPrinter.lineWrap(1);
        } catch (e) {
          debugPrint('Impossibile stampare logo: $e');
        }
      }

      await SunmiPrinter.printText(
        'CHIUSURA GIORNATA',
        style: SunmiTextStyle(
          bold: true,
          fontSize: 28,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.printText(
        c.ristorante,
        style: SunmiTextStyle(fontSize: 24, align: SunmiPrintAlign.CENTER),
      );
      await SunmiPrinter.printText(
        c.dataFormattata,
        style: SunmiTextStyle(
          bold: true,
          fontSize: 28,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('================================');

      // --- CONTEGGI ---
      await SunmiPrinter.printText(
        'ORDINI: ${c.ordini}',
        style: SunmiTextStyle(bold: true, fontSize: 26),
      );
      await SunmiPrinter.printText(
        'A domicilio: ${c.domicilio}   Asporto: ${c.asporto}',
        style: SunmiTextStyle(fontSize: 22),
      );
      if (c.inCorso > 0) {
        await SunmiPrinter.printText(
          'Non ancora consegnati: ${c.inCorso}',
          style: SunmiTextStyle(fontSize: 22),
        );
      }
      if (c.annullati > 0) {
        await SunmiPrinter.printText(
          'Annullati (esclusi): ${c.annullati}',
          style: SunmiTextStyle(fontSize: 22),
        );
      }
      await SunmiPrinter.printText(
        'Voci: ${c.voci}   Pezzi: ${c.pezzi}',
        style: SunmiTextStyle(fontSize: 22),
      );
      await SunmiPrinter.printText('--------------------------------');

      // --- IMPORTI, le stesse voci del pannello Lenny Platform ---
      await SunmiPrinter.lineWrap(1);
      await _riga('Subtotale', c.subtotale);
      await _riga('Rincaro', c.rincaro);
      await _riga('Consegna', c.consegna);
      await _riga('Tassa', c.tassa);
      if (c.sconto > 0) {
        await _riga('Sconti', -c.sconto);
      }
      await SunmiPrinter.printText('--------------------------------');
      await SunmiPrinter.printText(
        'TOTALE',
        style: SunmiTextStyle(bold: true, fontSize: 28),
      );
      await SunmiPrinter.printText(
        'EUR ${c.totale.toStringAsFixed(2)}',
        style: SunmiTextStyle(
          bold: true,
          fontSize: 32,
          align: SunmiPrintAlign.RIGHT,
        ),
      );
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('================================');
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText(
        'Totali calcolati il ${c.generatoFormattato}',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 20),
      );

      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.cutPaper();

      return await _osservaDopoIlTaglio('Chiusura interrotta.');
    } catch (e) {
      debugPrint('Errore stampa chiusura: $e');
      final problema = await problemaCorrente();
      return EsitoStampa.fallita(
        problema ?? 'Errore durante la stampa della chiusura',
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
