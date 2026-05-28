import 'package:flutter/foundation.dart';
import '../models/availability_data.dart';
import '../services/availability_service.dart';

/// Provider per gestire lo stato di disponibilità
///
/// Fornisce:
/// - Caricamento dati disponibilità
/// - Caching dei dati
/// - Verifica disponibilità piatti
/// - Notifiche agli observer
class AvailabilityProvider extends ChangeNotifier {
  final AvailabilityService _service = AvailabilityService();

  // Stato
  AvailabilityData? _availabilityData;
  bool _isLoading = false;
  String? _error;
  String? _currentDate;
  int? _currentRestaurantId;

  // Getters
  AvailabilityData? get availabilityData => _availabilityData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _availabilityData != null;

  /// Carica la disponibilità per una data e ristorante specifici
  Future<bool> loadAvailability({
    required String date,
    required int restaurantId,
    bool includeCategories = true,
    bool includeDishes = true,
    int? categoryId,
    int? dishId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _currentDate = date;
      _currentRestaurantId = restaurantId;
      notifyListeners();

      final data = await _service.getAvailability(
        date: date,
        restaurantId: restaurantId,
        includeCategories: includeCategories,
        includeDishes: includeDishes,
        categoryId: categoryId,
        dishId: dishId,
      );

      if (data == null) {
        _error = 'Impossibile caricare i dati di disponibilità';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _availabilityData = data;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Errore durante il caricamento: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verifica se un piatto è disponibile
  Future<bool> isDishAvailable(int dishId) async {
    if (_currentDate == null || _currentRestaurantId == null) {
      return false;
    }

    return await _service.isDishAvailable(
      date: _currentDate!,
      restaurantId: _currentRestaurantId!,
      dishId: dishId,
    );
  }

  /// Recupera il motivo di indisponibilità di un piatto
  Future<String?> getDishUnavailabilityReason(int dishId) async {
    if (_currentDate == null || _currentRestaurantId == null) {
      return null;
    }

    return await _service.getDishUnavailabilityReason(
      date: _currentDate!,
      restaurantId: _currentRestaurantId!,
      dishId: dishId,
    );
  }

  /// Verifica se il ristorante è aperto
  bool get isRestaurantOpen {
    if (_availabilityData == null) return false;
    return _availabilityData!.restaurant.isOpen;
  }

  /// Ottiene il prossimo slot disponibile
  TimeSlot? get nextAvailableSlot {
    if (_availabilityData == null) return null;
    return _availabilityData!.restaurant.getNextAvailableSlot();
  }

  /// Verifica se un piatto è disponibile localmente (da dati in cache)
  /// Questo è utile per verifiche rapide senza nuova richiesta API
  bool isDishAvailableLocally(int dishId) {
    if (_availabilityData == null) return false;
    return _availabilityData!.isDishAvailable(dishId);
  }

  /// Recupera il piatto per ID (da dati in cache)
  DishAvailability? getDishData(int dishId) {
    if (_availabilityData == null) return null;
    return _availabilityData!.getDishById(dishId);
  }

  /// Verifica disponibilità di una lista di piatti
  Future<Map<int, bool>> checkDishesAvailability(List<int> dishIds) async {
    if (_currentDate == null || _currentRestaurantId == null) {
      return {for (var id in dishIds) id: false};
    }

    return await _service.checkDishesAvailability(
      date: _currentDate!,
      restaurantId: _currentRestaurantId!,
      dishIds: dishIds,
    );
  }

  /// Azzera lo stato
  void reset() {
    _availabilityData = null;
    _isLoading = false;
    _error = null;
    _currentDate = null;
    _currentRestaurantId = null;
    notifyListeners();
  }

  /// Forza il ricaricamento
  Future<bool> refresh() async {
    if (_currentDate == null || _currentRestaurantId == null) {
      return false;
    }

    return await loadAvailability(
      date: _currentDate!,
      restaurantId: _currentRestaurantId!,
    );
  }
}
