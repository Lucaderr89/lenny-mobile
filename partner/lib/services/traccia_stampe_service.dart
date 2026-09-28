import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';

/// Da dove parte una stampa: in caso di contestazione conta sapere se la
/// comanda e' uscita da sola o se qualcuno ha premuto un bottone dopo.
enum OrigineStampa { automatica, manuale, storico }

/// Traccia delle comande sul server.
///
/// Ogni esito di stampa, riuscito o fallito con il motivo, viene mandato al
/// server, che lo conserva sull'ordine: quando un ristorante dice "la comanda
/// non e' uscita" la risposta sta nel DB, non sul tablet.
///
/// Gli esiti passano da una coda salvata su disco: se la rete cade subito
/// dopo la stampa, o il tablet si riavvia, partono al primo collegamento
/// utile. Sono proprio i momenti in cui nasce una contestazione, e la prova
/// non deve perdersi li'.
///
/// L'ora non la decide il tablet: si manda da quanti secondi e' successo e il
/// server la ricava dal suo orologio. Quello del Sunmi puo' essere sbagliato
/// anche di ore.
class TracciaStampe {
  TracciaStampe._();
  static final TracciaStampe instance = TracciaStampe._();

  static const String _chiaveCoda = 'partner_traccia_stampe_coda';
  static const String _chiaveDispositivo = 'partner_dispositivo_id';

  /// Oltre questo numero di esiti in attesa si scartano i piu' vecchi: la
  /// coda non deve crescere all'infinito se il server resta irraggiungibile.
  static const int _maxCoda = 500;
  static const int _perInvio = 50;

  final List<Map<String, dynamic>> _coda = [];
  Future<void>? _caricamento;
  bool _invioInCorso = false;
  String? _dispositivo;
  final Random _casuale = Random.secure();

  /// Ultimo motivo di fallimento gia' segnalato per ogni ordine. La stampa
  /// automatica riprova a ogni giro (20 s): con la carta finita per mezz'ora
  /// ogni ordine produrrebbe novanta righe identiche. Si segnala solo quando
  /// il motivo cambia.
  final Map<int, String> _ultimoFallimento = {};

  /// Identificativo di questo dispositivo, generato una volta e salvato.
  /// Distingue il Sunmi del locale da un telefono su cui il titolare ha
  /// aperto la stessa app con le stesse credenziali.
  Future<String> dispositivo() async {
    final noto = _dispositivo;
    if (noto != null) return noto;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_chiaveDispositivo);
    if (id == null || id.isEmpty) {
      id = _codice(16);
      await prefs.setString(_chiaveDispositivo, id);
    }
    _dispositivo = id;
    return id;
  }

  String _codice(int lunghezza) {
    const alfabeto = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      lunghezza,
      (_) => alfabeto[_casuale.nextInt(alfabeto.length)],
    ).join();
  }

  Future<void> _carica() {
    return _caricamento ??= () async {
      final prefs = await SharedPreferences.getInstance();
      for (final riga in prefs.getStringList(_chiaveCoda) ?? const []) {
        try {
          _coda.add(Map<String, dynamic>.from(jsonDecode(riga) as Map));
        } catch (_) {
          // Riga illeggibile: meglio perderla che bloccare la coda.
        }
      }
    }();
  }

  Future<void> _salva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_chiaveCoda, _coda.map(jsonEncode).toList());
  }

  /// Registra l'esito di una stampa e prova subito a mandarlo.
  /// Non lancia mai: la traccia non deve disturbare la stampa.
  Future<void> registra({
    required int orderId,
    required bool ok,
    String? motivo,
    required OrigineStampa origine,
  }) async {
    try {
      if (ok) {
        _ultimoFallimento.remove(orderId);
      } else if (origine == OrigineStampa.automatica) {
        final m = motivo ?? '';
        if (_ultimoFallimento[orderId] == m) return;
        _ultimoFallimento[orderId] = m;
      }

      await _carica();
      final adesso = DateTime.now().millisecondsSinceEpoch;
      _coda.add({
        'uid': '${orderId}_${adesso}_${_codice(6)}',
        'order_id': orderId,
        'outcome': ok ? 'printed' : 'failed',
        'source': switch (origine) {
          OrigineStampa.automatica => 'auto',
          OrigineStampa.manuale => 'manual',
          OrigineStampa.storico => 'history',
        },
        'reason': ok ? null : motivo,
        'at_ms': adesso,
      });
      if (_coda.length > _maxCoda) {
        _coda.removeRange(0, _coda.length - _maxCoda);
      }
      await _salva();
    } catch (e) {
      debugPrint('Traccia stampa non salvata: $e');
      return;
    }
    unawaited(invia());
  }

  /// Manda al server gli esiti in coda. Si chiama dopo ogni stampa e a ogni
  /// aggiornamento ordini riuscito: la coda si svuota appena torna la rete.
  Future<void> invia() async {
    if (_invioInCorso) return;
    _invioInCorso = true;
    try {
      await _carica();
      while (_coda.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.keyApiToken);
        if (token == null) return;

        final lotto = _coda.take(_perInvio).toList();
        final adesso = DateTime.now().millisecondsSinceEpoch;
        final eventi = lotto
            .map(
              (e) => {
                'uid': e['uid'],
                'order_id': e['order_id'],
                'outcome': e['outcome'],
                'source': e['source'],
                'reason': e['reason'],
                // Eta' dell'esito secondo il tablet: l'ora la fa il server.
                'age_s': max(
                  0,
                  ((adesso - (e['at_ms'] as num).toInt()) / 1000).round(),
                ),
              },
            )
            .toList();

        final response = await http
            .post(
              Uri.parse(AppConstants.printLogEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'device': await dispositivo(),
                'events': eventi,
              }),
            )
            .timeout(const Duration(seconds: AppConstants.apiTimeout));
        if (response.statusCode != 200) return;

        final data = jsonDecode(response.body);
        final presi =
            ((data is Map ? data['data'] : null) as Map?)?['accepted']
                as List?;
        final uidPresi = (presi ?? const []).map((e) => e.toString()).toSet();
        if (uidPresi.isEmpty) return;

        _coda.removeWhere((e) => uidPresi.contains(e['uid']));
        await _salva();
        // Se il server non li ha presi tutti si riprova al prossimo giro,
        // non subito: un errore del DB non si risolve in un millisecondo.
        if (uidPresi.length < lotto.length) return;
      }
    } catch (e) {
      debugPrint('Invio traccia stampe non riuscito: $e');
    } finally {
      _invioInCorso = false;
    }
  }
}
