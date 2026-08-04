import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/restaurant.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../providers/cart_provider.dart';
import 'product_detail_modal.dart';
import 'checkout_screen.dart';
import 'package:flutter/foundation.dart';

/// Cart Screen - Basato sul prototipo 8-carrello.html
class CartScreen extends StatefulWidget {
  final Restaurant restaurant;
  final List<CartItem> cartItems;

  const CartScreen({
    super.key,
    required this.restaurant,
    required this.cartItems,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<CartItem> _cartItems;
  List<int> _recommendedItemIds = [];
  List<int> _forgottenItemIds = [];
  bool _suggestionsLoading = true;

  // Colori identici al prototipo
  static const Color primaryColor = AppColors.primary;
  static const Color successColor = AppColors.success;
  static const Color dangerColor = AppColors.danger;
  static const Color darkColor = AppColors.dark;
  static const Color lightColor = AppColors.light;
  static const Color grayColor = AppColors.gray;
  static const Color lightGrayColor = AppColors.lightGray;

  // URL base API
  // HTTPS obbligatorio: in chiaro il traffico e' leggibile e modificabile
  // da chiunque sia sulla stessa rete.
  static const String apiBaseUrl = 'https://lenny-staging.com/api';

  @override
  void initState() {
    super.initState();
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    _cartItems = List.from(cartProvider.items);
    _loadSuggestions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aggiorna _cartItems quando il CartProvider cambia
    final cartProvider = Provider.of<CartProvider>(context);
    if (mounted) {
      setState(() {
        _cartItems = List.from(cartProvider.items);
      });
    }
  }

  /// Carica suggerimenti da API
  Future<void> _loadSuggestions() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    try {
      // Costruisci query string cart_items
      final cartFoodIds = cartProvider.items
          .map((item) => item.menuItem.id.toString())
          .join(',');

      final url = Uri.parse(
        '$apiBaseUrl/restaurants/${widget.restaurant.id}/suggestions'
        '${cartFoodIds.isNotEmpty ? '?cart_items=$cartFoodIds' : ''}',
      );

      final response = await http.get(url);

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _recommendedItemIds = List<int>.from(
              data['data']['recommended'] ?? [],
            );
            _forgottenItemIds = List<int>.from(data['data']['forgotten'] ?? []);
            _suggestionsLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestionsLoading = false;
        });
      }
      if (kDebugMode) print('Errore caricamento suggerimenti: $e');
    }
  }

  // Calcola i totali
  double get _subtotal =>
      _cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  int get _totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmClearCart() {
    if (_cartItems.isEmpty) {
      _showToast('Il carrello è già vuoto');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _buildConfirmationDialog(
        title: 'Svuotare il carrello?',
        message:
            'Sei sicuro di voler rimuovere tutti gli articoli dal carrello? Questa azione non può essere annullata.',
        onConfirm: () async {
          // Svuota sia la lista locale che il CartProvider
          final cartProvider = Provider.of<CartProvider>(
            context,
            listen: false,
          );
          await cartProvider.clearCart();
          setState(() {
            _cartItems.clear();
          });
          Navigator.pop(context);
          _showToast('Carrello svuotato');
        },
      ),
    );
  }

  void _removeItem(CartItem item) {
    showDialog(
      context: context,
      builder: (context) => _buildConfirmationDialog(
        title: 'Rimuovere articolo?',
        message: 'Sei sicuro di voler rimuovere questo articolo dal carrello?',
        onConfirm: () {
          final cartProvider = Provider.of<CartProvider>(
            context,
            listen: false,
          );
          final index = _cartItems.indexOf(item);
          if (index >= 0) {
            cartProvider.removeItem(index);
          }
          setState(() {
            _cartItems = List.from(cartProvider.items);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _increaseQuantity(CartItem item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final index = _cartItems.indexOf(item);
    if (index >= 0) {
      cartProvider.incrementQuantity(index);
    }
    setState(() {
      _cartItems = List.from(cartProvider.items);
    });
  }

  void _decreaseQuantity(CartItem item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final index = _cartItems.indexOf(item);
    if (index >= 0) {
      if (item.quantity > 1) {
        cartProvider.decrementQuantity(index);
        setState(() {
          _cartItems = List.from(cartProvider.items);
        });
      } else {
        // Se quantità = 1, rimuovi l'item
        cartProvider.removeItem(index);
        setState(() {
          _cartItems = List.from(cartProvider.items);
        });
      }
    }
  }

  void _editItem(CartItem item) {
    // Salva l'indice corrente dell'item
    final itemIndex = _cartItems.indexOf(item);
    // Salva il context del cart screen
    final cartScreenContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ProductDetailModal(
        menuItem: item.menuItem,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        initialQuantity: item.quantity,
        initialCustomizations: item.customizationData,
        isEditMode: true,
        onAddToCart: (menuItem, quantity, customizations, priceModifier) {
          // Ottieni il CartProvider usando il context del cart screen
          final cartProvider = Provider.of<CartProvider>(
            cartScreenContext,
            listen: false,
          );

          // Prepara la lista di customizzazioni in formato stringa
          final customizationsList = <String>[];

          // Gestisci options (single-select groups)
          final options = customizations['options'];
          if (options != null && options is Map) {
            options.forEach((groupId, optionId) {
              for (var group in menuItem.customizations) {
                if (group.id == groupId.toString()) {
                  try {
                    final CustomizationOption option = group.options.firstWhere(
                      (opt) => opt.id == optionId.toString(),
                    );
                    customizationsList.add(option.label);
                  } catch (e) {
                    // Opzione non trovata, ignora
                  }
                }
              }
            });
          }

          // Gestisci extras (multi-select groups)
          final extras = customizations['extras'];
          if (extras != null && extras is List) {
            for (var extraId in extras) {
              for (var group in menuItem.customizations) {
                if (group.isMultiSelect) {
                  try {
                    final CustomizationOption option = group.options.firstWhere(
                      (opt) => opt.id == extraId.toString(),
                    );
                    customizationsList.add(option.label);
                  } catch (e) {
                    // Extra non trovato, ignora
                  }
                }
              }
            }
          }

          // Gestisci istruzioni
          final instructions = customizations['instructions'];
          if (instructions != null && instructions.toString().isNotEmpty) {
            customizationsList.add('Note: $instructions');
          }

          // Aggiorna l'item nel CartProvider
          if (itemIndex >= 0) {
            cartProvider.updateItem(
              index: itemIndex,
              quantity: quantity,
              customizations: customizationsList,
              customizationData: customizations,
              customizationsPriceModifier: priceModifier,
            );

            // Aggiorna anche lo stato locale
            if (mounted) {
              setState(() {
                _cartItems[itemIndex] = CartItem(
                  menuItem: menuItem,
                  quantity: quantity,
                  customizations: customizationsList,
                  customizationData: customizations,
                  customizationsPriceModifier: priceModifier,
                );
              });
            }
          }

          // Chiudi solo il modal usando il modalContext
          Navigator.of(modalContext).pop();
        },
      ),
    );
  }

  void _proceedToCheckout() {
    if (_cartItems.isEmpty) {
      _showToast('Il carrello è vuoto');
      return;
    }

    // Naviga allo schermo di checkout
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          restaurant: widget.restaurant,
          cartItems: _cartItems,
          subtotal: _subtotal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _cartItems);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _cartItems.isEmpty
                      ? _buildEmptyState()
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 100),
                            child: _buildCartContent(),
                          ),
                        ),
                ),
              ],
            ),
            if (_cartItems.isNotEmpty) _buildCheckoutBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 5,
        left: 12,
        right: 12,
        bottom: 5,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context, _cartItems),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Il tuo carrello',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Segoe UI',
              ),
            ),
          ),
          TextButton(
            onPressed: _confirmClearCart,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Svuota',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'Segoe UI',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildStep(1, 'Carrello', true, false),
          _buildStepLine(false),
          _buildStep(2, 'Checkout', false, false),
          _buildStepLine(false),
          _buildStep(3, 'Conferma', false, false),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String label, bool isActive, bool isCompleted) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isCompleted
                  ? successColor
                  : isActive
                  ? primaryColor
                  : lightGrayColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : Text(
                      number.toString(),
                      style: TextStyle(
                        color: isActive ? Colors.white : grayColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Segoe UI',
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isCompleted
                  ? successColor
                  : isActive
                  ? primaryColor
                  : grayColor,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              fontFamily: 'Segoe UI',
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14),
        color: isCompleted ? successColor : lightGrayColor,
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: lightGrayColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: widget.restaurant.logoUrl != null
                  ? Image.network(
                      widget.restaurant.logoUrl!,
                      width: 35,
                      height: 35,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.restaurant,
                        color: primaryColor,
                        size: 30,
                      ),
                    )
                  : const Icon(Icons.restaurant, color: primaryColor, size: 30),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.restaurant.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: darkColor,
                    fontFamily: 'Segoe UI',
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.motorcycle,
                      size: 11,
                      color: grayColor,
                    ),
                    Text(
                      widget.restaurant.deliveryTime,
                      style: const TextStyle(
                        fontSize: 13,
                        color: grayColor,
                        fontFamily: 'Segoe UI',
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(color: lightGrayColor, fontSize: 13),
                    ),
                    const FaIcon(
                      FontAwesomeIcons.locationDot,
                      size: 11,
                      color: grayColor,
                    ),
                    const Text(
                      '2.5 km',
                      style: TextStyle(
                        fontSize: 13,
                        color: grayColor,
                        fontFamily: 'Segoe UI',
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(color: lightGrayColor, fontSize: 13),
                    ),
                    const FaIcon(
                      FontAwesomeIcons.star,
                      size: 11,
                      color: grayColor,
                    ),
                    Text(
                      '${widget.restaurant.rating}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: grayColor,
                        fontFamily: 'Segoe UI',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 70,
              color: lightGrayColor,
            ),
            const SizedBox(height: 20),
            const Text(
              'Il tuo carrello è vuoto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: darkColor,
                fontFamily: 'Segoe UI',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Aggiungi qualcosa dal menu per iniziare a ordinare',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: grayColor,
                fontFamily: 'Segoe UI',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, _cartItems),
              icon: const FaIcon(FontAwesomeIcons.utensils, size: 16),
              label: const Text('Sfoglia il menu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Segoe UI',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    return Column(
      children: [
        _buildStepsIndicator(),
        _buildRestaurantInfo(),
        _buildCartItems(),
        _buildRecommendedItems(),
        _buildForgottenItems(),
      ],
    );
  }

  Widget _buildCartItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/icons8-basket-2-32.png',
                width: 16,
                height: 16,
                color: primaryColor,
              ),
              const SizedBox(width: 10),
              const Text(
                'I tuoi articoli',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                  fontFamily: 'Segoe UI',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        ..._cartItems.map((item) => _buildCartItem(item)),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: lightGrayColor.withOpacity(0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                    fontSize: 14,
                    fontFamily: 'Segoe UI',
                    height: 1.15,
                  ),
                ),
                if (item.customizations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.customizationsText,
                    style: const TextStyle(
                      color: grayColor,
                      fontSize: 12,
                      fontFamily: 'Segoe UI',
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '€${item.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: darkColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'Segoe UI',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _editItem(item),
                      icon: const FaIcon(
                        FontAwesomeIcons.penToSquare,
                        size: 11,
                      ),
                      label: const Text('Modifica'),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Segoe UI',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: () => _removeItem(item),
                      icon: const FaIcon(FontAwesomeIcons.trashCan, size: 11),
                      label: const Text('Rimuovi'),
                      style: TextButton.styleFrom(
                        foregroundColor: dangerColor,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Segoe UI',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: lightGrayColor,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                _buildQuantityButton(
                  icon: Icons.remove,
                  onPressed: item.quantity > 1
                      ? () => _decreaseQuantity(item)
                      : null,
                ),
                Container(
                  width: 30,
                  alignment: Alignment.center,
                  child: Text(
                    item.quantity.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                      fontSize: 14,
                      fontFamily: 'Segoe UI',
                    ),
                  ),
                ),
                _buildQuantityButton(
                  icon: Icons.add,
                  onPressed: () => _increaseQuantity(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: onPressed != null ? lightColor : lightColor.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        color: darkColor,
      ),
    );
  }

  Widget _buildRecommendedItems() {
    if (_suggestionsLoading) {
      return const SizedBox.shrink(); // Non mostrare nulla mentre carica
    }

    if (_recommendedItemIds.isEmpty) {
      return const SizedBox.shrink(); // Non mostrare se nessun suggerimento
    }

    return FutureBuilder<List<MenuItem>>(
      future: _loadMenuItems(_recommendedItemIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.only(left: 20, top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.thumbsUp,
                    size: 16,
                    color: primaryColor,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Consigliati per te',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                      fontFamily: 'Segoe UI',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12, bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: item.imageUrl != null
                                ? Image.network(
                                    item.imageUrl!,
                                    width: 140,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 140,
                                      height: 100,
                                      color: lightGrayColor,
                                      child: const Icon(
                                        Icons.image,
                                        color: grayColor,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 140,
                                    height: 100,
                                    color: lightGrayColor,
                                    child: const Icon(
                                      Icons.image,
                                      color: grayColor,
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: darkColor,
                                    fontSize: 14,
                                    fontFamily: 'Segoe UI',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '€${item.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: darkColor,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        fontFamily: 'Segoe UI',
                                      ),
                                    ),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.add,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          _showToast('${item.name} aggiunto');
                                        },
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildForgottenItems() {
    if (_suggestionsLoading) {
      return const SizedBox.shrink();
    }

    if (_forgottenItemIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<MenuItem>>(
      future: _loadMenuItems(_forgottenItemIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.lightbulb,
                    size: 16,
                    color: primaryColor,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Hai dimenticato qualcosa?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                      fontFamily: 'Segoe UI',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ...items.map((item) => _buildForgottenItem(item)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildForgottenItem(MenuItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl != null
                ? Image.network(
                    item.imageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 50,
                      height: 50,
                      color: lightGrayColor,
                      child: const Icon(Icons.image, color: grayColor),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: lightGrayColor,
                    child: const Icon(Icons.image, color: grayColor),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: darkColor,
                    fontSize: 14,
                    fontFamily: 'Segoe UI',
                  ),
                ),
                const SizedBox(height: 2),
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: grayColor,
                      fontSize: 12,
                      fontFamily: 'Segoe UI',
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '€${item.price.toStringAsFixed(2)}',
            style: const TextStyle(
              color: darkColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Segoe UI',
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              onPressed: () {
                _showToast('${item.name} aggiunto');
              },
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper per caricare i MenuItem dal menu del ristorante
  Future<List<MenuItem>> _loadMenuItems(List<int> foodIds) async {
    if (foodIds.isEmpty) return [];

    try {
      // Carica il menu dal ristorante
      final menu = await _loadRestaurantMenu();

      // Filtra i piatti che corrispondono ai foodIds suggeriti
      return menu.where((dish) => foodIds.contains(dish.id)).toList();
    } catch (e) {
      if (kDebugMode) print('Errore caricamento piatti suggeriti: $e');
      return [];
    }
  }

  /// Carica il menu completo del ristorante
  Future<List<MenuItem>> _loadRestaurantMenu() async {
    try {
      final url = Uri.parse(
        '$apiBaseUrl/restaurants/${widget.restaurant.id}/menu',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          List<MenuItem> allItems = [];

          // Itera sulle categorie e raccoglie tutti i piatti
          for (var category in data['data']) {
            if (category['dishes'] != null) {
              for (var dishJson in category['dishes']) {
                allItems.add(MenuItem.fromJson(dishJson));
              }
            }
          }

          return allItems;
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Errore caricamento menu: $e');
      return [];
    }
  }

  Widget _buildCheckoutBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            onPressed: _proceedToCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/icons/icons8-basket-2-32.png',
                      width: 20,
                      height: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $_totalItems ${_totalItems == 1 ? 'articolo' : 'articoli'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '€${_subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/icons/icons8-arrow-WHITE-32.png',
                      width: 16,
                      height: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, lightGrayColor.withOpacity(0.3)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: dangerColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, color: dangerColor, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: darkColor,
                fontFamily: 'Segoe UI',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: grayColor,
                fontFamily: 'Segoe UI',
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkColor,
                      side: BorderSide(color: lightGrayColor, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Annulla',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        fontFamily: 'Segoe UI',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dangerColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Rimuovi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        fontFamily: 'Segoe UI',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
