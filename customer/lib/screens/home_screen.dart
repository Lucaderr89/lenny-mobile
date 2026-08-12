import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../widgets/guest_gate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../config/app_constants.dart';
import '../models/cuisine.dart';
import '../models/restaurant.dart';
import '../services/cuisine_service.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/order_type_dialog.dart';
import '../widgets/address_selector_bottom_sheet.dart';
import '../widgets/blob_icon_selector.dart';
import 'tabs/ristoranti_tab.dart';
import 'tabs/scopri_tab.dart';
import 'tabs/per_te_tab.dart';
import 'cart_screen.dart';
import 'live_orders_screen.dart';
import 'favorites_screen.dart';
import 'ai_chat_screen.dart';
import 'notifications_screen.dart';
import '../providers/notification_provider.dart';
import '../widgets/app_icon.dart';

/// Home Screen basata sul prototipo 6-HOME DEFINITIVA.html
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedTab = 0;
  int _selectedBottomNav = 0;
  String _customerName = '';
  bool _isHeaderCollapsed = false;
  int? _selectedCuisineId; // Filtro cucina attivo (null = tutti)
  String _searchQuery = ''; // Query di ricerca
  final TextEditingController _searchController = TextEditingController();

  // Debounce ricerca: si filtra quando l'utente smette di digitare,
  // non a ogni singola lettera.
  Timer? _searchDebounce;

  // Ancora per il coach-mark sul badge CONSEGNA/RITIRO
  final GlobalKey _orderTypeBadgeKey = GlobalKey();

  late PageController _pageController;
  late List<ScrollController> _scrollControllers;
  final CuisineService _cuisineService = CuisineService();

  // Controller per animazione vibrazione carrello
  late AnimationController _cartShakeController;
  late Animation<double> _cartShakeAnimation;

  // Riferimento al CartProvider per evitare accessi al context nel dispose
  CartProvider? _cartProvider;

  List<Cuisine> _cuisines = [];
  bool _isLoadingCuisines = true;
  StreamSubscription? _fcmSubscription;

  // Colori dal prototipo 6-HOME DEFINITIVA.html
  static const Color primaryBlue =
      AppColors.primary; // era un SECONDO blu (#0F4BCA)
  static const Color primaryDarkPink = AppColors.primary;
  static const Color accentYellow = AppColors.accent;
  // Colori badge tipo ordine (uguali al dialog)
  static const Color badgeDeliveryColor = AppColors.primary; // Rosso consegna
  static const Color badgePickupColor = Color(0xFFF6E644); // Giallo ritiro
  static const Color warningOrange = Color(0xFFE67700);
  static const Color dangerRed = Color(0xFFC62828);
  static const Color darkColor = AppColors.dark;
  static const Color lightColor = Color(0xFFFFFFFF);
  static const Color grayColor = AppColors.grayDark;
  static const Color lightGrayColor = AppColors.grayLight;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _scrollControllers = List.generate(3, (_) => ScrollController());

    // Avvia polling notifiche
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).start();
    });

    // Aggiorna badge subito quando arriva un push FCM in foreground
    _fcmSubscription = FirebaseMessaging.onMessage.listen((_) {
      if (mounted) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).refreshCount();
      }
    });
    for (var controller in _scrollControllers) {
      controller.addListener(() => _onScroll(controller.offset));
    }

    // Inizializza animazione shake per carrello
    _cartShakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _cartShakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_cartShakeController);

    _loadCustomerName();
    _loadCuisines();

    // 🎯 Mostra dialog selezione tipo ordine (DOPO il primo frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOrderTypeDialogIfNeeded();

      // Ascolta i cambiamenti del carrello per triggerare l'animazione
      _cartProvider = Provider.of<CartProvider>(context, listen: false);
      _cartProvider?.addListener(_onCartChanged);
    });
  }

  /// Mostra dialog tipo ordine SOLO se non e' mai stato scelto
  /// (la scelta e' persistita: agli avvii successivi non ricompare).
  Future<void> _showOrderTypeDialogIfNeeded() async {
    if (mounted) {
      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );

      if (!locationProvider.hasSelectedOrderType) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => OrderTypeDialog(),
          ),
        );

        // Prima scelta appena fatta: coach-mark sul badge reale, una volta
        // sola. Sostituisce il tutorial preventivo che stava nel dialog.
        _maybeShowOrderTypeHint();
      }
    }
  }

  /// Coach-mark una tantum: indica il badge CONSEGNA/RITIRO come punto
  /// dove cambiare modalita'. Mostrato solo dopo la prima scelta assoluta.
  Future<void> _maybeShowOrderTypeHint() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('order_type_hint_shown') ?? false) return;
    if (!mounted) return;

    final badgeContext = _orderTypeBadgeKey.currentContext;
    if (badgeContext == null) return;

    final renderBox = badgeContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final badgePosition = renderBox.localToGlobal(Offset.zero);
    final badgeSize = renderBox.size;

    OverlayEntry? entry;
    void dismiss() {
      entry?.remove();
      entry = null;
    }

    entry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: dismiss,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: badgePosition.dy + badgeSize.height + 8,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dark,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Da qui passi tra Consegna e Ritiro quando vuoi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(entry!);
    await prefs.setBool('order_type_hint_shown', true);

    // Auto-chiusura se l'utente non tocca nulla
    Future.delayed(const Duration(seconds: 6), dismiss);
  }

  int _previousCartCount = 0;

  void _onCartChanged() {
    if (_cartProvider == null || !mounted) return;
    if (_cartProvider!.itemCount > _previousCartCount) {
      // Prodotto aggiunto - trigghera animazione vibrazione
      _cartShakeController.forward(from: 0);
    }
    _previousCartCount = _cartProvider!.itemCount;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _fcmSubscription?.cancel();
    _pageController.dispose();
    _cartShakeController.dispose();

    // Rimuovi listener dal carrello usando il riferimento salvato
    _cartProvider?.removeListener(_onCartChanged);

    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onScroll(double offset) {
    if (offset > 50 && !_isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = true);
    } else if (offset <= 50 && _isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = false);
    }
  }

  Future<void> _loadCustomerName() async {
    final prefs = await SharedPreferences.getInstance();
    final fullname = prefs.getString(AppConstants.keyUserFullname) ?? 'Utente';
    // Prende solo il nome
    final firstName = fullname.split(' ').first;
    setState(() => _customerName = firstName);
  }

  Future<void> _loadCuisines() async {
    setState(() => _isLoadingCuisines = true);
    try {
      final cuisines = await _cuisineService.getCuisines();
      setState(() {
        _cuisines = cuisines;
        _isLoadingCuisines = false;
      });
    } catch (e) {
      print('❌ Errore caricamento cucine: $e');
      setState(() => _isLoadingCuisines = false);
    }
  }

  void _navigateToCart() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (cartProvider.isEmpty) {
      _showEmptyCartDialog();
    } else {
      // Naviga al carrello
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CartScreen(
            // Scheletro: solo id/nome/logo. Il carrello carica da solo i
            // dati veri (coordinate, tempi) via API — niente "30 min" finti.
            restaurant: Restaurant(
              id: cartProvider.restaurantId!,
              name: cartProvider.restaurantName!,
              cuisine: 'Vario',
              rating: 0.0,
              deliveryTime: '',
              deliveryCost: '€0',
              minOrder: '0',
              imageUrl: '',
              description: '',
              logoUrl: cartProvider.restaurantLogoUrl ?? '',
            ),
            cartItems: cartProvider.items,
          ),
        ),
      );
    }
  }

  void _showEmptyCartDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: accentYellow.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 50,
                  color: warningOrange,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Il tuo carrello è vuoto!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Sembra che tu abbia fame...\nEsplora i ristoranti e ordina qualcosa di buono!',
                style: TextStyle(fontSize: 14, color: grayColor, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDarkPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Scopri i ristoranti',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightColor,
      body: Column(
        children: [
          _buildHeader(),
          // Header compatto sulla tab Ristoranti: spariscono le 3 tab e
          // restano le CATEGORIE cucina, cosi' a meta' di una lista di 40
          // ristoranti si puo' filtrare senza risalire. Le altre tab
          // restano raggiungibili con lo swipe orizzontale (e tornando su).
          if (!(_isHeaderCollapsed && _selectedTab == 0)) _buildSectionNav(),
          if (_selectedTab == 0) _buildCategories(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                // Il collasso dell'header segue la tab VISIBILE: senza questo
                // ricalcolo, arrivando da una tab scrollata la barra di
                // ricerca e le categorie restavano nascoste (schermo "vuoto").
                final offset = _scrollControllers[index].hasClients
                    ? _scrollControllers[index].offset
                    : 0.0;
                setState(() {
                  _selectedTab = index;
                  _isHeaderCollapsed = offset > 50;
                });
              },
              children: [
                RistorantiTab(
                  scrollController: _scrollControllers[0],
                  cuisineId: _selectedCuisineId,
                  searchQuery: _searchQuery,
                  onClearSearch: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  // NIENTE key qui: una ValueKey su cucina+ricerca smontava
                  // lo State a ogni lettera digitata, rifacendo da zero tutte
                  // le chiamate di rete. I cambi filtro passano da
                  // didUpdateWidget dentro RistorantiTab.
                ),
                ScopriTab(
                  scrollController: _scrollControllers[1],
                  // Chip di Scopri (meteo/eventi) → ricerca ristoranti:
                  // imposta la query e torna alla tab Ristoranti.
                  onSearchSuggestion: (query) {
                    if (_scrollControllers[0].hasClients) {
                      _scrollControllers[0].jumpTo(0);
                    }
                    setState(() {
                      _searchController.text = query;
                      _searchQuery = query;
                      _isHeaderCollapsed = false;
                    });
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                PerTeTab(scrollController: _scrollControllers[2]),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildAIAssistant(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final displayAddress = locationProvider.displayAddress;
        final isLoading = locationProvider.isLoadingLocation;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: const BoxDecoration(color: lightColor),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header principale
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Pulsante indietro + Logo/Nome
                      Expanded(
                        child: Row(
                          children: [
                            // Pulsante indietro per tornare alle categorie
                            IconButton(
                              icon: AppIcon(
                                'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
                                width: 22,
                                height: 22,
                                color: darkColor,
                              ),
                              onPressed: () => context.go('/categories'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 10),
                            if (!_isHeaderCollapsed)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  // L'ospite non ha un nome: si saluta senza.
                                  _customerName.isEmpty
                                      ? 'Ciao!'
                                      : 'Ciao, $_customerName',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    // Era rosa acceso, residuo del marchio
                                    // precedente, proprio in cima alla home.
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            if (_isHeaderCollapsed) ...[
                              const SizedBox(width: 10),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Badge tipo ordine - click per cambiare tipo
                                    InkWell(
                                      onTap: () {
                                        // Mostra dialog selezione tipo ordine
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            fullscreenDialog: true,
                                            builder: (context) =>
                                                OrderTypeDialog(),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: locationProvider.isPickup
                                              ? badgePickupColor
                                              : badgeDeliveryColor,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              locationProvider.isPickup
                                                  ? Icons.storefront
                                                  : Icons.delivery_dining,
                                              color: locationProvider.isPickup
                                                  ? darkColor
                                                  : lightColor,
                                              size: 10,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              locationProvider.isPickup
                                                  ? 'RITIRO'
                                                  : 'CONSEGNA',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: locationProvider.isPickup
                                                    ? darkColor
                                                    : lightColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Indirizzo - click per cambiare indirizzo
                                    Expanded(
                                      child: InkWell(
                                        onTap: locationProvider.isDelivery
                                            ? () {
                                                showAddressSelectorBottomSheet(
                                                  context,
                                                );
                                              }
                                            : null,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (locationProvider
                                                .isDelivery) ...[
                                              if (isLoading)
                                                const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              else
                                                const Icon(
                                                  Icons.location_on,
                                                  color: primaryBlue,
                                                  size: 14,
                                                ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  displayAddress.length > 15
                                                      ? '${displayAddress.substring(0, 15)}...'
                                                      : displayAddress,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: darkColor,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ] else
                                              Flexible(
                                                child: Text(
                                                  'Ritiro',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: grayColor,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            const Icon(
                                              Icons.arrow_drop_down,
                                              color: primaryBlue,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Icons
                      Row(
                        children: [
                          // Campanella notifiche
                          Consumer<NotificationProvider>(
                            builder: (context, notifProvider, _) {
                              return Stack(
                                children: [
                                  IconButton(
                                    icon: AppIcon(
                                      'assets/icons/icons8-allarme-32.png',
                                      width: 22,
                                      height: 22,
                                      color: darkColor,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SoloUtenti(
                                            schermata: NotificationsScreen(),
                                            titolo: 'Le tue notifiche',
                                            messaggio:
                                                'Con un account ti avvisiamo a ogni passo del tuo ordine, dalla conferma alla consegna.',
                                            icona: Icons.notifications_none,
                                          ),
                                        ),
                                      ).then((_) {
                                        // Aggiorna count al ritorno
                                        notifProvider.refreshCount();
                                      });
                                    },
                                  ),
                                  if (notifProvider.unreadCount > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 15,
                                        height: 15,
                                        decoration: BoxDecoration(
                                          color: dangerRed,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            notifProvider.unreadCount > 99
                                                ? '99+'
                                                : notifProvider.unreadCount
                                                      .toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          Consumer<CartProvider>(
                            builder: (context, cart, child) {
                              return Stack(
                                children: [
                                  AnimatedBuilder(
                                    animation: _cartShakeAnimation,
                                    builder: (context, child) {
                                      return Transform.translate(
                                        offset: Offset(
                                          math.sin(_cartShakeAnimation.value) *
                                              3,
                                          0,
                                        ),
                                        child: IconButton(
                                          icon: AppIcon(
                                            'assets/icons/icons8-cart-32.png',
                                            width: 22,
                                            height: 22,
                                            color: darkColor,
                                          ),
                                          onPressed: () => _navigateToCart(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (cart.itemCount > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: primaryDarkPink,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            cart.itemCount > 99
                                                ? '99+'
                                                : cart.itemCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search bar e address (nascosti quando collapsed)
                if (!_isHeaderCollapsed) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: lightGrayColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.search, color: grayColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                _searchDebounce?.cancel();
                                _searchDebounce = Timer(
                                  const Duration(milliseconds: 300),
                                  () {
                                    if (mounted) {
                                      setState(() => _searchQuery = value);
                                    }
                                  },
                                );
                              },
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                // "o piatti" rimosso: la ricerca filtra solo
                                // i ristoranti (nome/cucina/descrizione).
                                // Ripristinarlo quando esistera' la ricerca
                                // piatti lato server.
                                hintText: 'Cerca ristoranti...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: grayColor,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                filled: false,
                              ),
                            ),
                          ),
                          // Niente microfono: era un bottone senza funzione.
                          // Torna quando ci sara' la ricerca vocale vera.
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        // 🎯 Badge tipo ordine - click per cambiare
                        InkWell(
                          onTap: () {
                            // Mostra dialog selezione tipo ordine
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (context) => OrderTypeDialog(),
                              ),
                            );
                          },
                          child: Container(
                            key: _orderTypeBadgeKey,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: locationProvider.isPickup
                                  ? badgePickupColor
                                  : badgeDeliveryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  locationProvider.isPickup
                                      ? Icons.storefront
                                      : Icons.delivery_dining,
                                  color: locationProvider.isPickup
                                      ? darkColor
                                      : lightColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  locationProvider.isPickup
                                      ? 'RITIRO'
                                      : 'CONSEGNA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: locationProvider.isPickup
                                        ? darkColor
                                        : lightColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Indirizzo - click per cambiare
                        Expanded(
                          child: InkWell(
                            onTap: locationProvider.isDelivery
                                ? () {
                                    showAddressSelectorBottomSheet(context);
                                  }
                                : null,
                            child: Row(
                              children: [
                                if (locationProvider.isDelivery) ...[
                                  if (isLoading)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.location_on,
                                      color: primaryBlue,
                                      size: 13,
                                    ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      displayAddress,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: darkColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ] else
                                  Expanded(
                                    child: Text(
                                      'Scegli il ristorante che preferisci',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: grayColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: primaryBlue,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        // 🎯 Icona refresh posizione
                        InkWell(
                          onTap: () =>
                              locationProvider.refreshCurrentPosition(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primaryBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: primaryBlue,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategories() {
    if (_isLoadingCuisines) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cuisines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Nessuna categoria disponibile',
            style: TextStyle(color: grayColor),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.transparent,
      child: SizedBox(
        // Casella 66 + spazio + etichetta. La lista ritaglia il proprio
        // riquadro: se resta stretta, taglia l'alone della pastiglia scelta.
        height: 94,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          // Stretto di proposito: e' il passo della lista a decidere quante
          // pastiglie entrano nello schermo, e la sesta deve restare
          // intravedibile per far capire che si scorre.
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: _cuisines.length,
          itemBuilder: (context, index) {
            final cuisine = _cuisines[index];
            // Il colore segue l'id della cucina, non la posizione: cosi'
            // Pizzeria resta della stessa tinta anche se il server cambia
            // l'ordine o ne aggiunge una nuova.
            final coloreCategoria = AppColors.coloreCategoria(cuisine.id);

            final isSelected = _selectedCuisineId == cuisine.id;
            // Nessuna spaziatura aggiuntiva: la casella porta gia' dentro 7px
            // di margine per lato, quindi fra due pastiglie restano 14px anche
            // con le caselle attaccate.
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BlobIconSelector(
                  isSelected: isSelected,
                  selectedColor: coloreCategoria,
                  size: 70,
                  onTap: () {
                    setState(() {
                      // Toggle: se già selezionato, deseleziona (mostra tutti)
                      _selectedCuisineId = isSelected ? null : cuisine.id;
                    });
                  },
                  child: Image.asset(
                    cuisine.getIconAssetPath(),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      // Il fondo e' chiaro in entrambi gli stati: il bianco
                      // di prima sarebbe sparito sulla pastiglia selezionata.
                      return Icon(
                        Icons.restaurant,
                        color: coloreCategoria,
                        size: 27,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  cuisine.name,
                  style: TextStyle(
                    fontSize: 11,
                    // Da selezionata l'etichetta prende il colore pieno
                    // della categoria: rinforza l'anello senza aggiungere
                    // altri elementi grafici.
                    color: isSelected ? coloreCategoria : darkColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionNav() {
    return Row(
      children: [
        _buildSectionTab('Ristoranti', 0),
        _buildSectionTab('Scopri', 1),
        _buildSectionTab('Per te', 2),
      ],
    );
  }

  Widget _buildSectionTab(String title, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedTab = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? primaryBlue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? primaryBlue : grayColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIAssistant() {
    return GestureDetector(
      onTap: () {
        // Apri schermata chat AI
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AIChatScreen()),
        );
      },
      // DISCRETO per scelta di prodotto: l'assistente e' in evidenza ma non
      // sopra il cibo. Tinta unita, niente gradiente ne' glow, ombra card.
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [AppColors.cardShadow],
        ),
        // Icona del set "Lenny Icons": il glifo Font Awesome usato prima era
        // pieno e apparteneva a un'altra famiglia grafica, unico caso nella
        // barra. Questa e' disegnata con la stessa grammatica delle altre
        // (tratto 2px, estremita' tonde, macchia morbida sul fondo).
        child: const AppIcon(
          'assets/icons_svg/lenny-robot.svg',
          size: 24,
          color: lightColor,
          semanticLabel: 'Assistente Lenny',
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    // Il Container con sfondo e ombra sta FUORI dal SafeArea:
    // su iOS l'area dell'home-indicator (≈34pt) viene riempita
    // con lightColor invece di restare bianca/vuota.
    // Su Android padding.bottom=0 → nessuna differenza.
    return Container(
      decoration: BoxDecoration(
        color: lightColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem('assets/icons/icons8-home-32.png', 'Home', 0),
              _buildBottomNavItem(
                'assets/icons/icons8-fattura-32.png',
                'Ordini',
                1,
              ),
              const SizedBox(width: 50), // Spazio per FAB
              _buildBottomNavItem(
                'assets/icons/icons8-romanzo-32.png',
                'Preferiti',
                2,
              ),
              _buildBottomNavItem(
                'assets/icons/icons8-user-male-32.png',
                'Profilo',
                3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(dynamic icon, String label, int index) {
    final isActive = _selectedBottomNav == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedBottomNav = index);
        // Navigazione bottom nav
        if (index == 1) {
          // Ordini - apre live orders screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LiveOrdersScreen()),
          );
        } else if (index == 2) {
          // Preferiti - richiedono un account: sono salvati sul profilo
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SoloUtenti(
                schermata: FavoritesScreen(),
                titolo: 'I tuoi preferiti',
                messaggio:
                    'Crea un account per salvare i ristoranti che ami e ritrovarli al volo.',
                icona: Icons.favorite_border,
              ),
            ),
          );
        } else if (index == 3) {
          // Profilo
          context.push('/profile');
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon is String
              ? AppIcon(
                  icon,
                  size: 20,
                  color: isActive ? primaryBlue : grayColor,
                )
              : Icon(icon, color: isActive ? primaryBlue : grayColor, size: 20),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? primaryBlue : grayColor,
            ),
          ),
        ],
      ),
    );
  }
}
