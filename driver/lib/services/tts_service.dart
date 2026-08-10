import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Annunci vocali della Modalita' Guida: il telefono PARLA invece di
/// farsi guardare. Solo eventi dell'app (nuovo ordine, cambio tappa,
/// revoca): automatici, zero configurazione, zero lavoro per l'operatore.
///
/// Voce italiana di sistema, scelta fra quelle installate preferendo le
/// piu' naturali. Disattivabile dalle impostazioni (pref
/// 'annunci_vocali_driver', default ATTIVO).
class TtsService {
  TtsService._();
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;

  static const String _chiavePrefs = 'annunci_vocali_driver';
  static const String _chiaveVoce = 'voce_driver';

  /// ATTENZIONE alla scala: su Android flutter_tts moltiplica per 2 il
  /// valore prima di passarlo al sistema, e per Android 1.0 = ritmo
  /// normale. Quindi 0.5 = ritmo NORMALE, non meta' velocita'.
  ///
  /// Non e' regolabile dall'utente: il ritmo naturale e' uno solo, e tre
  /// scelte in impostazioni erano solo rumore.
  static const double velocitaNormale = 0.5;

  final FlutterTts _tts = FlutterTts();
  bool _inizializzato = false;
  bool _abilitato = true;
  String? _nomeVoce;
  List<Map<String, String>> _vociItaliane = const [];

  bool get abilitato => _abilitato;
  String? get nomeVoce => _nomeVoce;
  List<Map<String, String>> get vociItaliane => _vociItaliane;

  Future<void> init() async {
    if (_inizializzato) return;
    _inizializzato = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _abilitato = prefs.getBool(_chiavePrefs) ?? true;
      _nomeVoce = prefs.getString(_chiaveVoce);
    } catch (_) {
      _abilitato = true;
    }
    try {
      await _tts.setLanguage('it-IT');
      await _tts.setSpeechRate(velocitaNormale);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      // In coda, non a taglio: due eventi ravvicinati si sentono entrambi
      await _tts.awaitSpeakCompletion(false);
      await _caricaVoci();
    } catch (_) {/* motore TTS assente: annunci silenziosi, app intatta */}
  }

  /// Elenca le voci italiane installate e applica la migliore disponibile.
  ///
  /// Google Speech Services pubblica per ogni lingua varianti "-network"
  /// (sintesi neurale lato server, molto piu' umana) e "-local" (sintesi
  /// sul telefono, piatta). Se il telefono ha le network, si usano quelle:
  /// senza rete il sistema ripiega da solo sulla locale.
  Future<void> _caricaVoci() async {
    try {
      final grezze = await _tts.getVoices;
      if (grezze is! List) return;

      final trovate = <Map<String, String>>[];
      for (final v in grezze) {
        if (v is! Map) continue;
        final nome = v['name']?.toString() ?? '';
        final locale = v['locale']?.toString() ?? '';
        if (nome.isEmpty) continue;
        if (!locale.toLowerCase().startsWith('it')) continue;
        trovate.add({'name': nome, 'locale': locale});
      }
      if (trovate.isEmpty) return;

      // Migliori prima: neurale/network in cima, locale in fondo.
      int punteggio(Map<String, String> v) {
        final n = v['name']!.toLowerCase();
        if (n.contains('network')) return 0;
        if (n.contains('neural') || n.contains('wavenet')) return 1;
        if (n.contains('local')) return 3;
        return 2;
      }

      trovate.sort((a, b) => punteggio(a).compareTo(punteggio(b)));
      _vociItaliane = trovate;

      final scelta = _nomeVoce == null
          ? trovate.first
          : trovate.firstWhere(
              (v) => v['name'] == _nomeVoce,
              orElse: () => trovate.first,
            );
      await _applicaVoce(scelta);
    } catch (_) {/* elenco voci non disponibile: resta quella di sistema */}
  }

  Future<void> _applicaVoce(Map<String, String> voce) async {
    try {
      await _tts.setVoice(voce);
      _nomeVoce = voce['name'];
    } catch (_) {}
  }

  Future<void> impostaAbilitato(bool valore) async {
    _abilitato = valore;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chiavePrefs, valore);
    } catch (_) {}
    if (!valore) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }


  Future<void> impostaVoce(Map<String, String> voce) async {
    await _applicaVoce(voce);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chiaveVoce, voce['name'] ?? '');
    } catch (_) {}
  }

  /// "19:30 - 20:00" -> "19 e 30": letto cosi' suona come lo direbbe una
  /// persona. Passando la stringa grezza il motore legge anche il trattino
  /// e la seconda ora, con una pausa fuori posto in mezzo.
  static String fasciaParlata(String fascia) {
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(fascia);
    if (m == null) return fascia;
    final ore = int.parse(m.group(1)!);
    final minuti = int.parse(m.group(2)!);
    return minuti == 0 ? '$ore' : '$ore e $minuti';
  }

  /// Pronuncia [testo] se gli annunci sono attivi. Mai un crash da qui:
  /// la voce e' un aiuto, non una dipendenza.
  Future<void> annuncia(String testo) async {
    if (!_abilitato) return;
    await init();
    try {
      await _tts.speak(testo);
    } catch (_) {}
  }

  /// Prova voce: parla anche con gli annunci spenti (serve a scegliere).
  Future<void> prova(String testo) async {
    await init();
    try {
      await _tts.stop();
      await _tts.speak(testo);
    } catch (_) {}
  }

  /// Zittisce subito (es. chiusura della navigazione a meta' frase).
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
