import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Archivio cifrato per la password del ristorante.
///
/// La password serve solo all'autologin nella WebView del pannello platform
/// (stesso meccanismo dell'app driver): non deve mai finire in
/// SharedPreferences in chiaro. Qui passa da EncryptedSharedPreferences,
/// con la chiave custodita nel Keystore di Android.
class CredenzialiSicure {
  static const _chiave = 'partner_password';

  static const FlutterSecureStorage _archivio = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> salvaPassword(String password) async {
    try {
      await _archivio.write(key: _chiave, value: password);
    } catch (e) {
      debugPrint('Impossibile salvare la password in archivio cifrato: $e');
    }
  }

  static Future<String?> leggiPassword() async {
    try {
      return await _archivio.read(key: _chiave);
    } catch (e) {
      debugPrint('Impossibile leggere la password: $e');
      return null;
    }
  }

  /// Da chiamare al logout: la password non deve sopravvivere alla sessione.
  static Future<void> cancella() async {
    try {
      await _archivio.delete(key: _chiave);
    } catch (e) {
      debugPrint('Impossibile cancellare la password cifrata: $e');
    }
  }
}
