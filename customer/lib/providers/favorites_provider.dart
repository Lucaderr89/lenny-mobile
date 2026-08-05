import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';
import '../models/favorite.dart';
import '../services/favorites_service.dart';

/// Provider per la gestione globale dei preferiti
class FavoritesProvider with ChangeNotifier {
  final FavoritesService _service = FavoritesService();

  List<FavoriteGroup> _favoriteGroups = [];
  final Map<String, bool> _favoriteStatus =
      {}; // Cache: "restaurant_11" => true
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;

  /// Lista preferiti raggruppati per ristorante
  List<FavoriteGroup> get favoriteGroups => List.unmodifiable(_favoriteGroups);

  /// Verifica se i dati sono in caricamento
  bool get isLoading => _isLoading;

  /// Verifica se i dati sono stati caricati almeno una volta
  bool get isLoaded => _isLoaded;

  /// Messaggio di errore (se presente)
  String? get error => _error;

  /// Numero totale di preferiti (ristoranti + piatti)
  int get totalCount {
    int count = 0;
    for (var group in _favoriteGroups) {
      if (group.isRestaurantFavorite) count++;
      count += group.favoriteDishes.length;
    }
    return count;
  }

  /// Numero ristoranti preferiti
  int get restaurantsCount =>
      _favoriteGroups.where((g) => g.isRestaurantFavorite).length;

  /// Numero piatti preferiti
  int get dishesCount =>
      _favoriteGroups.fold(0, (sum, g) => sum + g.favoriteDishes.length);

  /// Verifica se la lista è vuota
  bool get isEmpty => _favoriteGroups.isEmpty && totalCount == 0;

  /// Carica i preferiti dal server
  Future<void> loadFavorites({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_isLoaded && !forceRefresh) return;

    // Un ospite non ha preferiti: senza account la chiamata fallirebbe e
    // lascerebbe un errore in memoria senza motivo.
    if (!await AuthService().isLoggedIn()) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final favorites = await _service.getFavorites();
      _favoriteGroups = favorites;
      _isLoaded = true;

      // Aggiorna cache stato preferiti
      _rebuildCache();

      print(
        '✅ [PROVIDER] Preferiti caricati: ${_favoriteGroups.length} gruppi',
      );
    } catch (e) {
      _error = 'Errore nel caricamento dei preferiti';
      print('❌ [PROVIDER] Errore caricamento: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Aggiunge un elemento ai preferiti
  ///
  /// [type] - 'restaurant' o 'dish'
  /// [id] - ID del ristorante o piatto
  Future<bool> addFavorite(String type, int id) async {
    try {
      print('➕ [PROVIDER] Add $type #$id');

      final success = await _service.addFavorite(type, id);

      if (success) {
        // Aggiorna cache locale
        _favoriteStatus['${type}_$id'] = true;

        // Ricarica lista completa per avere dati aggiornati
        await loadFavorites(forceRefresh: true);

        print('✅ [PROVIDER] Preferito aggiunto');
        return true;
      } else {
        print('⚠️ [PROVIDER] Add fallito');
        return false;
      }
    } catch (e) {
      print('❌ [PROVIDER] Errore add: $e');
      return false;
    }
  }

  /// Rimuove un elemento dai preferiti
  ///
  /// [type] - 'restaurant' o 'dish'
  /// [id] - ID del ristorante o piatto
  Future<bool> removeFavorite(String type, int id) async {
    try {
      print('➖ [PROVIDER] Remove $type #$id');

      final success = await _service.removeFavorite(type, id);

      if (success) {
        // Aggiorna cache locale
        _favoriteStatus['${type}_$id'] = false;

        // Ricarica lista completa
        await loadFavorites(forceRefresh: true);

        print('✅ [PROVIDER] Preferito rimosso');
        return true;
      } else {
        print('⚠️ [PROVIDER] Remove fallito');
        return false;
      }
    } catch (e) {
      print('❌ [PROVIDER] Errore remove: $e');
      return false;
    }
  }

  /// Toggle preferito (aggiunge se non c'è, rimuove se c'è)
  ///
  /// [type] - 'restaurant' o 'dish'
  /// [id] - ID del ristorante o piatto
  Future<bool> toggleFavorite(String type, int id) async {
    final isFav = isFavorite(type, id);

    if (isFav) {
      return await removeFavorite(type, id);
    } else {
      return await addFavorite(type, id);
    }
  }

  /// Verifica se un elemento è nei preferiti (da cache locale)
  ///
  /// [type] - 'restaurant' o 'dish'
  /// [id] - ID del ristorante o piatto
  bool isFavorite(String type, int id) {
    return _favoriteStatus['${type}_$id'] ?? false;
  }

  /// Ricostruisce la cache dello stato preferiti dalla lista caricata
  void _rebuildCache() {
    _favoriteStatus.clear();

    for (var group in _favoriteGroups) {
      // Ristorante
      if (group.isRestaurantFavorite) {
        _favoriteStatus['restaurant_${group.restaurant.id}'] = true;
      }

      // Piatti
      for (var dish in group.favoriteDishes) {
        _favoriteStatus['dish_${dish.id}'] = true;
      }
    }

    print('🔄 [PROVIDER] Cache aggiornata: ${_favoriteStatus.length} items');
  }

  /// Resetta il provider (es. al logout)
  void reset() {
    _favoriteGroups = [];
    _favoriteStatus.clear();
    _isLoading = false;
    _isLoaded = false;
    _error = null;
    notifyListeners();
  }
}
