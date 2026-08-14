import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'package:provider/provider.dart';
import '../restaurant_menu_screen.dart';
import '../../models/restaurant.dart';
import '../../services/restaurant_service.dart';
import '../../providers/location_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cart_conflict_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/foto_rete.dart';
import '../../widgets/scheletro.dart';

/// Tab "Ristoranti" - ESATTAMENTE come HTML: Ristoranti in evidenza + Tutti i ristoranti
class RistorantiTab extends StatefulWidget {
  final ScrollController scrollController;
  final int? cuisineId; // Filtro cucina (null = tutti)
  final String searchQuery; // Ricerca per nome o piatti
  final VoidCallback? onClearSearch; // Azzera la ricerca (campo in HomeScreen)

  const RistorantiTab({
    super.key,
    required this.scrollController,
    this.cuisineId,
    this.searchQuery = '',
    this.onClearSearch,
  });

  @override
  State<RistorantiTab> createState() => _RistorantiTabState();
}

class _RistorantiTabState extends State<RistorantiTab>
    with AutomaticKeepAliveClientMixin {
  // Il tab resta vivo nel PageView: cambiare tab non deve rifare
  // tutte le chiamate di rete a ogni ritorno.
  @override
  bool get wantKeepAlive => true;

  // Colori
  static const Color primaryDarkPink = AppColors.primary; // TODO F4: rinominare
  static const Color accentYellow = AppColors.accent;
  static const Color darkColor = AppColors.dark;
  static const Color lightColor = Color(0xFFFFFFFF);
  static const Color grayColor = AppColors.grayDark;
  static const Color lightGrayColor = AppColors.grayLight;

  final RestaurantService _restaurantService = RestaurantService();
  // Liste filtrate per la UI (dipendono da cuisineId attivo)
  List<Restaurant> _featuredRestaurants = [];
  List<Restaurant> _newRestaurants = [];
  List<Restaurant> _allRestaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  bool _isLoadingFeatured = true;

  // 🗄️ Master data dell'ultimo caricamento (gia' filtrati per cucina
  // dall'API). La ricerca testuale filtra client-side su questi.
  List<Restaurant> _masterFeatured = [];
  List<Restaurant> _masterNew = [];
  List<Restaurant> _masterAll = [];

  // 🎯 Cache per tracciare l'ultima posizione per cui abbiamo caricato le regole
  String? _lastLoadedPostalCode;
  double? _lastLoadedLatitude;
  double? _lastLoadedLongitude;
  bool _isReloadingRules = false;

  // 🔧 Riferimento al LocationProvider per dispose sicuro
  LocationProvider? _locationProvider;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();

    // 🎯 Salva il riferimento al LocationProvider e aggiungi listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locationProvider = Provider.of<LocationProvider>(context, listen: false);
      _locationProvider!.addListener(_onLocationChanged);
    });
  }

  @override
  void dispose() {
    // 🔧 Usa il riferimento salvato invece di Provider.of(context)
    _locationProvider?.removeListener(_onLocationChanged);
    super.dispose();
  }

  /// 🎯 Callback quando cambia posizione o tipo ordine
  void _onLocationChanged() {
    if (mounted) {
      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );

      // 🎯 Controlla se è cambiata la posizione (CAP, lat, lng)
      final hasLocationChanged =
          _lastLoadedPostalCode != locationProvider.activePostalCode ||
          _lastLoadedLatitude != locationProvider.activeLatitude ||
          _lastLoadedLongitude != locationProvider.activeLongitude;

      if (hasLocationChanged) {
        // Ricarica forzatamente per la nuova posizione
        _reloadDeliveryRules(forceReload: true);
      } else {
        // Solo aggiorna UI senza ricaricare
        if (mounted) setState(() {});
      }
    }
  }

  /// 🔄 Ricarica solo le regole di consegna senza ricaricare i ristoranti
  Future<void> _reloadDeliveryRules({bool forceReload = false}) async {
    if (_masterAll.isEmpty) return;
    // masterAll è la fonte autorevole (contiene tutti i ristoranti)
    await _loadDeliveryZoneRules(_masterAll, forceReload: forceReload);
    // Sincronizza i dati di consegna agli altri master (oggetti diversi in memoria)
    _syncDeliveryFromAll();
    if (mounted) setState(() {});
  }

  /// Sincronizza dati consegna da masterAll → masterFeatured e masterNew.
  /// Necessario perché le 3 chiamate API creano oggetti Dart separati per lo stesso ID.
  void _syncDeliveryFromAll() {
    final byId = {for (final r in _masterAll) r.id: r};
    for (final list in [_masterFeatured, _masterNew]) {
      for (final r in list) {
        final src = byId[r.id];
        if (src != null && src != r) {
          r.isDeliverable = src.isDeliverable;
          r.actualDeliveryFee = src.actualDeliveryFee;
          r.actualMinOrder = src.actualMinOrder;
          r.actualFreeOver = src.actualFreeOver;
          r.freeDelivery = src.freeDelivery;
        }
      }
    }
  }

  @override
  void didUpdateWidget(RistorantiTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Da qui passa OGNI cambio di filtro (niente piu' ValueKey che smontava
    // lo State: prima ogni lettera digitata rifaceva 3+N chiamate di rete).
    final cuisineChanged = oldWidget.cuisineId != widget.cuisineId;
    final searchChanged = oldWidget.searchQuery != widget.searchQuery;

    if (cuisineChanged) {
      // Il filtro cucina lo applica l'API: una ricarica per tap categoria
      _loadRestaurants();
    } else if (searchChanged) {
      // Filtro locale immediato (nome/cucina/descrizione), poi il server
      // aggiunge i ristoranti che hanno la parola NEL MENU: i chip di
      // Scopri suggeriscono cibi, e "frullati" non e' il nome di nessuno.
      setState(_filterRestaurants);
      _cercaAncheNeiPiatti(widget.searchQuery);
    }
  }

  // Ristoranti trovati dal server per piatto (merge coi risultati locali)
  Set<int> _dishMatchIds = {};
  bool _cercandoPiatti = false;

  Future<void> _cercaAncheNeiPiatti(String query) async {
    if (query.length < 2) {
      if (_dishMatchIds.isNotEmpty && mounted) {
        setState(() {
          _dishMatchIds = {};
          _filterRestaurants();
        });
      }
      return;
    }

    setState(() => _cercandoPiatti = true);
    final ids = await _restaurantService.searchRestaurantsByDish(query);
    // La query puo' essere cambiata mentre la richiesta era in volo
    if (!mounted || widget.searchQuery != query) return;

    setState(() {
      _cercandoPiatti = false;
      _dishMatchIds = ids;
      _filterRestaurants();
    });
  }

  /// Applica filtro cucina e ricerca sui master data (client-side, nessuna API)
  List<Restaurant> _applyFilters(List<Restaurant> source) {
    // La cucina è filtrata dall'API (cuisineId nel parametro chiamata)
    // Questo metodo resta per eventuali filtri client-side futuri
    return source;
  }

  Future<void> _loadRestaurants() async {
    if (mounted) setState(() => _isLoadingFeatured = true);

    try {
      // 🚀 Carica CON filtro cucina dall'API (affidabile, nessun problema di type mismatch)
      final results = await Future.wait([
        _restaurantService.getFeaturedRestaurants(cuisineId: widget.cuisineId),
        _restaurantService.getNewRestaurants(cuisineId: widget.cuisineId),
        _restaurantService.getRestaurants(cuisineId: widget.cuisineId),
      ]);

      if (mounted) {
        _masterFeatured = results[0];
        _masterNew = results[1];
        _masterAll = results[2];

        setState(() {
          _featuredRestaurants = _applyFilters(_masterFeatured);
          _newRestaurants = _applyFilters(_masterNew);
          _allRestaurants = _applyFilters(_masterAll);
          _isLoadingFeatured = false;
          _filterRestaurants();
        });

        // 🎯 Carica delivery zone rules SOLO su masterAll (contiene tutti i ristoranti)
        // masterNew e masterFeatured sono sottoinsiemi con oggetti Dart DIVERSI:
        // i valori vanno sincronizzati esplicitamente dopo il caricamento.
        _loadDeliveryZoneRules(_masterAll).then((_) {
          _syncDeliveryFromAll();
          if (mounted) setState(() {});
        });
      }
    } catch (e) {
      print('❌ Errore caricamento ristoranti: $e');
      if (mounted) setState(() => _isLoadingFeatured = false);
    }
  }

  /// 🆕 Carica le delivery zone rules per una lista di ristoranti
  /// Carica SEMPRE in background, anche in modalità RITIRO (per cache)
  Future<void> _loadDeliveryZoneRules(
    List<Restaurant> restaurants, {
    bool forceReload = false,
  }) async {
    if (restaurants.isEmpty) return;
    if (!mounted) return;

    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final postalCode = locationProvider.activePostalCode;
    final latitude = locationProvider.activeLatitude;
    final longitude = locationProvider.activeLongitude;

    if (postalCode == null && (latitude == null || longitude == null)) {
      return;
    }

    // 🎯 Controlla se le regole sono già caricate per questa posizione
    // Skip solo se NON è forzato il ricaricamento
    if (!forceReload) {
      final alreadyLoaded =
          restaurants.isNotEmpty && restaurants.first.isDeliverable != null;

      if (alreadyLoaded) {
        if (mounted) setState(() {});
        return;
      }
    } else {
      // 🧹 RESET tutti i valori delivery per evitare cache stale
      for (final restaurant in restaurants) {
        restaurant.isDeliverable = null;
        restaurant.actualDeliveryFee = null;
        restaurant.actualMinOrder = null;
        restaurant.actualFreeOver = null;
        restaurant.freeDelivery = false;
      }
    }

    // 🔧 Check mounted prima di setState
    if (!mounted) return;
    setState(() => _isReloadingRules = true);

    // 🎯 Salva la posizione attuale nella cache
    _lastLoadedPostalCode = postalCode;
    _lastLoadedLatitude = latitude;
    _lastLoadedLongitude = longitude;

    // UNA richiesta batch per tutte le regole: prima era una chiamata
    // per OGNI ristorante (N+1) a ogni caricamento della home.
    try {
      final rules = await _restaurantService.getDeliveryZoneRulesBatch(
        restaurantIds: restaurants.map((r) => r.id).toList(),
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
        subtotal: 1.0,
      );

      if (rules != null) {
        for (final restaurant in restaurants) {
          final rule = rules[restaurant.id];
          if (rule == null) continue;

          restaurant.isDeliverable = rule['is_deliverable'] as bool? ?? false;
          restaurant.actualDeliveryFee = (rule['delivery_fee'] as num?)
              ?.toDouble();
          restaurant.actualMinOrder = (rule['min_order'] as num?)?.toDouble();

          // 🎯 Controlla entrambi i campi free_over e free_delivery_from
          final freeOverValue = rule['free_over'] ?? rule['free_delivery_from'];

          restaurant.actualFreeOver = freeOverValue != null
              ? (freeOverValue as num).toDouble()
              : null;

          restaurant.freeDelivery = rule['free_delivery'] as bool? ?? false;
        }
      }
    } catch (e) {
      // In caso di errore, lascia i valori null
    }

    // 🎯 UN SOLO setState alla fine - aggiornamento ISTANTANEO
    if (mounted) {
      setState(() => _isReloadingRules = false);
    }
  }

  void _filterRestaurants() {
    if (widget.searchQuery.isEmpty) {
      // Nessuna ricerca - mostra tutti i ristoranti
      _filteredRestaurants = _allRestaurants;
    } else {
      // Filtra per nome ristorante, cucina o descrizione, PIU' i
      // ristoranti che hanno la parola nel menu (match server-side)
      final query = widget.searchQuery.toLowerCase();
      _filteredRestaurants = _allRestaurants.where((restaurant) {
        final nameMatch = restaurant.name.toLowerCase().contains(query);
        final cuisineMatch = restaurant.cuisine.toLowerCase().contains(query);
        final descriptionMatch = restaurant.description.toLowerCase().contains(
          query,
        );
        final dishMatch = _dishMatchIds.contains(restaurant.id);
        return nameMatch || cuisineMatch || descriptionMatch || dishMatch;
      }).toList();
    }
  }

  /// 🎯 Ordina ristoranti per distanza (più vicini prima)
  /// Feed "Tutti i ristoranti": IL catalogo completo, senza take(10).
  /// Ricerca applicata, non consegnabili esclusi in modalita' consegna,
  /// aperti prima, ordinati per distanza (chi non ha coordinate in coda).
  List<Restaurant> _getAllRestaurantsForFeed() {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final restaurantsToUse = widget.searchQuery.isNotEmpty
        ? _filteredRestaurants
        : _allRestaurants;

    // null = regole non ancora caricate → ottimisticamente visibile
    final filtered = locationProvider.isPickup
        ? List<Restaurant>.from(restaurantsToUse)
        : restaurantsToUse.where((r) => r.isDeliverable != false).toList();

    final userLat = locationProvider.activeLatitude;
    final userLng = locationProvider.activeLongitude;

    if (userLat != null && userLng != null) {
      double distanza(Restaurant r) {
        if (r.latitude == null ||
            r.longitude == null ||
            r.latitude == 0 ||
            r.longitude == 0) {
          return double.maxFinite; // senza coordinate: in fondo
        }
        return _calculateDistance(userLat, userLng, r.latitude!, r.longitude!);
      }

      filtered.sort((a, b) => distanza(a).compareTo(distanza(b)));
    }

    return _sortByOpenFirst(filtered);
  }

  /// Apre il menu di un ristorante con tutti i controlli del caso:
  /// chiuso oggi, zona non servita (solo consegna), conflitto carrello.
  /// Unico punto di ingresso per card compatte e feed verticale.
  Future<void> _openRestaurantMenu(Restaurant restaurant) async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final isOpenNow = restaurant.isOpenNow ?? true;
    final opensAt = restaurant.opensAt;
    final isDeliverable = restaurant.isDeliverable != false;

    // Blocca solo se chiuso oggi (senza orario di apertura).
    // Se opensAt != null, consenti PREORDINE anche se non è ancora aperto.
    if (!isOpenNow && opensAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Il ristorante è chiuso oggi'),
          backgroundColor: primaryDarkPink,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Solo in modalità CONSEGNA mostriamo il dialog di zona non servita
    if (!locationProvider.isPickup && !isDeliverable) {
      _showZoneNotServicedDialog(restaurant);
      return;
    }

    // CONTROLLO CARRELLO: prodotti di un altro ristorante?
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.isNotEmpty && cartProvider.restaurantId != restaurant.id) {
      await showCartConflictDialog(
        context: context,
        currentRestaurantName:
            cartProvider.restaurantName ?? 'un altro ristorante',
        onClearCart: () {
          cartProvider.clearCart();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RestaurantMenuScreen(restaurant: restaurant),
            ),
          );
        },
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMenuScreen(restaurant: restaurant),
      ),
    );
  }

  /// � Ordina ristoranti mettendo prima quelli aperti, poi quelli chiusi
  /// Mantiene l'ordinamento interno di ciascun gruppo
  List<Restaurant> _sortByOpenFirst(List<Restaurant> restaurants) {
    final open = <Restaurant>[];
    final closed = <Restaurant>[];

    for (final restaurant in restaurants) {
      // isOpenNow: true = aperto, false/null = chiuso
      if (restaurant.isOpenNow == true) {
        open.add(restaurant);
      } else {
        closed.add(restaurant);
      }
    }

    // Ritorna: prima tutti gli aperti, poi tutti i chiusi
    return [...open, ...closed];
  }

  /// �🎯 Calcola distanza in km usando formula Haversine
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

  /// Card full-width del feed "Tutti i ristoranti": foto grande che vende,
  /// stato apertura e costi di consegna nella stessa card.
  Widget _buildFullWidthCard(Restaurant restaurant) {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final isOpenNow = restaurant.isOpenNow ?? true;
    final opensAt = restaurant.opensAt;
    final isDeliverable = restaurant.isDeliverable != false;
    final available = locationProvider.isPickup
        ? isOpenNow
        : (isDeliverable && isOpenNow);

    final deliveryFeeText = restaurant.freeDelivery == true
        ? 'Gratis'
        : restaurant.actualDeliveryFee != null
        ? '€${restaurant.actualDeliveryFee!.toStringAsFixed(2)}'
        : null;

    String? distanceText;
    final userLat = locationProvider.activeLatitude;
    final userLng = locationProvider.activeLongitude;
    if (userLat != null &&
        userLng != null &&
        restaurant.latitude != null &&
        restaurant.longitude != null &&
        restaurant.latitude != 0 &&
        restaurant.longitude != 0) {
      final d = _calculateDistance(
        userLat,
        userLng,
        restaurant.latitude!,
        restaurant.longitude!,
      );
      distanceText = '${d.toStringAsFixed(1)} km';
    }

    return GestureDetector(
      onTap: () => _openRestaurantMenu(restaurant),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto grande 16:9 con stato sovraimpresso
            Stack(
              children: [
                Opacity(
                  opacity: available ? 1.0 : 0.55,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: restaurant.imageUrl.isNotEmpty
                          ? FotoRete(
                              restaurant.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: lightGrayColor,
                                child: const AppIcon(
                                  'assets/icons_svg/icons8-ristorante-32.svg',
                                  size: 40,
                                  color: grayColor,
                                ),
                              ),
                            )
                          : Container(
                              color: lightGrayColor,
                              child: const AppIcon(
                                'assets/icons_svg/icons8-ristorante-32.svg',
                                size: 40,
                                color: grayColor,
                              ),
                            ),
                    ),
                  ),
                ),

                // Chiuso ora: riapertura o chiuso oggi
                if (!isOpenNow)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: opensAt != null
                                ? primaryDarkPink
                                : AppColors.danger,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            opensAt != null
                                ? 'Apre alle $opensAt · Preordina'
                                : 'Chiuso oggi',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Distanza in alto a destra
                if (distanceText != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryDarkPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        distanceText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Consegna gratis sopra soglia
                if (!locationProvider.isPickup &&
                    restaurant.actualFreeOver != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Gratis da €${restaurant.actualFreeOver!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Testi
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: darkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (restaurant.rating > 0) ...[
                        const SizedBox(width: 6),
                        AppIcon(
                          'assets/icons/icons8-stella-32.png',
                          size: 12,
                          color: accentYellow,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: darkColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    restaurant.cuisine,
                    style: const TextStyle(fontSize: 11, color: grayColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!locationProvider.isPickup &&
                      deliveryFeeText != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const AppIcon(
                          'assets/icons_svg/lenny-consegna.svg',
                          size: 13,
                          color: grayColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Consegna $deliveryFeeText',
                          style: const TextStyle(
                            fontSize: 11,
                            color: grayColor,
                          ),
                        ),
                        if (restaurant.actualMinOrder != null &&
                            restaurant.actualMinOrder! > 0) ...[
                          const SizedBox(width: 10),
                          Text(
                            'Min €${restaurant.actualMinOrder!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: grayColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 Filtra ristoranti nuovi (ordinati per updated_at da backend)
  List<Restaurant> _getNewRestaurants() {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // 🎯 Usa lista novità (già ordinata per updated_at dal backend)
    final restaurantsToUse = widget.searchQuery.isNotEmpty
        ? _filteredRestaurants
        : _newRestaurants;

    // 🎯 FILTRO CONDIZIONALE: solo NON consegnabili esclusi in CONSEGNA
    // null = regole non ancora caricate → ottimisticamente visibile
    final filteredRestaurants = locationProvider.isPickup
        ? restaurantsToUse
        : restaurantsToUse.where((r) => r.isDeliverable != false).toList();

    // 🆕 Priorità ai ristoranti aperti: aperti prima, chiusi dopo
    final withOpenPriority = _sortByOpenFirst(filteredRestaurants);
    return withOpenPriority.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // richiesto da AutomaticKeepAliveClientMixin
    return RefreshIndicator(
      onRefresh: () async {
        // Ricarica ristoranti e regole delivery
        await _loadRestaurants();
      },
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          // Con la ricerca attiva le sezioni editoriali spariscono: resta solo
          // il feed dei risultati (o lo stato vuoto). Prima una ricerca senza
          // match nascondeva TUTTE le sezioni e la tab restava bianca.
          if (widget.searchQuery.isEmpty) ...[
            // 🎯 SEZIONE 1: Offerte in corso (Sconto)
            // Senza emptyMessage la sezione SPARISCE finché non c'è nulla da
            // mostrare, invece di presentare un titolo con sotto "nessuna offerta".
            // La logica offerte non è ancora implementata: la lista resta vuota e
            // la sezione non occupa spazio, così la home non appare mai povera.
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Offerte in corso',
                iconPath: 'assets/icons/icons8-sconto-32.png',
                restaurants: const [], // TODO: logica coupon/offerte
              ),
            ),

            // 🎯 SEZIONE 2: In evidenza (Premium)
            SliverToBoxAdapter(
              child: Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  // 🎯 FILTRO CONDIZIONALE: solo NON consegnabili esclusi in CONSEGNA
                  // null = regole non ancora caricate → ottimisticamente visibile
                  final filteredFeatured = locationProvider.isPickup
                      ? _featuredRestaurants
                      : _featuredRestaurants
                            .where((r) => r.isDeliverable != false)
                            .toList();

                  // 🆕 Priorità ai ristoranti aperti: aperti prima, chiusi dopo
                  final sortedFeatured = _sortByOpenFirst(filteredFeatured);

                  return _buildSection(
                    title: 'In evidenza',
                    iconPath: 'assets/icons/icons8-premium-32.png',
                    restaurants: sortedFeatured,
                    isLoading: _isLoadingFeatured,
                  );
                },
              ),
            ),

            // 🎯 SEZIONE 3: Novità (News)
            SliverToBoxAdapter(
              child: Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  return _buildSection(
                    title: 'Novità',
                    iconPath: 'assets/icons/icons8-news-32.png',
                    restaurants: _getNewRestaurants(),
                  );
                },
              ),
            ),
          ],

          // 🎯 SEZIONE 4: TUTTI I RISTORANTI — feed verticale completo.
          // Prima la home era solo caroselli cappati a 10 ("I + vicini",
          // "I + amati"...) che mostravano gli stessi locali con etichette
          // diverse: un ristorante fuori dai primi 10 era irraggiungibile.
          // Qui c'e' TUTTO il catalogo, aperti prima, ordinato per distanza.
          SliverToBoxAdapter(
            child: Consumer<LocationProvider>(
              builder: (context, locationProvider, child) {
                final all = _getAllRestaurantsForFeed();
                if (all.isEmpty && !_isLoadingFeatured) {
                  if (widget.searchQuery.isNotEmpty) {
                    // Il server sta ancora cercando nei menu: niente
                    // "nessun risultato" prematuro
                    if (_cercandoPiatti) {
                      return const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: primaryDarkPink,
                          ),
                        ),
                      );
                    }
                    return _buildSearchEmptyState();
                  }
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: _buildSectionHeader(
                    // "Risultati" generico: la query la scrive il cliente
                    // e puo' essere lunga quanto vuole, niente overflow
                    widget.searchQuery.isNotEmpty
                        ? 'Risultati'
                        : 'Tutti i ristoranti',
                    'assets/icons/icons8-ristorante-32.png',
                  ),
                );
              },
            ),
          ),
          SliverList.builder(
            itemCount: _getAllRestaurantsForFeed().length,
            itemBuilder: (context, index) {
              final restaurant = _getAllRestaurantsForFeed()[index];
              return _buildFullWidthCard(restaurant);
            },
          ),

          // Padding finale
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  /// Stato vuoto della ricerca: senza questo, una query senza match
  /// lasciava la tab completamente bianca.
  Widget _buildSearchEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 20),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 48, color: grayColor),
          const SizedBox(height: 14),
          Text(
            'Nessun risultato per "${widget.searchQuery}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Abbiamo cercato tra ristoranti, cucine e piatti dei menu. '
            'Prova con un\'altra parola.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: grayColor),
          ),
          const SizedBox(height: 16),
          if (widget.onClearSearch != null)
            OutlinedButton(
              onPressed: widget.onClearSearch,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryDarkPink,
                side: const BorderSide(color: primaryDarkPink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text('Cancella ricerca'),
            ),
        ],
      ),
    );
  }

  /// 🎯 Widget generico per sezione ristoranti
  Widget _buildSection({
    required String title,
    required String iconPath,
    required List<Restaurant> restaurants,
    bool isLoading = false,
    bool showDistance = false,
    String? emptyMessage,
  }) {
    // Nascondi sezione se vuota e non in loading
    if (!isLoading && restaurants.isEmpty) {
      if (emptyMessage != null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(title, iconPath),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  emptyMessage,
                  style: const TextStyle(
                    fontSize: 13,
                    color: grayColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: _buildSectionHeader(title, iconPath),
        ),
        SizedBox(
          height: 200, // Card compatte
          child: isLoading
              // Segnaposto con la forma delle schede al posto della rotella:
              // la fila si vede subito e non c'e' salto quando arrivano i dati.
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
                  itemCount: 3,
                  itemBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: ScheletroScheda(width: 160, altezzaFoto: 110),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    final restaurant = restaurants[index];
                    return _buildCompactCard(
                      restaurant: restaurant,
                      showDistance: showDistance,
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 🎯 Header sezione con icona e titolo
  Widget _buildSectionHeader(String title, String iconPath) {
    return Row(
      children: [
        AppIcon(iconPath, size: 24, color: primaryDarkPink),
        const SizedBox(width: 8),
        // Expanded + ellipsis: 'Risultati per "<parola lunga>"' sfondava
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),
        ),
      ],
    );
  }

  /// 🎯 Card ristorante compatta (200x200)
  Widget _buildCompactCard({
    required Restaurant restaurant,
    bool showDistance = false,
  }) {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Calcola distanza se richiesto
    double? distance;
    if (showDistance) {
      final userLat = locationProvider.activeLatitude;
      final userLng = locationProvider.activeLongitude;
      if (userLat != null &&
          userLng != null &&
          restaurant.latitude != null &&
          restaurant.longitude != null &&
          restaurant.latitude != 0 &&
          restaurant.longitude != 0) {
        distance = _calculateDistance(
          userLat,
          userLng,
          restaurant.latitude!,
          restaurant.longitude!,
        );
      }
    }

    final isDeliverable = restaurant.isDeliverable != false;
    final deliveryFeeText = restaurant.freeDelivery == true
        ? 'Gratis'
        : '€${restaurant.actualDeliveryFee?.toStringAsFixed(2) ?? '0.00'}';

    // 🎯 Determina se il ristorante è disponibile
    // Se il backend non ha info (null), assumiamo APERTO per non nascondere erroneamente
    final isOpenNow = restaurant.isOpenNow ?? true;
    final opensAt = restaurant.opensAt; // "HH:MM" o null

    // 🎯 In modalità RITIRO, non controlliamo se è consegnabile
    // Ma oscuriamo se è chiuso
    final shouldShowAsAvailable = locationProvider.isPickup
        ? isOpenNow
        : (isDeliverable && isOpenNow);

    return GestureDetector(
      onTap: () => _openRestaurantMenu(restaurant),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Immagine
            Stack(
              children: [
                Opacity(
                  opacity: shouldShowAsAvailable ? 1.0 : 0.5,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: restaurant.imageUrl.isNotEmpty
                        ? FotoRete(
                            restaurant.imageUrl,
                            width: 200,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 200,
                                  height: 110,
                                  color: lightGrayColor,
                                  child: const AppIcon(
                                    'assets/icons_svg/icons8-ristorante-32.svg',
                                    size: 40,
                                    color: grayColor,
                                  ),
                                ),
                          )
                        : Container(
                            width: 200,
                            height: 110,
                            color: lightGrayColor,
                            child: const AppIcon(
                              'assets/icons_svg/icons8-ristorante-32.svg',
                              size: 40,
                              color: grayColor,
                            ),
                          ),
                  ),
                ),
                // Badge distanza
                if (showDistance && distance != null && shouldShowAsAvailable)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryDarkPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(
                            'assets/icons_svg/icons8-mirino-32.svg',
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distance >= 1
                                ? '${distance.toStringAsFixed(1)} km'
                                : '${(distance * 1000).round()} m',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Badge consegna gratuita sopra (solo in modalità CONSEGNA)
                if (!locationProvider.isPickup &&
                    shouldShowAsAvailable &&
                    restaurant.actualFreeOver != null &&
                    restaurant.actualFreeOver! > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(
                            'assets/icons_svg/icons8-sconto-32.svg',
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Gratis da €${restaurant.actualFreeOver!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 🆕 Overlay nero per ristoranti chiusi
                if (!isOpenNow && opensAt != null)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                // 🆕 Badge "Apre alle HH:MM" + PREORDINA in primo piano
                if (!isOpenNow && opensAt != null)
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryDarkPink,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  'assets/icons/icons8-orologio-32.png',
                                  width: 12,
                                  height: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Apre alle $opensAt',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentYellow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PREORDINA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: darkColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 🆕 Overlay nero per ristoranti chiusi oggi
                if (!isOpenNow && opensAt == null)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                // 🆕 Badge "Chiuso oggi" in primo piano
                if (!isOpenNow && opensAt == null)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              'assets/icons/icons8-cancella-32.png',
                              width: 12,
                              height: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Chiuso oggi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Overlay zona non servita (solo in modalità CONSEGNA)
                if (!locationProvider.isPickup && !isDeliverable && isOpenNow)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Zona non consegnabile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Dettagli
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome e rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: darkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Stella solo con un rating reale: senza recensioni
                      // non si mostra nulla, mai un numero inventato.
                      if (restaurant.rating > 0) ...[
                        const SizedBox(width: 4),
                        AppIcon(
                          'assets/icons/icons8-stella-32.png',
                          size: 11,
                          color: accentYellow,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: darkColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Cucina
                  Row(
                    children: [
                      AppIcon(
                        'assets/icons/icons8-ristorante-32.png',
                        size: 10,
                        color: grayColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.cuisine,
                          style: const TextStyle(
                            fontSize: 11,
                            color: grayColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Costo consegna e minimo ordine (solo in modalità CONSEGNA)
                  if (!locationProvider.isPickup)
                    _isReloadingRules
                        ? Row(
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: primaryDarkPink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Un attimo...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: grayColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              AppIcon(
                                'assets/icons/icons8-in-transito-32.png',
                                size: 10,
                                color: grayColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                deliveryFeeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: deliveryFeeText == 'Gratis'
                                      ? AppColors.success
                                      : grayColor,
                                ),
                              ),
                              if (restaurant.actualMinOrder != null &&
                                  restaurant.actualMinOrder! > 0) ...[
                                const SizedBox(width: 8),
                                const AppIcon(
                                  'assets/icons_svg/icons8-basket-2-32.svg',
                                  size: 10,
                                  color: grayColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Min €${restaurant.actualMinOrder!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: grayColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🆕 Dialog friendly per zona non servita
  void _showZoneNotServicedDialog(Restaurant restaurant) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icona
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryDarkPink.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  'assets/icons/icons8-marcatore-spento-32.png',
                  size: 48,
                  color: primaryDarkPink,
                ),
              ),
              const SizedBox(height: 20),
              // Titolo
              const Text(
                'Zona non servita',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Messaggio
              Text(
                'Siamo spiacenti, ma ${restaurant.name} non effettua consegne nella tua zona attuale.',
                style: const TextStyle(
                  fontSize: 14,
                  color: grayColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Bottone
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
                    'Ho capito',
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
}
