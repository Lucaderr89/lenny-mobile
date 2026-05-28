import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/address_model.dart';

/// Servizio per gestire gli indirizzi di consegna del cliente
class AddressService {
  final String baseUrl = AppConstants.apiUrl;

  /// Headers comuni con API token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken) ?? '';

    print('🔐 [ADDRESS] API Token presente: ${apiToken.isNotEmpty}');
    if (apiToken.isNotEmpty) {
      print(
        '🔐 [ADDRESS] Token (primi 15): ${apiToken.substring(0, apiToken.length > 15 ? 15 : apiToken.length)}...',
      );
    } else {
      print('❌ [ADDRESS] TOKEN VUOTO! Utente non autenticato!');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': apiToken, // Header custom - più affidabile
    };

    print('📤 [ADDRESS] Headers inviati: ${headers.keys.join(", ")}');

    return headers;
  }

  /// Recupera tutti gli indirizzi del cliente
  Future<List<AddressModel>> getAddresses() async {
    try {
      print('🏠 [ADDRESS] Recupero indirizzi...');

      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/customer/addresses'), headers: headers)
          .timeout(const Duration(seconds: 10));

      print('📡 [ADDRESS] Status: ${response.statusCode}');
      print('📄 [ADDRESS] Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final addressesJson = (jsonResponse['data'] as List?) ?? [];

        final addresses = addressesJson
            .map((json) => AddressModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ [ADDRESS] ${addresses.length} indirizzi recuperati');
        return addresses;
      } else {
        print('❌ [ADDRESS] Errore: ${response.statusCode}');
        throw Exception('Errore nel recupero degli indirizzi');
      }
    } catch (e) {
      print('❌ [ADDRESS] Eccezione: $e');
      rethrow;
    }
  }

  /// Aggiunge un nuovo indirizzo
  Future<AddressModel> addAddress(AddressModel address) async {
    try {
      print('➕ [ADDRESS] Aggiunta nuovo indirizzo...');

      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/customer/addresses/add'),
            headers: headers,
            body: jsonEncode(address.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [ADDRESS] Status: ${response.statusCode}');
      print('📄 [ADDRESS] Response: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final addressIdRaw = jsonResponse['data']['address_id'];
        final addressId = addressIdRaw is String
            ? int.tryParse(addressIdRaw)
            : addressIdRaw as int?;

        print('✅ [ADDRESS] Indirizzo aggiunto con ID: $addressId');

        // Ritorna l'indirizzo con ID aggiornato
        return address.copyWith(id: addressId);
      } else {
        print('❌ [ADDRESS] Errore: ${response.statusCode}');
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
          jsonResponse['error']?['message'] ??
              'Errore nell\'aggiunta dell\'indirizzo',
        );
      }
    } catch (e) {
      print('❌ [ADDRESS] Eccezione: $e');
      rethrow;
    }
  }

  /// Aggiorna un indirizzo esistente
  Future<void> updateAddress(AddressModel address) async {
    if (address.id == null) {
      throw Exception('ID indirizzo mancante');
    }

    try {
      print('🔄 [ADDRESS] Aggiornamento indirizzo ID: ${address.id}...');

      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/customer/addresses/update?id=${address.id}'),
            headers: headers,
            body: jsonEncode(address.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [ADDRESS] Status: ${response.statusCode}');
      print('📄 [ADDRESS] Response: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ [ADDRESS] Indirizzo aggiornato');
      } else {
        print('❌ [ADDRESS] Errore: ${response.statusCode}');
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
          jsonResponse['error']?['message'] ??
              'Errore nell\'aggiornamento dell\'indirizzo',
        );
      }
    } catch (e) {
      print('❌ [ADDRESS] Eccezione: $e');
      rethrow;
    }
  }

  /// Elimina un indirizzo
  Future<void> deleteAddress(int addressId) async {
    try {
      print('🗑️ [ADDRESS] Eliminazione indirizzo ID: $addressId...');

      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/customer/addresses/delete'),
            headers: headers,
            body: jsonEncode({'address_id': addressId}),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [ADDRESS] Status: ${response.statusCode}');
      print('📄 [ADDRESS] Response: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ [ADDRESS] Indirizzo eliminato');
      } else {
        print('❌ [ADDRESS] Errore: ${response.statusCode}');
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
          jsonResponse['error']?['message'] ??
              'Errore nell\'eliminazione dell\'indirizzo',
        );
      }
    } catch (e) {
      print('❌ [ADDRESS] Eccezione: $e');
      rethrow;
    }
  }

  /// Imposta un indirizzo come predefinito
  Future<void> setDefaultAddress(int addressId) async {
    try {
      print(
        '⭐ [ADDRESS] Impostazione indirizzo $addressId come predefinito...',
      );

      // Backend: aggiorna is_default=1 per questo indirizzo
      // Gli altri vengono automaticamente settati a 0 dal backend
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/customer/addresses/update?id=$addressId'),
            headers: headers,
            body: jsonEncode({'is_default': 1}),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 [ADDRESS] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ [ADDRESS] Indirizzo predefinito aggiornato');
      } else {
        print('❌ [ADDRESS] Errore: ${response.statusCode}');
        print('📋 [ADDRESS] Response: ${response.body}');
        throw Exception(
          'Errore nell\'impostazione dell\'indirizzo predefinito',
        );
      }
    } catch (e) {
      print('❌ [ADDRESS] Eccezione: $e');
      rethrow;
    }
  }

  /// Ottiene l'indirizzo predefinito del cliente
  Future<AddressModel?> getDefaultAddress() async {
    try {
      final addresses = await getAddresses();
      return addresses.firstWhere(
        (addr) => addr.isDefault,
        orElse: () => addresses.isNotEmpty
            ? addresses.first
            : throw Exception('Nessun indirizzo'),
      );
    } catch (e) {
      print('⚠️ [ADDRESS] Nessun indirizzo predefinito: $e');
      return null;
    }
  }
}
