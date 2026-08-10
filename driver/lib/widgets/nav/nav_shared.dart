// Core di navigazione portato dal progetto taxi (nav_shared.dart): icone
// manovra, formattazione distanze e voce del navigatore. La parte mappa e'
// riscritta su flutter_map in nav_map_view.dart; qui resta solo la logica
// pura, identica all'originale dove possibile.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/nav_route.dart';
import '../../services/tts_service.dart';

/// "200 m" / "1.2 km" per la UI.
String navDistLabel(int m) =>
    m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '$m m';

/// "200 metri" / "1,2 chilometri" per la voce.
String navDistSpeech(int m) => m >= 1000
    ? '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} chilometri'
    : '$m metri';

/// Icona freccia dal codice manovra GraphHopper (sign).
IconData navManeuverIcon(int sign) {
  switch (sign) {
    case -3:
    case -2:
      return Icons.turn_sharp_left;
    case -1:
    case -7:
      return Icons.turn_slight_left;
    case 0:
      return Icons.straight;
    case 1:
    case 7:
      return Icons.turn_slight_right;
    case 2:
    case 3:
      return Icons.turn_sharp_right;
    case 4:
      return Icons.flag;
    case 6:
      return Icons.roundabout_left;
    default:
      return Icons.straight;
  }
}

/// Voce del navigatore: annuncia la prossima manovra in italiano, una volta
/// per manovra.
///
/// SPENTA DI DEFAULT (vincolo di progetto), con pref propria che ricorda la
/// scelta. E' un canale SEPARATO dagli annunci eventi ordine
/// ('annunci_vocali_driver', default acceso): due voci, due interruttori.
/// Parla attraverso TtsService.prova(), cosi' riusa la voce italiana gia'
/// scelta dal driver nelle impostazioni.
class NavVoice {
  static const String chiavePrefs = 'voce_navigazione_driver';

  /// Sotto questa distanza scatta il secondo annuncio ("adesso gira").
  static const int metriAnnuncioVicino = 150;

  final TtsService _tts = TtsService();
  String? _chiaveManovra;
  bool _annuncioVicinoFatto = false;
  bool enabled = false;

  /// Carica la preferenza salvata (default: spenta).
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(chiavePrefs) ?? false;
    } catch (_) {
      enabled = false;
    }
    if (enabled) {
      await _tts.init();
    }
  }

  /// Accende/spegne e RICORDA la scelta.
  Future<void> setEnabled(bool valore) async {
    enabled = valore;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(chiavePrefs, valore);
    } catch (_) {}
    if (valore) {
      await _tts.init();
    } else {
      await _tts.stop();
    }
  }

  /// Annuncia [istruzione] con schema a DUE STADI: una volta quando diventa
  /// la manovra corrente (con la distanza: "Tra 800 metri, svolta...") e una
  /// seconda volta sotto [metriAnnuncioVicino] ("Svolta a destra") — senza il
  /// secondo stadio una manovra a 2 km veniva annunciata solo all'inizio del
  /// tratto e mai piu' al momento di girare.
  ///
  /// La dedup usa l'IDENTITA' dell'istruzione (indice nella geometria), non
  /// il testo: due "Svolta a destra" consecutive sono manovre diverse.
  /// [metri] = distanza attuale dalla manovra (gia' scalata da NavGuidance).
  void announce(NavInstruction? istruzione, int metri) {
    if (!enabled || istruzione == null || istruzione.text.isEmpty) return;
    final chiave = istruzione.interval.isNotEmpty
        ? 'i${istruzione.interval[0]}'
        : istruzione.text;
    if (chiave != _chiaveManovra) {
      _chiaveManovra = chiave;
      _annuncioVicinoFatto = metri < metriAnnuncioVicino;
      final frase = metri >= 30
          ? 'Tra ${navDistSpeech(metri)}, ${istruzione.text}'
          : istruzione.text;
      _tts.prova(frase);
    } else if (!_annuncioVicinoFatto && metri <= metriAnnuncioVicino) {
      _annuncioVicinoFatto = true;
      _tts.prova(istruzione.text);
    }
  }

  /// Frase libera (es. "Ritiro completato. Prossima tappa: ...").
  void say(String frase) {
    if (!enabled) return;
    _tts.prova(frase);
  }

  /// Azzera la dedup (nuova gamba: la prima manovra va riannunciata).
  void reset() {
    _chiaveManovra = null;
    _annuncioVicinoFatto = false;
  }

  void stop() => _tts.stop();
}
