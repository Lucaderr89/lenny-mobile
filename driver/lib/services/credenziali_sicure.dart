import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Archivio cifrato per la password del driver.
///
/// La password serve solo all'auto-login nella WebView del pannello. Prima
/// finiva in SharedPreferences, cioe' in un file XML in chiaro dentro la
/// cartella privata dell'app: protetto dal sandbox di Android, ma leggibile
/// su un dispositivo con accesso root. Qui invece passa da
/// EncryptedSharedPreferences, con la chiave custodita nel Keystore.
class CredenzialiSicure {
  static const _chiave = 'driver_password';
  static const _chiaveVecchia = 'driver_password';

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

  /// Legge la password, migrando quella eventualmente rimasta in chiaro dalle
  /// versioni precedenti e cancellandola dalle preferenze.
  static Future<String?> leggiPassword() async {
    try {
      final cifrata = await _archivio.read(key: _chiave);
      if (cifrata != null && cifrata.isNotEmpty) return cifrata;

      final prefs = await SharedPreferences.getInstance();
      final inChiaro = prefs.getString(_chiaveVecchia);
      if (inChiaro != null && inChiaro.isNotEmpty) {
        await _archivio.write(key: _chiave, value: inChiaro);
        await prefs.remove(_chiaveVecchia);
        return inChiaro;
      }
    } catch (e) {
      debugPrint('Impossibile leggere la password: $e');
    }
    return null;
  }

  /// Cancella la password sia dall'archivio cifrato sia da eventuali residui
  /// in chiaro. Da chiamare al logout.
  static Future<void> cancella() async {
    try {
      await _archivio.delete(key: _chiave);
    } catch (e) {
      debugPrint('Impossibile cancellare la password cifrata: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chiaveVecchia);
  }
}
