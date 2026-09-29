import 'menu_item.dart';

/// Modello per un articolo nel carrello
class CartItem {
  final MenuItem menuItem;
  int quantity;
  List<String> customizations;
  Map<String, dynamic> customizationData;
  final double
  customizationsPriceModifier; // Prezzo aggiuntivo dalle customizzazioni

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    List<String>? customizations,
    Map<String, dynamic>? customizationData,
    this.customizationsPriceModifier = 0.0,
  }) : customizations = customizations ?? [],
       customizationData = customizationData ?? {};

  double get totalPrice =>
      (menuItem.price + customizationsPriceModifier) * quantity;

  double get unitPrice => menuItem.price + customizationsPriceModifier;

  String get customizationsText {
    if (customizations.isEmpty) return '';
    return customizations.join(', ');
  }

  /// Riga nel formato delle API (preventivo e creazione ordine). Le scelte
  /// sono quelle salvate da [scelteDallaScheda]: {id, name, price}.
  Map<String, dynamic> perApi() {
    final extras = <Map<String, dynamic>>[];
    final extrasData = customizationData['extras'];
    if (extrasData is List) {
      for (final extra in extrasData) {
        if (extra is Map) {
          final extraMap = Map<String, dynamic>.from(extra);
          extras.add({
            'extra_id': extraMap['id'] ?? 0,
            'price': (extraMap['price'] as num?)?.toDouble() ?? 0.0,
          });
        }
      }
    }

    return {
      'food_id': menuItem.id,
      'quantity': quantity,
      'price': menuItem.price,
      'discount_amount': 0.0,
      'extras': extras,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_item': menuItem.id,
      'quantity': quantity,
      'customizations': customizations,
      'customization_data': customizationData,
      'total_price': totalPrice,
    };
  }
}

/// Scelte fatte nella scheda del piatto, dal formato della scheda
/// ({'options': {gruppo: opzione}, 'extras': [id opzione], 'instructions': ...})
/// a quello del carrello e delle API: una lista di {id, name, price}.
///
/// Devono entrarci SIA le opzioni a scelta singola (taglia, numero di pezzi,
/// peso...) SIA gli extra multi-selezione: entrambe hanno un prezzo e vanno
/// addebitate, ed entrambe servono al ristorante per sapere cosa preparare.
/// Un solo punto per tutte le schermate che aggiungono o modificano un
/// piatto: quando ognuna aveva la sua copia, "Modifica" dal carrello e la
/// chat salvavano le scelte in un altro formato e l'ordine partiva senza.
List<Map<String, dynamic>> scelteDallaScheda(
  MenuItem item,
  Map<String, dynamic> customizations,
) {
  final scelte = <Map<String, dynamic>>[];

  bool aggiungi(CustomizationGroup group, String optionId) {
    for (final option in group.options) {
      if (option.id == optionId) {
        scelte.add({
          'id': option.id,
          'name': option.label,
          'price': option.priceModifier,
        });
        return true;
      }
    }
    return false;
  }

  // Scelte singole: mappa {groupId: optionId}
  final singole = customizations['options'];
  if (singole is Map) {
    singole.forEach((groupId, optionId) {
      for (final group in item.customizations) {
        if (group.id == groupId.toString()) {
          aggiungi(group, optionId.toString());
          break;
        }
      }
    });
  }

  // Extra multi-selezione: lista di optionId
  final extra = customizations['extras'];
  if (extra is List) {
    for (final extraId in extra) {
      for (final group in item.customizations) {
        if (!group.isMultiSelect) continue;
        if (aggiungi(group, extraId.toString())) break;
      }
    }
  }

  return scelte;
}

/// Modello per i dati del carrello
class Cart {
  final List<CartItem> items;

  Cart({this.items = const []});

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee => 2.99;

  double get tax => subtotal * 0.1;

  double get total => subtotal + deliveryFee + tax;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;
}
