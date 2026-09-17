import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../config/app_constants.dart';

/// Quello che il server restituisce per aprire il foglio di pagamento.
class StripeSheetData {
  final String clientSecret;
  final String paymentIntentId;
  final String publishableKey;
  final String? customerId;
  final String? ephemeralKey;
  final String merchantDisplayName;
  final String amount;
  final String currency;
  final bool testMode;

  const StripeSheetData({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.publishableKey,
    required this.customerId,
    required this.ephemeralKey,
    required this.merchantDisplayName,
    required this.amount,
    required this.currency,
    required this.testMode,
  });

  factory StripeSheetData.fromJson(Map<String, dynamic> j) {
    return StripeSheetData(
      clientSecret: (j['client_secret'] ?? '').toString(),
      paymentIntentId: (j['payment_intent_id'] ?? '').toString(),
      publishableKey: (j['publishable_key'] ?? '').toString(),
      customerId: j['customer_id']?.toString(),
      ephemeralKey: j['ephemeral_key']?.toString(),
      merchantDisplayName: (j['merchant_display_name'] ?? 'Lenny').toString(),
      amount: (j['amount'] ?? '').toString(),
      currency: (j['currency'] ?? 'EUR').toString(),
      testMode: j['test_mode'] == true,
    );
  }
}

/// Esito del foglio di pagamento, gia' in parole semplici.
class StripeEsito {
  final bool riuscito;
  final bool annullato;
  final String? motivo;

  const StripeEsito._(this.riuscito, this.annullato, this.motivo);

  const StripeEsito.ok() : this._(true, false, null);
  const StripeEsito.annullatoDalCliente() : this._(false, true, null);
  const StripeEsito.fallito(String motivo) : this._(false, false, motivo);
}

/// Il pagamento con Stripe: carta, Apple Pay, Google Pay, Link e carta
/// ricordata, nel foglio nativo di Stripe (niente webview).
///
/// Sequenza: il server prepara il pagamento (importo e ordine li decide lui),
/// il foglio raccoglie la carta, e a foglio chiuso e' di nuovo il server a
/// verificare su Stripe e a confermare l'ordine. L'app non decide mai da sola
/// che un ordine e' pagato.
class StripePaymentService {
  /// Apple Pay si accende solo quando il Merchant ID esiste sul profilo
  /// sviluppatore Apple, l'app ha il permesso relativo (Runner.entitlements)
  /// e il certificato e' caricato su Stripe. Acceso senza questi tre pezzi il
  /// foglio non si aprirebbe affatto su iPhone; spento, il foglio funziona
  /// lo stesso con carte, Google Pay e Link.
  ///
  /// FALSE finche' il Merchant ID `merchant.com.lenny.customer` non e' stato
  /// creato (docs/stripe-pagamenti.md, par. 5.2): quando c'e', mettere true
  /// qui e riattivare il blocco in ios/Runner/Runner.entitlements.
  static const bool applePayPronto = false;
  static const String appleMerchantId = 'merchant.com.lenny.customer';

  /// Schema con cui Stripe riporta il cliente nell'app dopo un metodo che
  /// passa da un'altra app o da un sito (conferma della banca, wallet).
  /// Dichiarato anche in ios/Runner/Info.plist e nel manifest Android.
  static const String schemaRitorno = 'lennycustomer';

  /// Chiave di Stripe gia' applicata in questa esecuzione: non si riapplica a
  /// ogni pagamento.
  static String _chiaveApplicata = '';

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyApiToken) ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': token,
    };
  }

  /// Chiede al server di preparare il pagamento dell'ordine.
  /// Lancia un'eccezione con un messaggio gia' leggibile se non si puo'.
  Future<StripeSheetData> preparaFoglio(int orderId) async {
    final headers = await _headers();
    final response = await http
        .post(
          Uri.parse('${AppConstants.apiUrl}/stripe/payment-sheet'),
          headers: headers,
          body: json.encode({'order_id': orderId}),
        )
        .timeout(const Duration(seconds: AppConstants.apiTimeout));

    final dati = _decodifica(response);
    if (response.statusCode != 200 || dati['success'] != true) {
      throw Exception(_messaggioErrore(dati,
          'Il pagamento con carta non e\' disponibile in questo momento.'));
    }
    final sheet =
        StripeSheetData.fromJson(Map<String, dynamic>.from(dati['data'] as Map));
    if (sheet.clientSecret.isEmpty || sheet.publishableKey.isEmpty) {
      throw Exception(
          'Il pagamento con carta non e\' configurato. Scegli un altro metodo.');
    }
    return sheet;
  }

  /// Configura Stripe (una volta per chiave) e prepara il foglio.
  Future<void> inizializzaFoglio(StripeSheetData dati) async {
    if (_chiaveApplicata != dati.publishableKey) {
      Stripe.publishableKey = dati.publishableKey;
      if (applePayPronto) {
        Stripe.merchantIdentifier = appleMerchantId;
      }
      Stripe.urlScheme = schemaRitorno;
      await Stripe.instance.applySettings();
      _chiaveApplicata = dati.publishableKey;
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: dati.clientSecret,
        merchantDisplayName: dati.merchantDisplayName,
        returnURL: '$schemaRitorno://stripe-redirect',
        customerId: dati.customerId,
        customerEphemeralKeySecret: dati.ephemeralKey,
        style: ThemeMode.light,
        applePay: applePayPronto
            ? const PaymentSheetApplePay(merchantCountryCode: 'IT')
            : null,
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: 'IT',
          currencyCode: dati.currency,
          testEnv: dati.testMode,
        ),
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            background: Colors.white,
            primary: AppColors.primary,
            componentBackground: Color(0xFFF5F6F8),
            componentBorder: Color(0xFFE3E6EA),
            componentDivider: Color(0xFFE3E6EA),
            componentText: AppColors.dark,
            primaryText: AppColors.dark,
            secondaryText: AppColors.grayDark,
            placeholderText: AppColors.gray,
            icon: AppColors.grayDark,
            error: AppColors.danger,
          ),
          shapes: PaymentSheetShape(borderRadius: 12, borderWidth: 1),
          primaryButton: PaymentSheetPrimaryButtonAppearance(
            colors: PaymentSheetPrimaryButtonTheme(
              light: PaymentSheetPrimaryButtonThemeColors(
                background: AppColors.primary,
                text: Colors.white,
              ),
              dark: PaymentSheetPrimaryButtonThemeColors(
                background: AppColors.primary,
                text: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mostra il foglio e, se il cliente conclude, fa confermare l'ordine al server.
  Future<StripeEsito> presentaEConferma(int orderId, StripeSheetData dati) async {
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return const StripeEsito.annullatoDalCliente();
      }
      return StripeEsito.fallito(_spiega(e));
    } catch (_) {
      return const StripeEsito.fallito(
          'Il pagamento non e\' andato a buon fine. Puoi riprovare o scegliere un altro metodo.');
    }

    // Il foglio si e' chiuso senza errori: e' il server a dire l'ultima parola,
    // verificando su Stripe e chiudendo l'ordine. Il webhook fa lo stesso in
    // seconda battuta, quindi una conferma mancata qui non perde il pagamento.
    try {
      await confermaPagamento(orderId, dati.paymentIntentId);
      return const StripeEsito.ok();
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      return StripeEsito.fallito(msg);
    }
  }

  /// Chiede al server di verificare il pagamento e chiudere l'ordine.
  Future<String> confermaPagamento(int orderId, String paymentIntentId) async {
    final headers = await _headers();
    // Un paio di tentativi: subito dopo il foglio la rete puo' avere un
    // singhiozzo, e l'ordine e' gia' pagato lato Stripe.
    Object? ultimoErrore;
    for (var tentativo = 0; tentativo < 3; tentativo++) {
      try {
        final response = await http
            .post(
              Uri.parse('${AppConstants.apiUrl}/stripe/confirm-payment'),
              headers: headers,
              body: json.encode({
                'order_id': orderId,
                'payment_intent_id': paymentIntentId,
              }),
            )
            .timeout(const Duration(seconds: AppConstants.apiTimeout));
        final dati = _decodifica(response);
        if (response.statusCode == 200 && dati['success'] == true) {
          return ((dati['data'] as Map?)?['status'] ?? 'paid').toString();
        }
        // 402 = il pagamento non e' passato: inutile riprovare.
        throw Exception(_messaggioErrore(dati,
            'Il pagamento non e\' stato confermato. Riprova tra un momento.'));
      } catch (e) {
        ultimoErrore = e;
        if (e is Exception && e.toString().contains('non e\' andato') ||
            e.toString().contains('non ha autorizzato') ||
            e.toString().contains('scaduta')) {
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    throw ultimoErrore ?? Exception('Conferma non riuscita');
  }

  Map<String, dynamic> _decodifica(http.Response response) {
    try {
      final d = json.decode(response.body);
      if (d is Map<String, dynamic>) return d;
      return {};
    } catch (_) {
      return {};
    }
  }

  String _messaggioErrore(Map<String, dynamic> dati, String predefinito) {
    final err = dati['error'];
    if (err is Map && (err['message'] ?? '').toString().isNotEmpty) {
      return err['message'].toString();
    }
    if ((dati['message'] ?? '').toString().isNotEmpty) {
      return dati['message'].toString();
    }
    return predefinito;
  }

  /// La causa, detta come sta, con la via d'uscita accanto. Stripe comunica
  /// il motivo del rifiuto: qui lo si traduce senza sigle.
  String _spiega(StripeException e) {
    final codice = [
      e.error.declineCode,
      e.error.stripeErrorCode,
      e.error.code.name,
    ].whereType<String>().join(' ').toLowerCase();

    const altrimenti = 'Puoi usare un\'altra carta o scegliere un altro metodo.';
    if (codice.contains('insufficient_funds')) {
      return 'La tua banca dice che sulla carta non c\'e\' abbastanza disponibilita\'. $altrimenti';
    }
    if (codice.contains('expired_card')) {
      return 'La carta e\' scaduta. $altrimenti';
    }
    if (codice.contains('cvc')) {
      return 'Il codice di sicurezza non e\' corretto. Riprova o scegli un altro metodo.';
    }
    if (codice.contains('authentication')) {
      return 'La conferma della tua banca non e\' andata a buon fine. Riprova o scegli un altro metodo.';
    }
    if (codice.contains('declined') ||
        codice.contains('do_not_honor') ||
        codice.contains('lost_card') ||
        codice.contains('stolen_card')) {
      return 'La tua banca non ha autorizzato il pagamento. $altrimenti';
    }
    final m = (e.error.localizedMessage ?? e.error.message ?? '').trim();
    return m.isNotEmpty
        ? '$m Puoi riprovare o scegliere un altro metodo.'
        : 'Il pagamento non e\' andato a buon fine. Puoi riprovare o scegliere un altro metodo.';
  }
}
