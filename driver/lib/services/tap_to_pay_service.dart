import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mek_stripe_terminal/mek_stripe_terminal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';

/// I momenti dell'incasso con la carta appoggiata al telefono.
enum TapToPayStato {
  inattivo,
  verifica, // si prepara il lettore e il pagamento
  avvicinaCarta, // il telefono aspetta la carta
  conferma, // carta letta, il server sta registrando l'incasso
  riuscito,
  nonDisponibile, // questo telefono non puo' farlo: si spiega perche'
  fallito, // la carta e' stata letta ma il pagamento non e' passato
}

class TapToPayState {
  final TapToPayStato stato;
  final String? motivo;

  const TapToPayState(this.stato, {this.motivo});

  static const iniziale = TapToPayState(TapToPayStato.inattivo);
}

/// Chiave di collegamento del lettore (dura pochi minuti) e postazione.
class ChiaveLettore {
  final String secret;
  final String location;
  final bool testMode;

  const ChiaveLettore({
    required this.secret,
    required this.location,
    required this.testMode,
  });
}

/// Il pagamento da far leggere al telefono.
class IncassoPreparato {
  final String clientSecret;
  final String paymentIntentId;
  final String amount;
  final String currency;

  const IncassoPreparato({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
  });
}

/// Il telefono del driver diventa il lettore di carte (Tap to Pay).
///
/// Sequenza: chiave del lettore dal server, controllo che il telefono possa
/// farlo (Android 11 aggiornato, NFC, non sbloccato), collegamento del
/// lettore, pagamento preparato dal server, lettura della carta, e infine la
/// conferma al server che segna l'ordine pagato con Stripe. Il webhook di
/// Stripe fa lo stesso in seconda battuta: un incasso riuscito non si perde.
class TapToPayService {
  /// Id del metodo "Stripe" in payment_methods: e' quello che l'ordine assume
  /// quando l'incasso con la carta sul telefono riesce.
  static const int metodoStripe = 4;

  /// Su iPhone serve un permesso di Apple concesso per QUESTA app
  /// (com.apple.developer.proximity-reader.payment.acceptance), che si chiede
  /// dal profilo sviluppatore e arriva in settimane. Finche' non c'e', il
  /// pulsante lo dice chiaro invece di far chiudere l'app. Quando Apple lo
  /// concede: mettere true qui, aggiungere l'entitlement in Runner.entitlements
  /// e ricompilare (procedura in docs/stripe-pagamenti.md).
  static const bool disponibileSuIphone = false;

  final ValueNotifier<TapToPayState> stato = ValueNotifier(TapToPayState.iniziale);

  /// Quando il pagamento e' in corso si puo' interrompere (il cliente ci
  /// ripensa, paga in contanti).
  CancelableFuture<PaymentIntent>? _inCorso;

  bool get inCorso =>
      stato.value.stato == TapToPayStato.verifica ||
      stato.value.stato == TapToPayStato.avvicinaCarta ||
      stato.value.stato == TapToPayStato.conferma;

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyApiToken);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ------------------------------------------------------------------
  // Server
  // ------------------------------------------------------------------

  Future<ChiaveLettore> chiaveLettore() async {
    final r = await http
        .post(
          Uri.parse('${AppConstants.apiUrl}/stripe/terminal-token'),
          headers: await _headers(),
          body: json.encode(<String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 30));
    final d = _decodifica(r);
    if (r.statusCode != 200 || d['success'] != true) {
      throw Exception(_messaggio(d,
          'Il POS non e\' disponibile in questo momento. Riscuoti in contanti.'));
    }
    final dati = Map<String, dynamic>.from(d['data'] as Map);
    final secret = (dati['secret'] ?? '').toString();
    final location = (dati['location'] ?? '').toString();
    if (secret.isEmpty || location.isEmpty) {
      throw Exception('Il POS non e\' configurato. Riscuoti in contanti.');
    }
    return ChiaveLettore(
      secret: secret,
      location: location,
      testMode: dati['test_mode'] == true,
    );
  }

  /// [orderSource]: 'food' o 'partner'. Il server cerca l'ordine nella
  /// tabella giusta: i numeri degli ordini partner non sono quelli dei food.
  Future<IncassoPreparato> preparaIncasso(
    int orderId, {
    String orderSource = 'food',
  }) async {
    final r = await http
        .post(
          Uri.parse('${AppConstants.apiUrl}/stripe/tap-to-pay'),
          headers: await _headers(),
          body: json.encode(<String, dynamic>{
            'order_id': orderId,
            'order_source': orderSource,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final d = _decodifica(r);
    if (r.statusCode != 200 || d['success'] != true) {
      throw Exception(_messaggio(d,
          'Non riusciamo ad avviare l\'incasso. Riprova o riscuoti in contanti.'));
    }
    final dati = Map<String, dynamic>.from(d['data'] as Map);
    final cs = (dati['client_secret'] ?? '').toString();
    if (cs.isEmpty) {
      throw Exception(
          'Non riusciamo ad avviare l\'incasso. Riscuoti in contanti.');
    }
    return IncassoPreparato(
      clientSecret: cs,
      paymentIntentId: (dati['payment_intent_id'] ?? '').toString(),
      amount: (dati['amount'] ?? '').toString(),
      currency: (dati['currency'] ?? 'EUR').toString(),
    );
  }

  /// La carta e' stata letta: il server verifica su Stripe e segna l'ordine
  /// pagato. Qualche tentativo, perche' i soldi sono gia' incassati e un
  /// singhiozzo di rete non deve lasciare l'ordine "da riscuotere".
  Future<void> confermaIncasso(
    int orderId,
    String paymentIntentId, {
    String orderSource = 'food',
  }) async {
    Object? ultimo;
    for (var tentativo = 0; tentativo < 4; tentativo++) {
      try {
        final r = await http
            .post(
              Uri.parse('${AppConstants.apiUrl}/stripe/tap-to-pay/confirm'),
              headers: await _headers(),
              body: json.encode(<String, dynamic>{
                'order_id': orderId,
                'payment_intent_id': paymentIntentId,
                'order_source': orderSource,
              }),
            )
            .timeout(const Duration(seconds: 30));
        final d = _decodifica(r);
        if (r.statusCode == 200 && d['success'] == true) return;
        // 402 = la lettura c'e' stata ma il pagamento non e' passato: inutile riprovare.
        if (r.statusCode == 402) {
          throw Exception(_messaggio(d,
              'L\'incasso non e\' andato a buon fine. Riprova o riscuoti in contanti.'));
        }
        ultimo = Exception(_messaggio(d, 'Conferma non riuscita.'));
      } on Exception catch (e) {
        if (e.toString().contains('non e\' andato')) rethrow;
        ultimo = e;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw ultimo ?? Exception('Conferma non riuscita.');
  }

  // ------------------------------------------------------------------
  // Lettore
  // ------------------------------------------------------------------

  Future<void> incassa(int orderId, {String orderSource = 'food'}) async {
    if (inCorso) return;
    stato.value = const TapToPayState(TapToPayStato.verifica);

    if (Platform.isIOS && !disponibileSuIphone) {
      stato.value = const TapToPayState(TapToPayStato.nonDisponibile,
          motivo:
              'Su iPhone il POS arriva con un prossimo aggiornamento. Per ora riscuoti in contanti o col POS fisico.');
      return;
    }

    try {
      // 1. Chiave del lettore e postazione, dal server.
      final chiave = await chiaveLettore();

      // 2. Il lettore si accende una volta sola per esecuzione.
      if (!Terminal.isInitialized) {
        await Terminal.init(fetchToken: _nuovaChiave);
      }

      // 3. Questo telefono puo' leggere le carte?
      final config = TapToPayDiscoveryConfiguration(isSimulated: false);
      final capace = await Terminal.instance.supportsReadersOfType(
        deviceType: DeviceType.tapToPay,
        discoveryConfiguration: config,
      );
      if (!capace) {
        stato.value = const TapToPayState(TapToPayStato.nonDisponibile,
            motivo:
                'Questo telefono non puo\' fare da POS: serve Android aggiornato, con NFC e senza sblocchi. Riscuoti in contanti.');
        return;
      }

      // 4. Collegamento (o riuso) del lettore.
      final collegato = await Terminal.instance.getConnectedReader();
      if (collegato == null) {
        final letti = await Terminal.instance
            .discoverReaders(config)
            .firstWhere((l) => l.isNotEmpty);
        await Terminal.instance.connectReader(
          letti.first,
          configuration: TapToPayConnectionConfiguration(
            locationId: chiave.location,
            merchantDisplayName: 'Lenny',
            readerDelegate: _LettoreSilenzioso(),
          ),
        );
      }

      // 5. Il pagamento lo prepara il server: importo e ordine li decide lui.
      final incasso = await preparaIncasso(orderId, orderSource: orderSource);
      final intent =
          await Terminal.instance.retrievePaymentIntent(incasso.clientSecret);

      // 6. Il telefono aspetta la carta.
      stato.value = const TapToPayState(TapToPayStato.avvicinaCarta);
      _inCorso = Terminal.instance.processPaymentIntent(intent);
      await _inCorso!;
      _inCorso = null;

      // 7. Il server registra l'incasso sull'ordine.
      stato.value = const TapToPayState(TapToPayStato.conferma);
      await confermaIncasso(
        orderId,
        incasso.paymentIntentId,
        orderSource: orderSource,
      );

      stato.value = const TapToPayState(TapToPayStato.riuscito);
    } on TerminalException catch (e) {
      _inCorso = null;
      final codice = e.code.name.toLowerCase();
      if (codice.contains('cancel')) {
        stato.value = TapToPayState.iniziale;
        return;
      }
      stato.value = TapToPayState(_tipoDiErrore(codice), motivo: _spiega(codice, e));
    } catch (e) {
      _inCorso = null;
      final m = e.toString().replaceFirst('Exception: ', '').trim();
      stato.value = TapToPayState(
        m.contains('non e\' configurato') || m.contains('non e\' disponibile')
            ? TapToPayStato.nonDisponibile
            : TapToPayStato.fallito,
        motivo: m.isNotEmpty
            ? m
            : 'L\'incasso non e\' andato a buon fine. Riprova o riscuoti in contanti.',
      );
    }
  }

  /// Il cliente ci ripensa: si interrompe la lettura.
  Future<void> interrompi() async {
    try {
      await _inCorso?.cancel();
    } catch (_) {}
    _inCorso = null;
    if (stato.value.stato != TapToPayStato.riuscito) {
      stato.value = TapToPayState.iniziale;
    }
  }

  void azzera() => stato.value = TapToPayState.iniziale;

  Future<String> _nuovaChiave() async {
    final chiave = await chiaveLettore();
    return chiave.secret;
  }

  TapToPayStato _tipoDiErrore(String codice) {
    if (codice.contains('unsupported') ||
        codice.contains('nfc') ||
        codice.contains('notsupported') ||
        codice.contains('androidapilevel') ||
        codice.contains('rooted') ||
        codice.contains('attestation') ||
        codice.contains('developeroptions')) {
      return TapToPayStato.nonDisponibile;
    }
    return TapToPayStato.fallito;
  }

  /// La causa detta come sta, con la via d'uscita accanto.
  String _spiega(String codice, TerminalException e) {
    if (codice.contains('declined')) {
      return 'La banca ha rifiutato la carta. Il cliente puo\' provarne un\'altra, oppure riscuoti in contanti.';
    }
    if (codice.contains('insufficientfunds')) {
      return 'La banca dice che sulla carta non c\'e\' abbastanza. Un\'altra carta, oppure contanti.';
    }
    if (codice.contains('expired')) {
      return 'La carta e\' scaduta. Un\'altra carta, oppure contanti.';
    }
    if (codice.contains('cardread') || codice.contains('readtimeout')) {
      return 'La carta non e\' stata letta. Tienila ferma sul retro del telefono e riprova.';
    }
    if (codice.contains('notconnected') || codice.contains('reader')) {
      return 'Il POS si e\' scollegato. Riprova.';
    }
    if (codice.contains('nfc')) {
      return 'L\'NFC del telefono e\' spento. Accendilo dalle impostazioni e riprova.';
    }
    if (codice.contains('androidapilevel') || codice.contains('unsupported')) {
      return 'Questo telefono non puo\' fare da POS: serve Android aggiornato con NFC. Riscuoti in contanti.';
    }
    if (codice.contains('developeroptions')) {
      return 'Le opzioni sviluppatore del telefono sono attive e il POS non parte. Spegnile e riprova.';
    }
    if (codice.contains('rooted') || codice.contains('attestation')) {
      return 'Il telefono non passa i controlli di sicurezza richiesti per fare da POS. Riscuoti in contanti.';
    }
    final m = e.message.trim();
    return m.isNotEmpty
        ? '$m. Puoi riprovare o riscuotere in contanti.'
        : 'L\'incasso non e\' andato a buon fine. Riprova o riscuoti in contanti.';
  }

  Map<String, dynamic> _decodifica(http.Response r) {
    try {
      final d = json.decode(r.body);
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  String _messaggio(Map<String, dynamic> d, String predefinito) {
    final err = d['error'];
    if (err is Map && (err['message'] ?? '').toString().isNotEmpty) {
      return err['message'].toString();
    }
    if ((d['message'] ?? '').toString().isNotEmpty) {
      return d['message'].toString();
    }
    return predefinito;
  }
}

/// Il lettore e' il telefono: niente aggiornamenti da installare, niente
/// schermo secondario. Le voci obbligatorie del contratto restano vuote.
class _LettoreSilenzioso extends TapToPayReaderDelegate {
  @override
  void onStartInstallingUpdate(
      ReaderSoftwareUpdate update, Cancellable cancelUpdate) {}

  @override
  void onReportReaderSoftwareUpdateProgress(double progress) {}

  @override
  void onFinishInstallingUpdate(
      ReaderSoftwareUpdate? update, TerminalException? exception) {}

  @override
  void onRequestReaderDisplayMessage(ReaderDisplayMessage message) {}

  @override
  void onRequestReaderInput(List<ReaderInputOption> options) {}
}
