import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';

/// Provider per la gestione globale del carrello con persistenza locale
class CartProvider with ChangeNotifier {
  static const String _cartKey = 'cart_items';
  static const String _restaurantIdKey = 'cart_restaurant_id';
  static const String _restaurantNameKey = 'cart_restaurant_name';
  static const String _restaurantLogoKey = 'cart_restaurant_logo';
  static const String _cartTimestampKey = 'cart_timestamp';
  static const int _cartExpirationHours = 24;

  final List<CartItem> _items = [];
  int? _restaurantId;
  String? _restaurantName;
  String? _restaurantLogoUrl;
  bool _isLoaded = false;

  List<CartItem> get items => List.unmodifiable(_items);
  int? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  String? get restaurantLogoUrl => _restaurantLogoUrl;

  /// Conteggio totale degli item nel carrello
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Totale del carrello
  double get total => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Verifica se il carrello è vuoto
  bool get isEmpty => _items.isEmpty;

  /// Verifica se il carrello contiene items
  bool get isNotEmpty => _items.isNotEmpty;

  /// Carica il carrello da SharedPreferences
  Future<void> loadCart() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Verifica timestamp
      final timestamp = prefs.getInt(_cartTimestampKey);
      if (timestamp != null) {
        final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        final difference = now.difference(savedTime).inHours;

        // Se il carrello è più vecchio di 24h, lo svuota
        if (difference >= _cartExpirationHours) {
          await _clearSavedCart();
          _isLoaded = true;
          return;
        }
      }

      // Carica dati ristorante
      _restaurantId = prefs.getInt(_restaurantIdKey);
      _restaurantName = prefs.getString(_restaurantNameKey);
      _restaurantLogoUrl = prefs.getString(_restaurantLogoKey); // Carica items
      final cartJson = prefs.getString(_cartKey);
      if (cartJson != null) {
        final List<dynamic> itemsList = jsonDecode(cartJson);
        _items.clear();
        for (var itemData in itemsList) {
          try {
            _items.add(
              CartItem(
                menuItem: MenuItem.fromJson(itemData['menu_item']),
                quantity: itemData['quantity'] as int,
                customizations: List<String>.from(
                  itemData['customizations'] ?? [],
                ),
                customizationData: Map<String, dynamic>.from(
                  itemData['customization_data'] ?? {},
                ),
                customizationsPriceModifier:
                    (itemData['price_modifier'] as num?)?.toDouble() ?? 0.0,
              ),
            );
          } catch (e) {
            if (kDebugMode) print('⚠️ Errore caricamento item carrello: $e');
          }
        }
      }

      // Se dopo il caricamento il carrello è vuoto, resetta i dati del ristorante
      if (_items.isEmpty) {
        _restaurantId = null;
        _restaurantName = null;
        _restaurantLogoUrl = null;
        await _clearSavedCart();
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Errore caricamento carrello: $e');
      _isLoaded = true;
    }
  }

  /// Salva il carrello in SharedPreferences
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Se il carrello è vuoto, pulisci tutto
      if (_items.isEmpty) {
        await _clearSavedCart();
        return;
      }

      // Salva items
      final itemsList = _items
          .map(
            (item) => {
              'menu_item': item.menuItem.toJson(),
              'quantity': item.quantity,
              'customizations': item.customizations,
              'customization_data': item.customizationData,
              'price_modifier': item.customizationsPriceModifier,
            },
          )
          .toList();

      await prefs.setString(_cartKey, jsonEncode(itemsList));

      // Salva dati ristorante solo se presenti
      if (_restaurantId != null) {
        await prefs.setInt(_restaurantIdKey, _restaurantId!);
      }
      if (_restaurantName != null) {
        await prefs.setString(_restaurantNameKey, _restaurantName!);
      }
      if (_restaurantLogoUrl != null) {
        await prefs.setString(_restaurantLogoKey, _restaurantLogoUrl!);
      }

      await prefs.setInt(
        _cartTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Errore salvataggio carrello: $e');
    }
  }

  /// Svuota il carrello salvato
  Future<void> _clearSavedCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
    await prefs.remove(_restaurantIdKey);
    await prefs.remove(_restaurantNameKey);
    await prefs.remove(_restaurantLogoKey);
    await prefs.remove(_cartTimestampKey);
  }

  /// Aggiunge un item al carrello
  /// Se è da un ristorante diverso, mostra un errore
  void addItem({
    required MenuItem menuItem,
    required int restaurantId,
    required String restaurantName,
    String? restaurantLogoUrl,
    required int quantity,
    List<Map<String, dynamic>>? selectedExtras,
    String? notes,
  }) {
    // Verifica se il ristorante è diverso
    if (_restaurantId != null && _restaurantId != restaurantId) {
      throw Exception(
        'Non puoi ordinare da ristoranti diversi nello stesso carrello. '
        'Svuota il carrello prima di ordinare da un altro ristorante.',
      );
    }

    // Imposta il ristorante se è il primo item
    if (_restaurantId == null) {
      _restaurantId = restaurantId;
      _restaurantName = restaurantName;
      _restaurantLogoUrl = restaurantLogoUrl;
    }

    // Calcola il prezzo degli extra
    double extrasPrice = 0.0;
    List<String> customizationsList = [];

    if (selectedExtras != null && selectedExtras.isNotEmpty) {
      for (var extra in selectedExtras) {
        extrasPrice += (extra['price'] as double? ?? 0.0);
        customizationsList.add(extra['name'] as String? ?? '');
      }
    }

    // Aggiungi note alle customizzazioni se presenti
    if (notes != null && notes.isNotEmpty) {
      customizationsList.add('Note: $notes');
    }

    // Verifica se esiste già un item identico
    final existingIndex = _items.indexWhere(
      (item) =>
          item.menuItem.id == menuItem.id &&
          item.customizationsText == customizationsList.join(', '),
    );

    if (existingIndex >= 0) {
      // Incrementa la quantità dell'item esistente
      _items[existingIndex].quantity += quantity;
    } else {
      // Aggiungi nuovo item
      _items.add(
        CartItem(
          menuItem: menuItem,
          quantity: quantity,
          customizations: customizationsList,
          customizationData: {'extras': selectedExtras ?? [], 'notes': notes},
          customizationsPriceModifier: extrasPrice,
        ),
      );
    }

    _saveCart();
    notifyListeners();
  }

  /// Rimuove un item dal carrello
  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);

      // Se il carrello è vuoto, resetta il ristorante
      if (_items.isEmpty) {
        _restaurantId = null;
        _restaurantName = null;
        _restaurantLogoUrl = null;
      }

      _saveCart();
      notifyListeners();
    }
  }

  /// Aggiorna la quantità di un item
  void updateQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _items.length) {
      if (newQuantity <= 0) {
        removeItem(index);
      } else {
        _items[index].quantity = newQuantity;
        _saveCart();
        notifyListeners();
      }
    }
  }

  /// Aggiorna completamente un item esistente nel carrello
  void updateItem({
    required int index,
    required int quantity,
    required List<String> customizations,
    required Map<String, dynamic> customizationData,
    required double customizationsPriceModifier,
  }) {
    if (index >= 0 && index < _items.length) {
      _items[index].quantity = quantity;
      _items[index].customizations = customizations;
      _items[index].customizationData = customizationData;
      // Note: customizationsPriceModifier is final, so we need to replace the item
      final updatedItem = CartItem(
        menuItem: _items[index].menuItem,
        quantity: quantity,
        customizations: customizations,
        customizationData: customizationData,
        customizationsPriceModifier: customizationsPriceModifier,
      );
      _items[index] = updatedItem;
      _saveCart();
      notifyListeners();
    }
  }

  /// Incrementa la quantità di un item
  void incrementQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index].quantity++;
      _saveCart();
      notifyListeners();
    }
  }

  /// Decrementa la quantità di un item
  void decrementQuantity(int index) {
    if (index >= 0 && index < _items.length) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
        _saveCart();
        notifyListeners();
      } else {
        removeItem(index);
      }
    }
  }

  /// Svuota completamente il carrello
  Future<void> clearCart() async {
    _items.clear();
    _restaurantId = null;
    _restaurantName = null;
    _restaurantLogoUrl = null;
    await _clearSavedCart();
    notifyListeners();
  }

  /// Debug: stampa contenuto carrello
  void debugPrintCart() {
    if (kDebugMode) {
      print('🛒 CARRELLO ($itemCount items, €${total.toStringAsFixed(2)})');
      print('   Ristorante: $_restaurantName (#$_restaurantId)');
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        print(
          '   [$i] ${item.menuItem.name} x${item.quantity} = €${item.totalPrice.toStringAsFixed(2)}',
        );
        if (item.customizations.isNotEmpty) {
          print('       Extra: ${item.customizationsText}');
        }
      }
    }
  }
}
