import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Annunci vocali della Modalita' Guida: il telefono PARLA invece di
/// farsi guardare. Solo eventi dell'app (nuovo ordine, cambio tappa,
/// revoca): automatici, zero configurazione, zero lavoro per l'operatore.
///
/// Voce italiana di sistema. Disattivabile dalle impostazioni
/// (pref 'annunci_vocali_driver', default ATTIVO).
class TtsService {
  TtsService._();
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;

  static const String _chiavePrefs = 'annunci_vocali_driver';

  final FlutterTts _tts = FlutterTts();
  bool _inizializzato = false;
  bool _abilitato = true;

  bool get abilitato => _abilitato;

  Future<void> init() async {
    if (_inizializzato) return;
    _inizializzato = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _abilitato = prefs.getBool(_chiavePrefs) ?? true;
    } catch (_) {
      _abilitato = true;
    }
    try {
      await _tts.setLanguage('it-IT');
      // Voce LENTA e scandita: in strada, con casco e rumore, la velocita'
      // standard risultava incomprensibile.
      await _tts.setSpeechRate(0.38);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      // In coda, non a taglio: due eventi ravvicinati si sentono entrambi
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {/* motore TTS assente: annunci silenziosi, app intatta */}
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

  /// Pronuncia [testo] se gli annunci sono attivi. Mai un crash da qui:
  /// la voce e' un aiuto, non una dipendenza.
  Future<void> annuncia(String testo) async {
    if (!_abilitato) return;
    await init();
    try {
      await _tts.speak(testo);
    } catch (_) {}
  }
}
