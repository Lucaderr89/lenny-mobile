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

  /// Dimensione del testo corrente; i titoli e gli importi chiave sono piu'
  /// grandi, niente va sotto.
  static const int _corpo = 24;

  /// Stampa una riga di testo. Tutto il testo della carta esce in GRASSETTO e
  /// mai sotto i 24 punti: sulla carta termica il tratto sottile del testo
  /// normale esce grigio e a volte illeggibile (segnalato da Giulietti KM0 il
  /// 26/10/2026: articoli, aggiunte e importi sbiaditi, titoli in grassetto
  /// perfetti). La densita' di stampa non si puo' alzare dall'app: l'SDK
  /// Sunmi la legge soltanto, quindi la leggibilita' passa da qui.
  Future<void> _testo(
    String testo, {
    int fontSize = _corpo,
    SunmiPrintAlign align = SunmiPrintAlign.LEFT,
    bool reverse = false,
  }) async {
    await SunmiPrinter.printText(
      testo,
      style: SunmiTextStyle(
        fontSize: fontSize,
        bold: true,
        align: align,
        reverse: reverse,
      ),
    );
  }

  /// Riga del riepilogo importi: etichetta a sinistra, cifra a destra.
  Future<void> _riga(String etichetta, double importo) async {
    await _testo(etichetta);
    await _testo(
      'EUR ${importo.toStringAsFixed(2)}',
      align: SunmiPrintAlign.RIGHT,
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
      await _testo(restaurantName, fontSize: 32, align: SunmiPrintAlign.CENTER);
      await SunmiPrinter.lineWrap(1);

      // Data e ora
      final dateFormatter = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();
      await _testo(
        '${dateFormatter.format(now)} - ${DateFormat('HH:mm').format(now)}',
        align: SunmiPrintAlign.CENTER,
      );

      await _testo(
        '================================',
        align: SunmiPrintAlign.CENTER,
      );
      await SunmiPrinter.lineWrap(1);

      // --- INFO ORDINE ---
      await _testo('ORDINE #${order.numeroOrdine}', fontSize: 28);
      await SunmiPrinter.lineWrap(2);

      // Tipo ordine - BEN IN EVIDENZA (bianco su nero)
      final orderType = order.isDelivery ? '  CONSEGNA  ' : '  ASPORTO  ';

      await _testo(
        orderType,
        fontSize: 40,
        align: SunmiPrintAlign.CENTER,
        reverse: true,
      );
      await SunmiPrinter.lineWrap(1);

      // Data ordine - BEN IN EVIDENZA
      await _testo(
        order.formattedDate,
        fontSize: 60,
        align: SunmiPrintAlign.CENTER,
      );
      await SunmiPrinter.lineWrap(1);

      // Orario consegna/ritiro - BEN IN EVIDENZA
      await _testo(order.timeSlot, fontSize: 60, align: SunmiPrintAlign.CENTER);
      await SunmiPrinter.lineWrap(2);

      // Pagamento - evidenziato in negativo (sfondo nero)
      final String paymentText = (order.paymentStatus == 'paid')
          ? '  PAGATO  '
          : '  DA PAGARE  ';
      await _testo(
        paymentText,
        fontSize: 40,
        align: SunmiPrintAlign.CENTER,
        reverse: true,
      );
      // Metodo di pagamento: per la cassa "DA PAGARE" da solo non basta,
      // contanti e bancomat si gestiscono in modo diverso.
      final metodoPagamento = (order.paymentMethodName ?? '').trim();
      if (metodoPagamento.isNotEmpty) {
        await _testo(
          metodoPagamento,
          fontSize: 28,
          align: SunmiPrintAlign.CENTER,
        );
      }
      await SunmiPrinter.lineWrap(1);

      await _testo('--------------------------------');

      // --- CLIENTE ---
      await _testo('CLIENTE');
      await _testo('Nome: ${order.customerName}');
      if (order.customerPhone.isNotEmpty) {
        await _testo('Tel: ${order.customerPhone}');
      }
      // Sugli asporti l'indirizzo non c'e': non si stampa un'etichetta vuota.
      if (order.isDelivery && order.deliveryAddress.trim().isNotEmpty) {
        await _testo('Indirizzo: ${order.deliveryAddress}');
      }
      await SunmiPrinter.lineWrap(1);

      await _testo('--------------------------------');

      // --- ARTICOLI ---
      await _testo('ARTICOLI');
      await SunmiPrinter.lineWrap(1);

      for (final item in order.items) {
        // Quantita' e nome, poi l'importo DELLA RIGA allineato a destra.
        // Stampare il prezzo unitario da solo si legge come importo di riga:
        // con 4 pezzi da 3,10 la riga vale 12,40, non 3,10.
        await _testo('${item.quantity}x ${item.name}');
        await _testo(
          'EUR ${item.lineTotal.toStringAsFixed(2)}',
          align: SunmiPrintAlign.RIGHT,
        );
        // Il prezzo unitario si mostra solo quando puo' servire, cioe' con piu'
        // di un pezzo, e tra parentesi per non confonderlo con l'importo di riga.
        if (item.quantity > 1) {
          await _testo(
            '(${item.quantity} x EUR ${item.price.toStringAsFixed(2)})',
            align: SunmiPrintAlign.RIGHT,
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
            await _testo('  ${entry.key}:');
            for (var extra in entry.value) {
              await _testo('    + ${extra.name}');
            }
          }
        }

        // Note prodotto
        if (item.notes != null && item.notes!.isNotEmpty) {
          await _testo('  Note: ${item.notes}');
        }

        await SunmiPrinter.lineWrap(1);
      }

      await _testo('--------------------------------');

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
      await _testo('--------------------------------');
      await _testo(
        order.isDelivery ? 'TOTALE CLIENTE' : 'TOTALE DA INCASSARE',
        fontSize: 28,
      );
      await _testo(
        'EUR ${order.total.toStringAsFixed(2)}',
        fontSize: 32,
        align: SunmiPrintAlign.RIGHT,
      );

      await SunmiPrinter.lineWrap(1);
      await _testo('================================');

      // --- NOTE ---
      if (order.note != null && order.note!.isNotEmpty) {
        await SunmiPrinter.lineWrap(1);
        await _testo('NOTE CLIENTE:');
        await _testo(order.note!);
        await SunmiPrinter.lineWrap(1);
        await _testo('================================');
      }

      // --- FOOTER ---
      await SunmiPrinter.lineWrap(2);
      await _testo('Grazie per la tua scelta!', align: SunmiPrintAlign.CENTER);
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

      await _testo(
        'CHIUSURA GIORNATA',
        fontSize: 28,
        align: SunmiPrintAlign.CENTER,
      );
      await _testo(c.ristorante, align: SunmiPrintAlign.CENTER);
      await _testo(
        c.dataFormattata,
        fontSize: 28,
        align: SunmiPrintAlign.CENTER,
      );
      await SunmiPrinter.lineWrap(1);
      await _testo('================================');

      // --- CONTEGGI ---
      await _testo('ORDINI: ${c.ordini}', fontSize: 26);
      await _testo('A domicilio: ${c.domicilio}   Asporto: ${c.asporto}');
      if (c.inCorso > 0) {
        await _testo('Non ancora consegnati: ${c.inCorso}');
      }
      if (c.annullati > 0) {
        await _testo('Annullati (esclusi): ${c.annullati}');
      }
      await _testo('Voci: ${c.voci}   Pezzi: ${c.pezzi}');
      await _testo('--------------------------------');

      // --- IMPORTI, le stesse voci del pannello Lenny Platform ---
      await SunmiPrinter.lineWrap(1);
      await _riga('Subtotale', c.subtotale);
      await _riga('Rincaro', c.rincaro);
      await _riga('Consegna', c.consegna);
      await _riga('Tassa', c.tassa);
      if (c.sconto > 0) {
        await _riga('Sconti', -c.sconto);
      }
      await _testo('--------------------------------');
      await _testo('TOTALE', fontSize: 28);
      await _testo(
        'EUR ${c.totale.toStringAsFixed(2)}',
        fontSize: 32,
        align: SunmiPrintAlign.RIGHT,
      );
      await SunmiPrinter.lineWrap(1);
      await _testo('================================');
      await SunmiPrinter.lineWrap(1);
      await _testo(
        'Totali calcolati il ${c.generatoFormattato}',
        align: SunmiPrintAlign.CENTER,
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

  /// Stampa di prova: una comanda finta completa, stampata con lo stesso
  /// codice delle comande vere, cosi' quello che si controlla (leggibilita',
  /// righe che vanno a capo) e' esattamente quello che arriva in cucina.
  /// Non passa dalla traccia sul server: non e' un ordine.
  Future<bool> printTest() async {
    // Il tasto si preme a schermo acceso: se il logo non era pronto
    // all'avvio, qui si puo' ancora preparare.
    await precaricaLogo();
    final esito = await _stampaComanda(_ordineDiProva(), 'PROVA DI STAMPA');
    return esito.ok;
  }

  /// Ordine finto per la stampa di prova, con dentro ogni parte della
  /// comanda: aggiunte, nota sul piatto, piu' pezzi, riepilogo importi e
  /// note del cliente. Gli importi quadrano come in un ordine vero.
  static Order _ordineDiProva() {
    return Order(
      id: 0,
      numeroOrdineGrezzo: 'PROVA',
      status: 'pending',
      statusLabel: 'Prova',
      customerName: 'Mario Rossi',
      customerPhone: '3331234567',
      deliveryAddress: 'Strada del Lavoro, 73, 47890, San Marino',
      total: 30.30,
      note: 'Citofono Rossi, secondo piano',
      timeSlotStart: '19:30:00',
      timeSlotEnd: '20:00:00',
      dateOrder: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      pickupDelivery: 'delivery',
      paymentStatus: 'pending',
      paymentMethodName: 'Contanti',
      items: [
        OrderItem(
          id: 1,
          name: 'Cheese Bacon Burger',
          quantity: 1,
          price: 9.80,
          extras: [OrderExtra(id: 1, name: 'Doppio cheddar', price: 0)],
        ),
        OrderItem(
          id: 2,
          name: 'Mozzarelline (8pz)',
          quantity: 2,
          price: 5.00,
          notes: 'Ben cotte',
        ),
        OrderItem(id: 3, name: 'Patate fritte', quantity: 1, price: 4.50),
      ],
      itemsTotal: 24.30,
      deliveryFee: 4.90,
      orderFee: 1.10,
    );
  }
}
