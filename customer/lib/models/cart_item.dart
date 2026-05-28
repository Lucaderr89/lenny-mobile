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
