import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../services/nominatim_service.dart';
import '../models/address_model.dart';

/// Provider per gestire lo stato globale della posizione utente
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final NominatimService _nominatimService = NominatimService();

  // Stato posizione corrente
  double? _currentLatitude;
  double? _currentLongitude;
  String? _currentAddress;
  String? _currentCity;
  String? _currentPostalCode;
  bool _isLoadingLocation = false;
  String? _locationError;

  // Indirizzo selezionato (può essere posizione corrente o salvato)
  AddressModel? _selectedAddress;
  bool _isUsingCurrentPosition = true;

  // Flag primo avvio
  bool _isFirstLaunch = true;
  bool _hasRequestedPermission = false;

  // Tipo di ordine: 'delivery' o 'pickup'.
  // PERSISTITO: il cliente sceglie una volta, non a ogni avvio.
  // Il full-screen di scelta compare solo finche' order_type_selected
  // non e' mai stato salvato (primo avvio assoluto).
  String _orderType = 'delivery';
  bool _hasSelectedOrderType = false;

  static const String _keyOrderType = 'order_type';
  static const String _keyOrderTypeSelected = 'order_type_selected';
  static const String _keySelectedAddressJson = 'selected_address_json';

  // Getters
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  String? get currentAddress => _currentAddress;
  String? get currentCity => _currentCity;
  String? get currentPostalCode => _currentPostalCode;
  bool get isLoadingLocation => _isLoadingLocation;
  String? get locationError => _locationError;
  AddressModel? get selectedAddress => _selectedAddress;
  bool get isUsingCurrentPosition => _isUsingCurrentPosition;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get hasRequestedPermission => _hasRequestedPermission;
  String get orderType => _orderType;
  bool get hasSelectedOrderType => _hasSelectedOrderType;
  bool get isPickup => _orderType == 'pickup';
  bool get isDelivery => _orderType == 'delivery';

  /// Indirizzo da mostrare nell'UI (priorità: selezionato > corrente)
  String get displayAddress {
    if (!_isUsingCurrentPosition && _selectedAddress != null) {
      return _selectedAddress!.formattedAddress;
    }
    return _currentAddress ?? 'Posizione non disponibile';
  }

  /// Coordinate da usare per filtri/API (priorità: selezionate > correnti)
  double? get activeLatitude {
    if (!_isUsingCurrentPosition && _selectedAddress != null) {
      return _selectedAddress!.latitude;
    }
    return _currentLatitude;
  }

  double? get activeLongitude {
    if (!_isUsingCurrentPosition && _selectedAddress != null) {
      return _selectedAddress!.longitude;
    }
    return _currentLongitude;
  }

  String? get activePostalCode {
    if (!_isUsingCurrentPosition && _selectedAddress != null) {
      return _selectedAddress!.postalCode;
    }
    return _currentPostalCode;
  }

  /// Inizializza il provider (chiamato al primo avvio app)
  Future<void> initialize() async {
    debugPrint('🎯 [LOCATION PROVIDER] Inizializzazione...');

    // Controlla se è primo avvio
    final prefs = await SharedPreferences.getInstance();
    _isFirstLaunch = prefs.getBool('first_launch') ?? true;
    _hasRequestedPermission =
        prefs.getBool('gps_permission_requested') ?? false;

    debugPrint('🎯 [LOCATION PROVIDER] Primo avvio: $_isFirstLaunch');
    debugPrint(
      '🎯 [LOCATION PROVIDER] Permesso già richiesto: $_hasRequestedPermission',
    );

    // Se non è primo avvio, prova a caricare ultima posizione salvata
    if (!_isFirstLaunch) {
      await _loadLastKnownPosition();
    }

    // Ripristina la scelta consegna/ritiro dell'ultima sessione:
    // se esiste, il full-screen di scelta non viene piu' mostrato.
    _hasSelectedOrderType = prefs.getBool(_keyOrderTypeSelected) ?? false;
    if (_hasSelectedOrderType) {
      _orderType = prefs.getString(_keyOrderType) ?? 'delivery';

      // Ripristina anche l'eventuale indirizzo salvato selezionato
      final addressJson = prefs.getString(_keySelectedAddressJson);
      if (addressJson != null && addressJson.isNotEmpty) {
        try {
          _selectedAddress = AddressModel.fromJson(
            jsonDecode(addressJson) as Map<String, dynamic>,
          );
          _isUsingCurrentPosition = false;
        } catch (e) {
          debugPrint('⚠️ [LOCATION PROVIDER] Indirizzo salvato corrotto: $e');
        }
      }
      debugPrint(
        '✅ [LOCATION PROVIDER] Tipo ordine ripristinato: $_orderType '
        '(indirizzo salvato: ${_selectedAddress != null})',
      );
    }

    notifyListeners();

    // La posizione salvata e' solo il punto di partenza: e' dove l'utente ERA
    // l'ultima volta che il GPS ha parlato, non dove si trova adesso. Chi apre
    // l'app in ufficio dopo averla usata a casa si vedeva "ti trovi qui: casa"
    // per sempre, e distanze, filtri e assistente ragionavano sull'indirizzo
    // vecchio. Qui parte un fix silenzioso in sottofondo: la schermata mostra
    // subito il dato salvato e si aggiorna da sola quando il GPS risponde.
    //
    // Due guardie, entrambe deliberate:
    //  - solo a permesso GIA' concesso: il permesso si chiede nel dialogo del
    //    primo avvio, mai a sorpresa aprendo l'app;
    //  - solo se l'utente sta usando la posizione corrente: un indirizzo
    //    scelto a mano ("consegna a casa") e' una scelta, e il GPS non la
    //    scavalca.
    if (!_isFirstLaunch && _isUsingCurrentPosition) {
      final permesso = await _locationService.checkPermission();
      if (permesso == LocationPermission.always ||
          permesso == LocationPermission.whileInUse) {
        debugPrint('🔄 [LOCATION PROVIDER] Aggiorno la posizione in sottofondo');
        unawaited(requestCurrentPosition(showLoading: false));
      }
    }
  }

  /// Carica ultima posizione salvata da SharedPreferences
  Future<void> _loadLastKnownPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_latitude');
      final lng = prefs.getDouble('last_longitude');
      final address = prefs.getString('last_address');
      final city = prefs.getString('last_city');
      final postalCode = prefs.getString('last_postal_code');

      if (lat != null && lng != null && address != null) {
        _currentLatitude = lat;
        _currentLongitude = lng;
        _currentAddress = address;
        _currentCity = city;
        _currentPostalCode = postalCode;
        debugPrint('✅ [LOCATION PROVIDER] Ultima posizione caricata: $address');
        debugPrint('✅ [LOCATION PROVIDER] Città: $city, CAP: $postalCode');
      }
    } catch (e) {
      debugPrint(
        '⚠️ [LOCATION PROVIDER] Errore caricamento ultima posizione: $e',
      );
    }
  }

  /// Salva posizione corrente in SharedPreferences
  Future<void> _saveCurrentPosition() async {
    if (_currentLatitude != null &&
        _currentLongitude != null &&
        _currentAddress != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('last_latitude', _currentLatitude!);
        await prefs.setDouble('last_longitude', _currentLongitude!);
        await prefs.setString('last_address', _currentAddress!);
        if (_currentCity != null) {
          await prefs.setString('last_city', _currentCity!);
        }
        if (_currentPostalCode != null) {
          await prefs.setString('last_postal_code', _currentPostalCode!);
        }
        debugPrint(
          '💾 [LOCATION PROVIDER] Posizione salvata (CAP: $_currentPostalCode)',
        );
      } catch (e) {
        debugPrint('⚠️ [LOCATION PROVIDER] Errore salvataggio posizione: $e');
      }
    }
  }

  /// Richiede posizione corrente (con reverse geocoding)
  Future<bool> requestCurrentPosition({bool showLoading = true}) async {
    if (showLoading) {
      _isLoadingLocation = true;
      _locationError = null;
      notifyListeners();
    }

    try {
      debugPrint('📍 [LOCATION PROVIDER] Richiesta posizione GPS...');

      // Ottieni coordinate GPS
      final position = await _locationService.getCurrentPosition();
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;

      debugPrint(
        '✅ [LOCATION PROVIDER] GPS: ${position.latitude}, ${position.longitude}',
      );

      // Reverse geocoding per ottenere indirizzo leggibile
      debugPrint('🗺️ [LOCATION PROVIDER] Reverse geocoding...');
      final addressData = await _nominatimService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (addressData?.formattedAddress != null) {
        _currentAddress = addressData!.formattedAddress;
        _currentCity = addressData.city;
        _currentPostalCode = addressData.postcode;
        debugPrint('✅ [LOCATION PROVIDER] Indirizzo: $_currentAddress');
        debugPrint('✅ [LOCATION PROVIDER] Città: $_currentCity');
        debugPrint('✅ [LOCATION PROVIDER] CAP: $_currentPostalCode');
      } else {
        _currentAddress =
            'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
        _currentCity = null;
        _currentPostalCode = null;
        debugPrint(
          '⚠️ [LOCATION PROVIDER] Reverse geocoding fallito, uso coordinate',
        );
      }

      // Salva posizione per riutilizzo futuro
      await _saveCurrentPosition();

      // Marca come "posizione corrente" selezionata
      _isUsingCurrentPosition = true;
      _selectedAddress = null;

      _isLoadingLocation = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ [LOCATION PROVIDER] Errore: $e');
      _locationError = e.toString();
      _isLoadingLocation = false;
      notifyListeners();
      return false;
    }
  }

  /// Marca che il permesso GPS è stato richiesto (anche se negato)
  Future<void> markPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gps_permission_requested', true);
    await prefs.setBool('first_launch', false);
    _hasRequestedPermission = true;
    _isFirstLaunch = false;
    notifyListeners();
    debugPrint('✅ [LOCATION PROVIDER] Flag permesso GPS salvato');
  }

  /// Seleziona un indirizzo salvato (disabilita "posizione corrente").
  /// Persistito: al prossimo avvio si riparte da questo indirizzo.
  void selectAddress(AddressModel address) {
    _selectedAddress = address;
    _isUsingCurrentPosition = false;
    notifyListeners();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_keySelectedAddressJson, jsonEncode(address.toJson()));
    });
  }

  /// Torna a usare posizione corrente
  Future<void> useCurrentPosition() async {
    _isUsingCurrentPosition = true;
    _selectedAddress = null;
    notifyListeners();
    debugPrint('📍 [LOCATION PROVIDER] Uso posizione corrente');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedAddressJson);

    // Se non abbiamo coordinate, richiedi GPS
    if (_currentLatitude == null || _currentLongitude == null) {
      await requestCurrentPosition();
    }
  }

  /// Refresh posizione (per icona 🎯 nell'header)
  Future<void> refreshCurrentPosition() async {
    debugPrint('🔄 [LOCATION PROVIDER] Refresh posizione...');
    await requestCurrentPosition(showLoading: true);
  }

  /// Aggiorna l'indirizzo della posizione corrente (per correzioni manuali)
  void updateCurrentAddress(String newAddress) {
    _currentAddress = newAddress;
    notifyListeners();
    debugPrint('✏️ [LOCATION PROVIDER] Indirizzo aggiornato: $_currentAddress');
  }

  /// Imposta il tipo di ordine (pickup/delivery).
  /// PERSISTITO: la scelta sopravvive al riavvio, il full-screen di scelta
  /// non viene piu' riproposto. Si cambia dal badge in home.
  void setOrderType(String type) {
    _orderType = type;
    _hasSelectedOrderType = true;
    notifyListeners();
    debugPrint('🛒 [LOCATION PROVIDER] Tipo ordine: $type');

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_keyOrderType, type);
      prefs.setBool(_keyOrderTypeSelected, true);
    });
  }

  /// Reset selezione tipo ordine (anche dalla persistenza)
  Future<void> resetOrderTypeSelection() async {
    _hasSelectedOrderType = false;
    _orderType = 'delivery';
    notifyListeners();
    debugPrint('🔄 [LOCATION PROVIDER] Reset tipo ordine');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOrderType);
    await prefs.remove(_keyOrderTypeSelected);
    await prefs.remove(_keySelectedAddressJson);
  }

  /// Reset provider (logout). La scelta consegna/ritiro resta persistita
  /// (vale anche per l'ospite); l'indirizzo salvato invece e' legato
  /// all'account e va dimenticato.
  void reset() {
    _currentLatitude = null;
    _currentLongitude = null;
    _currentAddress = null;
    _selectedAddress = null;
    _isUsingCurrentPosition = true;
    _locationError = null;
    _isLoadingLocation = false;
    notifyListeners();
    debugPrint('🔄 [LOCATION PROVIDER] Reset completato');

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_keySelectedAddressJson);
    });
  }
}
