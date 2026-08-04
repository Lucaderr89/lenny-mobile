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

/// Tab "Ristoranti" - ESATTAMENTE come HTML: Ristoranti in evidenza + Tutti i ristoranti
class RistorantiTab extends StatefulWidget {
  final ScrollController scrollController;
  final int? cuisineId; // Filtro cucina (null = tutti)
  final String searchQuery; // Ricerca per nome o piatti

  const RistorantiTab({
    super.key,
    required this.scrollController,
    this.cuisineId,
    this.searchQuery = '',
  });

  @override
  State<RistorantiTab> createState() => _RistorantiTabState();
}

class _RistorantiTabState extends State<RistorantiTab> {
  // Colori
  static const Color primaryDarkPink = AppColors.primary;
  static const Color accentYellow = Color(0xFFFFD042);
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

  // 🗄️ Master cache — caricata UNA VOLTA senza filtro cucina
  // Il filtro cucina avviene client-side su questi dati
  List<Restaurant> _masterFeatured = [];
  List<Restaurant> _masterNew = [];
  List<Restaurant> _masterAll = [];
  bool _masterCacheLoaded = false;

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
    final cuisineChanged = oldWidget.cuisineId != widget.cuisineId;
    final searchChanged = oldWidget.searchQuery != widget.searchQuery;
    if (cuisineChanged || searchChanged) {
      if (_masterCacheLoaded) {
        // Filtro client-side istantaneo — nessuna chiamata API
        setState(() {
          _featuredRestaurants = _applyFilters(_masterFeatured);
          _newRestaurants = _applyFilters(_masterNew);
          _allRestaurants = _applyFilters(_masterAll);
          _filterRestaurants();
        });
      } else {
        _loadRestaurants();
      }
    }
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
        _masterCacheLoaded = true;

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

    // 🎯 Carica tutte le regole SENZA setState nel loop
    // Raccoglie tutti i risultati e fa UN SOLO setState alla fine
    final futures = restaurants.map((restaurant) async {
      try {
        final rule = await _restaurantService.getDeliveryZoneRule(
          restaurantId: restaurant.id,
          postalCode: postalCode,
          latitude: latitude,
          longitude: longitude,
          subtotal: 1.0,
        );

        if (rule != null) {
          // NON chiamare setState qui - solo modifica i dati
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
      } catch (e) {
        // In caso di errore, lascia i valori null
      }
    }).toList();

    // 🎯 Attendi che TUTTE le regole siano caricate
    await Future.wait(futures);

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
      // Filtra per nome ristorante, cucina o descrizione
      final query = widget.searchQuery.toLowerCase();
      _filteredRestaurants = _allRestaurants.where((restaurant) {
        final nameMatch = restaurant.name.toLowerCase().contains(query);
        final cuisineMatch = restaurant.cuisine.toLowerCase().contains(query);
        final descriptionMatch = restaurant.description.toLowerCase().contains(
          query,
        );
        return nameMatch || cuisineMatch || descriptionMatch;
      }).toList();
    }
  }

  /// 🎯 Ordina ristoranti per distanza (più vicini prima)
  List<Restaurant> _getSortedByDistance() {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final userLat = locationProvider.activeLatitude;
    final userLng = locationProvider.activeLongitude;

    // 🎯 Usa lista filtrata se c'è una ricerca attiva, altrimenti usa tutti
    final restaurantsToUse = widget.searchQuery.isNotEmpty
        ? _filteredRestaurants
        : _allRestaurants;

    // 🎯 FILTRO CONDIZIONALE: solo NON consegnabili esclusi in CONSEGNA
    // null = regole non ancora caricate → ottimisticamente visibile
    final filteredRestaurants = locationProvider.isPickup
        ? restaurantsToUse
        : restaurantsToUse.where((r) => r.isDeliverable != false).toList();

    // Se non abbiamo coordinate utente, mostra i primi 10 ristoranti
    if (userLat == null || userLng == null) {
      return filteredRestaurants.take(10).toList();
    }

    // Separa ristoranti con e senza coordinate
    final restaurantsWithCoords = <Map<String, dynamic>>[];
    final restaurantsWithoutCoords = <Restaurant>[];

    for (var restaurant in filteredRestaurants) {
      if (restaurant.latitude != null &&
          restaurant.longitude != null &&
          restaurant.latitude != 0 &&
          restaurant.longitude != 0) {
        final distance = _calculateDistance(
          userLat,
          userLng,
          restaurant.latitude!,
          restaurant.longitude!,
        );
        restaurantsWithCoords.add({
          'restaurant': restaurant,
          'distance': distance,
        });
      } else {
        restaurantsWithoutCoords.add(restaurant);
      }
    }

    // Ordina quelli con coordinate per distanza
    restaurantsWithCoords.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    // Prendi i primi 10 con coordinate
    final sorted = restaurantsWithCoords
        .take(10)
        .map((item) => item['restaurant'] as Restaurant)
        .toList();

    // Se abbiamo meno di 10, aggiungi quelli senza coordinate per riempire
    if (sorted.length < 10) {
      sorted.addAll(restaurantsWithoutCoords.take(10 - sorted.length));
    }

    // 🆕 Priorità ai ristoranti aperti: aperti prima, chiusi dopo
    return _sortByOpenFirst(sorted);
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

  /// 🎯 Ordina ristoranti per popolarità (rating + ordini)
  List<Restaurant> _getMostLovedRestaurants() {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // 🎯 Usa lista filtrata se c'è una ricerca attiva, altrimenti usa tutti
    final restaurantsToUse = widget.searchQuery.isNotEmpty
        ? _filteredRestaurants
        : _allRestaurants;

    // 🎯 FILTRO CONDIZIONALE: solo NON consegnabili esclusi in CONSEGNA
    // null = regole non ancora caricate → ottimisticamente visibile
    final filteredRestaurants = locationProvider.isPickup
        ? restaurantsToUse
        : restaurantsToUse.where((r) => r.isDeliverable != false).toList();

    final sorted = List<Restaurant>.from(filteredRestaurants);
    sorted.sort((a, b) {
      // Ordina per rating decrescente
      final ratingA = double.tryParse(a.rating.toString()) ?? 0.0;
      final ratingB = double.tryParse(b.rating.toString()) ?? 0.0;
      return ratingB.compareTo(ratingA);
    });
    // 🆕 Priorità ai ristoranti aperti: aperti prima, chiusi dopo
    final withOpenPriority = _sortByOpenFirst(sorted);
    return withOpenPriority.take(10).toList();
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
    return RefreshIndicator(
      onRefresh: () async {
        // Ricarica ristoranti e regole delivery
        await _loadRestaurants();
      },
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
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

          // 🎯 SEZIONE 2: I + vicini (Vicino a me)
          SliverToBoxAdapter(
            child: Consumer<LocationProvider>(
              builder: (context, locationProvider, child) {
                return _buildSection(
                  title: 'I + vicini',
                  iconPath: 'assets/icons/icons8-vicino-a-me-32.png',
                  restaurants: _getSortedByDistance(),
                  showDistance: true,
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

          // 🎯 SEZIONE 4: In evidenza (Premium)
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

          // 🎯 SEZIONE 5: I + amati (Più amati)
          SliverToBoxAdapter(
            child: Consumer<LocationProvider>(
              builder: (context, locationProvider, child) {
                return _buildSection(
                  title: 'I + amati',
                  iconPath: 'assets/icons/icons8-piu_amati-32.png',
                  restaurants: _getMostLovedRestaurants(),
                );
              },
            ),
          ),

          // Padding finale
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
              ? const Center(child: CircularProgressIndicator())
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
        ImageIcon(AssetImage(iconPath), size: 24, color: primaryDarkPink),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: darkColor,
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
      onTap: () async {
        // 🎯 Blocca solo se chiuso oggi (senza orario di apertura)
        // Se opensAt != null, consenti PREORDINE anche se non è ancora aperto
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

        // 🎯 Solo in modalità CONSEGNA mostriamo il dialog di zona non servita
        if (!locationProvider.isPickup && !isDeliverable) {
          _showZoneNotServicedDialog(restaurant);
          return;
        }

        // 🎯 CONTROLLO CARRELLO: Verifica se ci sono prodotti di un altro ristorante
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        if (cartProvider.isNotEmpty &&
            cartProvider.restaurantId != restaurant.id) {
          // Mostra dialog di conflitto carrello
          await showCartConflictDialog(
            context: context,
            currentRestaurantName:
                cartProvider.restaurantName ?? 'un altro ristorante',
            onClearCart: () {
              cartProvider.clearCart();
              // Apri il menu dopo aver svuotato il carrello
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

        // Carrello vuoto o stesso ristorante - apri il menu
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantMenuScreen(restaurant: restaurant),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
                        ? Image.network(
                            restaurant.imageUrl,
                            width: 200,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 200,
                                  height: 110,
                                  color: lightGrayColor,
                                  child: const Icon(
                                    Icons.restaurant,
                                    size: 40,
                                    color: grayColor,
                                  ),
                                ),
                          )
                        : Container(
                            width: 200,
                            height: 110,
                            color: lightGrayColor,
                            child: const Icon(
                              Icons.restaurant,
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
                          const Icon(
                            Icons.near_me,
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
                          const Icon(
                            Icons.local_offer,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Gratis da €${restaurant.actualFreeOver!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10,
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
                        color: Colors.black.withOpacity(0.5),
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
                                Image.asset(
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
                                fontSize: 10,
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
                        color: Colors.black.withOpacity(0.5),
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
                          color: const Color(0xFFB71C1C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
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
                        color: Colors.black.withOpacity(0.5),
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
                      const SizedBox(width: 4),
                      const ImageIcon(
                        AssetImage('assets/icons/icons8-stella-32.png'),
                        size: 11,
                        color: accentYellow,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '4.5',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: darkColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Cucina
                  Row(
                    children: [
                      const ImageIcon(
                        AssetImage('assets/icons/icons8-ristorante-32.png'),
                        size: 10,
                        color: grayColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.cuisine,
                          style: const TextStyle(
                            fontSize: 10,
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
                                  fontSize: 10,
                                  color: grayColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              const ImageIcon(
                                AssetImage(
                                  'assets/icons/icons8-in-transito-32.png',
                                ),
                                size: 10,
                                color: grayColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                deliveryFeeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: deliveryFeeText == 'Gratis'
                                      ? AppColors.success
                                      : grayColor,
                                ),
                              ),
                              if (restaurant.actualMinOrder != null &&
                                  restaurant.actualMinOrder! > 0) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.shopping_basket,
                                  size: 10,
                                  color: grayColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Min €${restaurant.actualMinOrder!.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 10,
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
                  color: primaryDarkPink.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const ImageIcon(
                  AssetImage('assets/icons/icons8-marcatore-spento-32.png'),
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
