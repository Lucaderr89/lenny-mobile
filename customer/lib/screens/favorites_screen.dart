import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../models/favorite.dart';
import '../models/restaurant.dart';
import '../services/restaurant_service.dart';
import 'restaurant_menu_screen.dart';

/// Screen Preferiti - Lista ristoranti e piatti preferiti raggruppati
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const Color primaryColor = AppColors.primary;
  static const Color darkColor = AppColors.dark;
  static const Color grayColor = AppColors.gray;
  static const Color lightGrayColor = AppColors.lightGray;

  // Stato locale per espansione card
  final Set<int> _expandedRestaurants = {};

  final RestaurantService _restaurantService = RestaurantService();

  /// Apre il menu del ristorante coi dati REALI (rating, consegna, orari).
  /// Con [dishId] apre direttamente la scheda di quel piatto.
  /// Se il dettaglio non e' raggiungibile si ripiega sui dati minimi
  /// dei preferiti, cosi' la navigazione non si blocca mai.
  Future<void> _openRestaurant(
    RestaurantBasic basic, {
    int? dishId,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: primaryColor)),
    );

    Restaurant? restaurant;
    try {
      restaurant = await _restaurantService.getRestaurantDetail(basic.id);
    } catch (_) {
      restaurant = null;
    }

    if (!mounted) return;
    Navigator.pop(context); // chiudi loading

    restaurant ??= Restaurant(
      id: basic.id,
      name: basic.name,
      description: basic.description ?? '',
      imageUrl: basic.imageUrl ?? '',
      rating: 0.0,
      deliveryTime: '',
      deliveryCost: '',
      cuisine: '',
      minOrder: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMenuScreen(
          restaurant: restaurant!,
          openDishId: dishId,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Carica i preferiti all'apertura dello screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FavoritesProvider>(context, listen: false).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        toolbarHeight: 56,
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
            width: 24,
            height: 24,
            color: AppColors.dark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'I miei preferiti',
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dark),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/icons/icons8-aggiornamenti-disponibili-32.png',
              width: 22,
              height: 22,
              color: AppColors.dark,
            ),
            onPressed: () {
              Provider.of<FavoritesProvider>(
                context,
                listen: false,
              ).loadFavorites(forceRefresh: true);
            },
          ),
        ],
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
          if (favoritesProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (favoritesProvider.favoriteGroups.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildInfoBanner(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      favoritesProvider.loadFavorites(forceRefresh: true),
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    itemCount: favoritesProvider.favoriteGroups.length,
                    itemBuilder: (context, index) {
                      final favoriteGroup =
                          favoritesProvider.favoriteGroups[index];
                      return _buildRestaurantCard(
                        favoriteGroup,
                        favoritesProvider,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.08),
            primaryColor.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tocca un piatto preferito per ordinarlo subito!',
              style: TextStyle(
                fontSize: 13,
                color: darkColor.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.2),
                  primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 60,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nessun preferito',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Aggiungi ristoranti e piatti ai tuoi preferiti per trovarli facilmente qui',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: grayColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(
    FavoriteGroup favoriteGroup,
    FavoritesProvider favoritesProvider,
  ) {
    final restaurant = favoriteGroup.restaurant;
    final isExpanded = _expandedRestaurants.contains(restaurant.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header ristorante
          InkWell(
            onTap: () {
              if (favoriteGroup.favoriteDishes.isNotEmpty) {
                setState(() {
                  if (_expandedRestaurants.contains(restaurant.id)) {
                    _expandedRestaurants.remove(restaurant.id);
                  } else {
                    _expandedRestaurants.add(restaurant.id);
                  }
                });
              } else {
                // Se non ci sono piatti, apri direttamente il menu
                _openRestaurant(restaurant);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Immagine ristorante con gradiente
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          restaurant.imageUrl ?? '',
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.3),
                                      primaryColor.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.restaurant,
                                  color: primaryColor,
                                  size: 36,
                                ),
                              ),
                        ),
                      ),
                      if (favoriteGroup.isRestaurantFavorite)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Nome e dettagli
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: darkColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (favoriteGroup.favoriteDishes.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.restaurant_menu,
                                      size: 14,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${favoriteGroup.favoriteDishes.length} piatt${favoriteGroup.favoriteDishes.length == 1 ? "o" : "i"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Chevron per espansione
                  if (favoriteGroup.favoriteDishes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lightGrayColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: darkColor,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Lista piatti espandibile
          if (isExpanded && favoriteGroup.favoriteDishes.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightGrayColor.withOpacity(0.2), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  top: BorderSide(color: lightGrayColor.withOpacity(0.5)),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: favoriteGroup.favoriteDishes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 0),
                itemBuilder: (context, index) {
                  final dish = favoriteGroup.favoriteDishes[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: primaryColor.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: dish.imageUrl != null
                            ? Image.network(
                                dish.imageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            primaryColor.withOpacity(0.2),
                                            primaryColor.withOpacity(0.05),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.restaurant_menu,
                                        color: primaryColor,
                                        size: 28,
                                      ),
                                    ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.2),
                                      primaryColor.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.restaurant_menu,
                                  color: primaryColor,
                                  size: 28,
                                ),
                              ),
                      ),
                      title: Text(
                        dish.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: darkColor,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '€${dish.actualPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              favoritesProvider.removeFavorite('dish', dish.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: primaryColor,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        // Apre il menu del ristorante con la scheda
                        // del piatto gia' aperta, pronta per l'ordine.
                        _openRestaurant(restaurant, dishId: dish.id);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
