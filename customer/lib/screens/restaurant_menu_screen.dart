import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../services/restaurant_service.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../providers/favorites_provider.dart';
import 'product_detail_modal.dart';
import 'checkout_screen.dart';

/// Restaurant Menu Screen - Basato sul prototipo 7-menu.html
class RestaurantMenuScreen extends StatefulWidget {
  final Restaurant restaurant;
  final int? openDishId;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurant,
    this.openDishId,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final ScrollController _scrollController = ScrollController();
  final RestaurantService _restaurantService = RestaurantService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory =
      ''; // Verrà impostata alla prima categoria caricata
  bool _isSearchActive = false;
  bool _isLoadingMenu = true;
  double _overScrollOffset = 0.0; // Per l'effetto pull-to-reveal
  String _searchQuery = '';

  // Menu data from API
  List<Map<String, dynamic>> _menuCategories = [];
  final Map<String, List<MenuItem>> _menuItemsByCategory = {};

  // Colori ridotti
  static const Color primaryColor = AppColors.primary;
  static const Color accentColor = AppColors.accent;
  static const Color successColor = AppColors.success;
  static const Color dangerColor = AppColors.danger;
  static const Color darkColor = AppColors.dark;
  static const Color grayColor = AppColors.gray;
  static const Color lightGrayColor = Color(0xffeeeeee);

  // Dynamic categories from API
  List<String> get _categories {
    // Non includere 'featured' nelle tab, solo le categorie reali
    if (_menuCategories.isEmpty) return [];
    return _menuCategories.map((c) => c['id'].toString()).toList();
  }

  Map<String, String> get _categoryLabels {
    final labels = <String, String>{};
    for (var category in _menuCategories) {
      labels[category['id'].toString()] = category['name'];
    }
    return labels;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      setState(() => _isLoadingMenu = true);

      final menuData = await _restaurantService.getRestaurantMenu(
        widget.restaurant.id,
      );

      setState(() {
        _menuCategories = List<Map<String, dynamic>>.from(
          menuData['categories'] ?? [],
        );

        // Group items by category
        _menuItemsByCategory.clear();

        // Featured items
        final allItems = <MenuItem>[];
        for (var category in _menuCategories) {
          final categoryId = category['id'].toString();
          final items =
              (category['dishes'] as List?)
                  ?.map((item) => MenuItem.fromJson(item))
                  .toList() ??
              [];

          _menuItemsByCategory[categoryId] = items;
          allItems.addAll(items);
        }

        // Featured: items with is_featured flag
        _menuItemsByCategory['featured'] = allItems
            .where((item) => item.badges.contains('Consigliato'))
            .toList();

        // Imposta la prima categoria come selezionata se non è già impostata
        if (_menuCategories.isNotEmpty && _selectedCategory.isEmpty) {
          _selectedCategory = _menuCategories[0]['id'].toString();
        }

        _isLoadingMenu = false;
      });

      // Se richiesto, apri automaticamente il dettaglio del piatto
      if (widget.openDishId != null && mounted) {
        _openDishDetailById(widget.openDishId!);
      }
    } catch (e) {
      setState(() => _isLoadingMenu = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento del menu: $e')),
        );
      }
    }
  }

  void _openDishDetailById(int dishId) {
    // Cerca il piatto in tutte le categorie
    MenuItem? targetDish;
    for (var items in _menuItemsByCategory.values) {
      try {
        targetDish = items.firstWhere((item) => item.id == dishId);
        break;
      } catch (_) {
        continue;
      }
    }

    if (targetDish != null) {
      // Apri il modal dopo un breve ritardo per permettere al menu di renderizzarsi
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _showProductDetail(targetDish!);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Update active category based on scroll position
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipPath(
        clipper: _BottomSheetCurveClipper(),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: lightGrayColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              // Titolo
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Opzioni',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkColor,
                  ),
                ),
              ),
              // Opzioni
              _buildOptionItem(
                iconPath: 'assets/icons/icons8-mi-piace-32.png',
                title: 'Aggiungi ai preferiti',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implementare funzionalità preferiti
                },
              ),
              _buildOptionItem(
                iconPath: 'assets/icons/icons8-condividi-2-32.png',
                title: 'Condividi il locale',
                onTap: () {
                  Navigator.pop(context);
                  _shareRestaurant();
                },
              ),
              _buildOptionItem(
                iconPath: 'assets/icons/icons8-valutazione-32.png',
                title: 'Lascia una recensione',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implementare funzionalità recensione
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required String iconPath,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Image.asset(iconPath, width: 24, height: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, color: darkColor),
              ),
            ),
            const Icon(Icons.chevron_right, color: grayColor, size: 20),
          ],
        ),
      ),
    );
  }

  /// Piatto bloccato dal server per oggi (convenzione: l'etichetta di
  /// disponibilita' inizia con "non disponibile"). I vincoli di fascia
  /// ("Disponibile dalle 18:00") NON bloccano: decide il checkout.
  bool _isDishUnavailable(MenuItem item) {
    final label = item.availabilityLabel;
    return label != null && label.toLowerCase().startsWith('non disponibile');
  }

  /// Banner "chiuso ora" sotto l'header: informa senza bloccare,
  /// perche' con le fasce orarie si puo' comunque preordinare.
  Widget _buildClosedBanner() {
    final opensAt = widget.restaurant.opensAt;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD9A0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: Color(0xFF9A6400)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              opensAt != null && opensAt.isNotEmpty
                  ? 'Ora è chiuso: riapre alle $opensAt. '
                        'Puoi comunque ordinare per dopo.'
                  : 'Ora è chiuso. Puoi comunque ordinare per un altro orario.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A6400),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareRestaurant() {
    final deliveryCost = widget.restaurant.freeDelivery == true
        ? 'Gratis'
        : widget.restaurant.actualDeliveryFee != null
        ? '${widget.restaurant.actualDeliveryFee!.toStringAsFixed(2)} Euro'
        : widget.restaurant.deliveryCost;

    // La valutazione entra nel testo solo se esiste davvero.
    final rating = widget.restaurant.rating;
    final String ratingLine = rating > 0
        ? 'Valutazione: ${rating.toStringAsFixed(1)}/5\n'
        : '';

    final String shareText =
        'Dai un\'occhiata a ${widget.restaurant.name}!\n\n'
        '$ratingLine'
        'Consegna: ${widget.restaurant.deliveryTime}\n'
        'Costo di consegna: $deliveryCost\n\n'
        'Ordina ora tramite la nostra app!';

    Share.share(
      shareText,
      subject: 'Guarda questo ristorante: ${widget.restaurant.name}',
    );
  }

  void _showProductDetail(MenuItem item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailModal(
        menuItem: item,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        onAddToCart: (menuItem, quantity, customizations, priceModifier) {
          _addToCart(
            menuItem,
            quantity,
            customizations,
            priceModifier,
            cartProvider,
          );
        },
      ),
    );
  }

  void _showProductDetailWithCustomizationWarning(MenuItem item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailModal(
        menuItem: item,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        onAddToCart: (menuItem, quantity, customizations, priceModifier) {
          _addToCart(
            menuItem,
            quantity,
            customizations,
            priceModifier,
            cartProvider,
          );
        },
      ),
    );

    // Mostra messaggio di avviso
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Questo piatto ha bisogno di essere personalizzato!',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            backgroundColor: primaryColor,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _quickAddToCart(MenuItem item, CartProvider cartProvider) {
    try {
      cartProvider.addItem(
        menuItem: item,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        restaurantLogoUrl: widget.restaurant.logoUrl,
        quantity: 1,
        selectedExtras: null,
        notes: null,
      );
    } catch (e) {
      // Mostra errore (es: ristorante diverso)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            duration: const Duration(seconds: 3),
            backgroundColor: dangerColor,
          ),
        );
      }
    }
  }

  void _addToCart(
    MenuItem item,
    int quantity,
    Map<String, dynamic> customizations,
    double priceModifier,
    CartProvider cartProvider,
  ) {
    // Prepara la lista delle scelte selezionate.
    // Devono entrarci SIA le opzioni a scelta singola (customizations['options'],
    // mappa gruppo -> opzione: taglia, numero di pezzi, peso...) SIA gli extra
    // multi-selezione. Entrambe hanno un prezzo e vanno addebitate, ed entrambe
    // servono al ristorante per sapere cosa preparare.
    final List<Map<String, dynamic>> selectedExtras = [];

    bool addOptionFromGroup(CustomizationGroup group, String optionId) {
      for (final option in group.options) {
        if (option.id == optionId) {
          selectedExtras.add({
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
    final singleChoices = customizations['options'];
    if (singleChoices is Map) {
      singleChoices.forEach((groupId, optionId) {
        for (final group in item.customizations) {
          if (group.id == groupId.toString()) {
            addOptionFromGroup(group, optionId.toString());
            break;
          }
        }
      });
    }

    // Extra multi-selezione: lista di optionId
    if (customizations['extras'] != null) {
      for (final extraId in customizations['extras']) {
        for (final group in item.customizations) {
          if (!group.isMultiSelect) continue;
          if (addOptionFromGroup(group, extraId.toString())) break;
        }
      }
    }

    final notes = customizations['instructions'] as String?;

    try {
      cartProvider.addItem(
        menuItem: item,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        restaurantLogoUrl: widget.restaurant.logoUrl,
        quantity: quantity,
        selectedExtras: selectedExtras.isNotEmpty ? selectedExtras : null,
        notes: notes,
      );
    } catch (e) {
      // Mostra errore (es: ristorante diverso)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            duration: const Duration(seconds: 3),
            backgroundColor: dangerColor,
            action: SnackBarAction(
              label: 'Svuota carrello',
              textColor: Colors.white,
              onPressed: () {
                cartProvider.clearCart();
                // Riprova ad aggiungere
                _addToCart(
                  item,
                  quantity,
                  customizations,
                  priceModifier,
                  cartProvider,
                );
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcola il fattore di scala per lo zoom dell'immagine durante il pull
    final double imageScale = 1.0 + (_overScrollOffset / 400);
    // Espandi anche l'altezza del contenitore durante il pull
    final double containerHeight = 200 + (_overScrollOffset / 2);

    return Scaffold(
      body: Stack(
        children: [
          // Immagine di copertina FISSA con zoom durante pull
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height:
                  containerHeight, // Altezza dinamica che si espande con il pull
              child: Stack(
                children: [
                  // Immagine con effetto zoom
                  Positioned.fill(
                    child: Transform.scale(
                      scale: imageScale,
                      child: Image.network(
                        widget.restaurant.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: lightGrayColor,
                          child: const Icon(
                            Icons.restaurant,
                            size: 80,
                            color: grayColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay leggero
                  Container(
                    height: containerHeight, // Anche il gradient si espande
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is ScrollUpdateNotification) {
                // Rileva overscroll verso l'alto (negativo)
                if (notification.metrics.pixels < 0) {
                  setState(() {
                    _overScrollOffset = notification.metrics.pixels.abs();
                  });
                } else {
                  if (_overScrollOffset != 0) {
                    setState(() {
                      _overScrollOffset = 0.0;
                    });
                  }
                }
              }
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(),
                // Ristorante chiuso ora: lo si dice SUBITO, non al checkout.
                // Ordinare resta possibile (preordine su fasce future).
                if (widget.restaurant.isOpenNow == false)
                  SliverToBoxAdapter(child: _buildClosedBanner()),
                _buildCategoryTabs(), // Tab aderenti al box
                if (!_isSearchActive) _buildFeaturedItems(),
                // Dynamic menu sections from API categories
                ..._buildDynamicMenuSections(),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
          // Barra di navigazione FISSA - pulsanti che non si muovono durante il pull
          // IMPORTANTE: Posizionata DOPO CustomScrollView per essere in primo piano
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pulsante indietro a sinistra
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.arrow_back, color: darkColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // Pulsanti a destra
                Row(
                  children: [
                    // Pulsante ricerca
                    Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(Icons.search, color: darkColor),
                        onPressed: () {
                          setState(() {
                            _isSearchActive = !_isSearchActive;
                          });
                          // Se attivo la ricerca, scrolla verso il basso per mostrare i risultati
                          if (_isSearchActive) {
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                _scrollController.animateTo(
                                  200.0,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                    // Pulsante preferiti
                    Consumer<FavoritesProvider>(
                      builder: (context, favProvider, child) {
                        final isFavorite = favProvider.isFavorite(
                          'restaurant',
                          widget.restaurant.id,
                        );
                        return Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? primaryColor : darkColor,
                            ),
                            onPressed: () {
                              if (isFavorite) {
                                favProvider.removeFavorite(
                                  'restaurant',
                                  widget.restaurant.id,
                                );
                              } else {
                                favProvider.addFavorite(
                                  'restaurant',
                                  widget.restaurant.id,
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                    // Pulsante menu opzioni
                    Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(Icons.more_vert, color: darkColor),
                        onPressed: () => _showOptionsMenu(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Overlay per chiudere la ricerca cliccando fuori
          if (_isSearchActive)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isSearchActive = false;
                  });
                },
                child: Container(color: Colors.transparent),
              ),
            ),
          // Barra di ricerca FISSA in alto
          if (_isSearchActive)
            Positioned(
              top: 85,
              left: 12,
              right: 12,
              child: GestureDetector(
                onTap:
                    () {}, // Assorbe i tap per non chiudere quando si clicca sulla barra
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cerca un piatto...',
                      hintStyle: const TextStyle(
                        color: grayColor,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: grayColor,
                        size: 18,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          _buildCartBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 250, // Altezza totale: spazio per immagine + logo + nome + chip
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Container con onda che parte da 90px e riempie il resto
            Positioned(
              top: 90, // Posizionato a 90px, lascia visibili 90px di immagine
              left: 0,
              right: 0,
              bottom: 0, // Si estende fino in fondo allo Stack
              child: ClipPath(
                clipper: _WaveTopClipper(),
                child: Container(width: double.infinity, color: Colors.white),
              ),
            ),

            // Logo del ristorante - in primo piano a sinistra
            if (widget.restaurant.logoUrl != null)
              Positioned(
                top: 110,
                left: 20,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.restaurant.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.restaurant,
                        color: grayColor,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),

            // Info ristorante sotto la copertina
            Positioned(
              top: 170,
              left: 20,
              right: 20,
              child: _buildRestaurantInfoContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantInfoContent() {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Calcola distanza
    String? distanceText;
    final userLat = locationProvider.activeLatitude;
    final userLng = locationProvider.activeLongitude;
    if (userLat != null &&
        userLng != null &&
        widget.restaurant.latitude != null &&
        widget.restaurant.longitude != null &&
        widget.restaurant.latitude != 0 &&
        widget.restaurant.longitude != 0) {
      final distance = _calculateDistance(
        userLat,
        userLng,
        widget.restaurant.latitude!,
        widget.restaurant.longitude!,
      );
      distanceText = '${distance.toStringAsFixed(1)}km';
    }

    // Costo consegna
    final deliveryCostText = widget.restaurant.freeDelivery == true
        ? 'Gratis'
        : widget.restaurant.actualDeliveryFee != null
        ? '€${widget.restaurant.actualDeliveryFee!.toStringAsFixed(2)}'
        : widget.restaurant.deliveryCost;

    // Minimo ordine
    String? minOrderText;
    if (widget.restaurant.actualMinOrder != null &&
        widget.restaurant.actualMinOrder! > 0) {
      minOrderText = '€${widget.restaurant.actualMinOrder!.toStringAsFixed(0)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome ristorante
        Text(
          widget.restaurant.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkColor,
          ),
        ),
        const SizedBox(height: 12),

        // Chip informative: solo costo consegna, minimo ordine e distanza
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildGlovoChip(
              icon: Icons.directions_bike,
              text: deliveryCostText,
              backgroundColor: const Color(0xFFF5F5F5),
            ),
            if (minOrderText != null)
              _buildGlovoChip(
                icon: Icons.shopping_bag,
                text: minOrderText,
                backgroundColor: const Color(0xFFF5F5F5),
              ),
            if (distanceText != null)
              _buildGlovoChip(
                icon: Icons.location_on,
                text: distanceText,
                backgroundColor: const Color(0xFFF5F5F5),
              ),
          ],
        ),
      ],
    );
  }

  /// Calcola distanza in km usando formula Haversine
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        (cos((lat2 - lat1) * p) / 2) +
        (cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2);
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  Widget _buildGlovoChip({
    required IconData icon,
    required String text,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: darkColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: darkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CategoryTabsDelegate(
        categories: _categories,
        categoryLabels: _categoryLabels,
        selectedCategory: _selectedCategory,
        onCategorySelected: (category) {
          setState(() => _selectedCategory = category);
        },
      ),
    );
  }

  Widget _buildFeaturedItems() {
    if (_isLoadingMenu) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final featuredItems = _menuItemsByCategory['featured'] ?? [];

    if (featuredItems.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.star,
                    size: 14,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'In evidenza',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 210, // Aumentato da 190 a 210 per evitare overflow
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: featuredItems.length,
                itemBuilder: (context, index) {
                  final item = featuredItems[index];
                  return _buildFeaturedCard(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(MenuItem item) {
    return GestureDetector(
      onTap: () => _showProductDetail(item),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Immagine con badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    item.imageUrl ?? '',
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: lightGrayColor,
                      child: const Icon(
                        Icons.restaurant,
                        color: grayColor,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                if (item.badges.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.badges.first.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: darkColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Contenuto con flex per evitare overflow
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome prodotto
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: darkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Descrizione con spazio flessibile
                    Expanded(
                      child: Text(
                        item.description,
                        style: const TextStyle(fontSize: 11, color: grayColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Prezzo e bottone aggiungi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '€${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: darkColor,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showProductDetail(item),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDynamicMenuSections() {
    if (_isLoadingMenu || _menuCategories.isEmpty) {
      return [];
    }

    // Se c'è una ricerca attiva, mostra tutte le categorie che hanno risultati
    // Altrimenti filtra per mostrare solo la categoria selezionata
    final selectedCategories = _searchQuery.isNotEmpty
        ? _menuCategories
        : _menuCategories.where((category) {
            final categoryId = category['id'].toString();
            return categoryId == _selectedCategory;
          }).toList();

    // Map category names to appropriate icons
    final iconMap = {
      'pizze': 'assets/icons/icons8-pizza-32.png',
      'pizza': 'assets/icons/icons8-pizza-32.png',
      'antipasti':
          'assets/icons/icons8-ristorante-32.png', // Usa ristorante per antipasti
      'antipasto': 'assets/icons/icons8-ristorante-32.png',
      'pasta': 'assets/icons/icons8-ristorante-32.png',
      'primi': 'assets/icons/icons8-ristorante-32.png',
      'secondi': 'assets/icons/icons8-carne-32.png',
      'carne': 'assets/icons/icons8-carne-32.png',
      'pesce': 'assets/icons/icons8-pesce-32.png',
      'dolci': 'assets/icons/icons8-cupcake-32.png',
      'dolce': 'assets/icons/icons8-cupcake-32.png',
      'dessert': 'assets/icons/icons8-cupcake-32.png',
      'bevande': 'assets/icons/icons8-coppa-32.png',
      'bevanda': 'assets/icons/icons8-coppa-32.png',
      'drink': 'assets/icons/icons8-coppa-32.png',
      'vini': 'assets/icons/icons8-bottiglia-di-champagne-32.png',
      'vino': 'assets/icons/icons8-bottiglia-di-champagne-32.png',
    };

    return selectedCategories.map((category) {
      final categoryId = category['id'].toString();
      final categoryName = category['name'] as String;

      // Find appropriate icon
      String iconPath = 'assets/icons/icons8-ristorante-32.png'; // Default
      final lowerName = categoryName.toLowerCase();
      for (var key in iconMap.keys) {
        if (lowerName.contains(key)) {
          iconPath = iconMap[key]!;
          break;
        }
      }

      return _buildMenuSection(categoryId, categoryName, iconPath);
    }).toList();
  }

  Widget _buildMenuSection(String categoryId, String title, String iconPath) {
    if (_isLoadingMenu) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    var items = _menuItemsByCategory[categoryId] ?? [];

    // Filtra i piatti in base alla query di ricerca
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        return item.name.toLowerCase().contains(_searchQuery) ||
            item.description.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  iconPath,
                  width: 14,
                  height: 14,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: darkColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _buildMenuItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(MenuItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: lightGrayColor.withOpacity(0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showProductDetail(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkColor,
                          ),
                        ),
                      ),
                      if (item.badges.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: item.badges
                              .take(2)
                              .map(
                                (badge) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getBadgeColor(badge),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 12, color: grayColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Vincolo orario dal pannello (es. "Disponibile dalle 18:00"):
                  // il piatto resta ordinabile per una fascia serale, ma il cliente
                  // sa subito che a pranzo non glielo portiamo.
                  if (item.availabilityLabel != null) ...[
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        // "Non disponibile oggi" e' uno stop, non un orario: rosso.
                        // Un vincolo di fascia ("Disponibile dalle 18:00") e' un
                        // avviso: arancione.
                        final bloccante = item.availabilityLabel!
                            .toLowerCase()
                            .startsWith('non disponibile');
                        final testo = bloccante
                            ? const Color(0xFFB3261E)
                            : const Color(0xFF9A6400);
                        final sfondo = bloccante
                            ? const Color(0xFFFDECEA)
                            : const Color(0xFFFFF4E5);
                        final bordo = bloccante
                            ? const Color(0xFFF5C2BD)
                            : const Color(0xFFFFD9A0);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: sfondo,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: bordo),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                bloccante
                                    ? Icons.do_not_disturb_on_outlined
                                    : Icons.schedule,
                                size: 12,
                                color: testo,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.availabilityLabel!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: testo,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (item.hasDiscount)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '€${item.originalPrice!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: grayColor,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Text(
                          '€${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: successColor,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '€${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: darkColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Pulsanti +/- per aggiunta rapida al carrello
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              final itemInCart = cart.items
                  .where((cartItem) => cartItem.menuItem.id == item.id)
                  .toList();
              final totalQuantity = itemInCart.fold<int>(
                0,
                (sum, cartItem) => sum + cartItem.quantity,
              );

              if (totalQuantity > 0) {
                // Mostra selettore con - quantità +
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: lightGrayColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsante -
                      InkWell(
                        onTap: () {
                          if (itemInCart.isNotEmpty) {
                            final index = cart.items.indexOf(itemInCart.last);
                            if (itemInCart.last.quantity > 1) {
                              cart.updateQuantity(
                                index,
                                itemInCart.last.quantity - 1,
                              );
                            } else {
                              cart.removeItem(index);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.remove,
                            size: 16,
                            color: darkColor,
                          ),
                        ),
                      ),
                      // Quantità
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          totalQuantity.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkColor,
                            fontFamily: 'Segoe UI',
                          ),
                        ),
                      ),
                      // Pulsante +
                      InkWell(
                        onTap: () {
                          // Piatto non disponibile oggi: niente aggiunta
                          if (_isDishUnavailable(item)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  item.availabilityLabel ??
                                      'Piatto non disponibile oggi',
                                ),
                                backgroundColor: dangerColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          // Controlla se ha varianti obbligatorie
                          final hasRequiredCustomizations = item.customizations
                              .any((group) => group.isRequired);

                          if (hasRequiredCustomizations) {
                            // Mostra product detail con avviso
                            _showProductDetailWithCustomizationWarning(item);
                          } else {
                            // Aggiungi direttamente al carrello
                            _quickAddToCart(item, cart);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: darkColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // Mostra solo pulsante +
                return GestureDetector(
                  onTap: () {
                    // Piatto non disponibile oggi: niente aggiunta
                    if (_isDishUnavailable(item)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            item.availabilityLabel ??
                                'Piatto non disponibile oggi',
                          ),
                          backgroundColor: dangerColor,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    // Controlla se ha varianti obbligatorie
                    final hasRequiredCustomizations = item.customizations.any(
                      (group) => group.isRequired,
                    );

                    if (hasRequiredCustomizations) {
                      // Mostra product detail con avviso
                      _showProductDetailWithCustomizationWarning(item);
                    } else {
                      // Aggiungi direttamente al carrello
                      _quickAddToCart(item, cart);
                    }
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(String badge) {
    switch (badge.toLowerCase()) {
      case 'bestseller':
      case 'popolare':
        return accentColor;
      case 'nuovo':
        return successColor;
      case 'piccante':
        return dangerColor;
      case 'vegetariano':
        return const Color(0xFF8BC34A);
      default:
        return grayColor;
    }
  }

  Widget _buildCartBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        child: Consumer<CartProvider>(
          builder: (context, cart, child) {
            return ElevatedButton(
              onPressed: cart.itemCount > 0
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutScreen(
                            restaurant: widget.restaurant,
                            cartItems: cart.items,
                            subtotal: cart.total,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: cart.itemCount > 0 ? primaryColor : grayColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                        '• ${cart.itemCount} ${cart.itemCount == 1 ? 'articolo' : 'articoli'}',
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
                        '€${cart.total.toStringAsFixed(2)}',
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
            );
          },
        ),
      ),
    );
  }
}

class _CategoryTabsDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final Map<String, String> categoryLabels;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  static const Color primaryColor = AppColors.primary;

  _CategoryTabsDelegate({
    required this.categories,
    required this.categoryLabels,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final label = categoryLabels[category] ?? category;
          final isSelected = category == selectedCategory;

          return GestureDetector(
            onTap: () => onCategorySelected(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? primaryColor : AppColors.gray,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryTabsDelegate oldDelegate) {
    return selectedCategory != oldDelegate.selectedCategory ||
        categories.length != oldDelegate.categories.length;
  }
}

/// Widget per gestire l'immagine del menu item che si nasconde se non carica
class _MenuItemImage extends StatefulWidget {
  final String imageUrl;

  const _MenuItemImage({required this.imageUrl});

  @override
  State<_MenuItemImage> createState() => _MenuItemImageState();
}

class _MenuItemImageState extends State<_MenuItemImage> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    // Se c'è stato un errore, non mostrare nulla
    if (_hasError) return const SizedBox.shrink();

    return Container(
      width: 75,
      height: 75,
      margin: const EdgeInsets.only(left: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          widget.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              // Immagine caricata con successo
              return child;
            }
            // Mostra un placeholder durante il caricamento
            return Container(
              color: AppColors.lightGray,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // Imposta l'errore e ricostruisci per nascondere l'immagine
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                });
              }
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

/// CustomClipper per l'onda nella parte superiore del contenuto bianco
/// Crea un'onda che parte dalla parte alta e copre l'immagine sottostante
class _WaveTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Parte dall'alto con l'onda
    path.moveTo(0, 65);

    // Effetto onda nella parte superiore
    path.cubicTo(
      size.width * 0.15,
      57,
      size.width * 0.25,
      50,
      size.width * 0.35,
      55,
    );

    path.cubicTo(
      size.width * 0.5,
      60,
      size.width * 0.65,
      52,
      size.width * 0.75,
      56,
    );

    path.cubicTo(size.width * 0.85, 62, size.width * 0.95, 66, size.width, 65);

    // Completa il rettangolo
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// CustomClipper per la curva del bottom sheet delle opzioni
class _BottomSheetCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Inizia dall'angolo in alto a sinistra
    path.moveTo(0, 30);

    // Curva concava nella parte superiore centrale (semicerchio verso l'interno)
    path.quadraticBezierTo(
      size.width * 0.5, // Punto di controllo X (centro)
      -10, // Punto di controllo Y (verso l'alto per creare la concavità)
      size.width, // Fine X (angolo destro)
      30, // Fine Y
    );

    // Continua verso il basso a destra
    path.lineTo(size.width, size.height);

    // Linea in basso
    path.lineTo(0, size.height);

    // Chiude il percorso
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
