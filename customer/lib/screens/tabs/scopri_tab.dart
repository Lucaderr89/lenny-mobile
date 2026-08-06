import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/discover_content.dart';
import '../../models/restaurant.dart';
import '../../models/trending_dish.dart';
import '../../models/food_event.dart';
import '../../models/weather_suggestion.dart';
import '../../services/discovery_service.dart';
import '../../services/restaurant_service.dart';
import '../restaurant_menu_screen.dart';
import '../games/dish_match_game_screen.dart';
import '../games/food_swipe_game_screen.dart';
import '../games/pizza_match_game_screen.dart';
import '../games/recipe_scrambler_game_screen.dart';

/// Tab "Scopri" - Discovery con contenuti esterni e gamification
class ScopriTab extends StatefulWidget {
  final ScrollController scrollController;

  /// Deep-link verso la ricerca della home: i chip suggerimento (meteo,
  /// eventi) portano ai ristoranti invece di essere decorazione.
  final void Function(String query)? onSearchSuggestion;

  const ScopriTab({
    super.key,
    required this.scrollController,
    this.onSearchSuggestion,
  });

  @override
  State<ScopriTab> createState() => _ScopriTabState();
}

class _ScopriTabState extends State<ScopriTab>
    with AutomaticKeepAliveClientMixin {
  // Il tab resta vivo nel PageView: anche solo attraversarlo scorrendo
  // verso un altro tab innescava 4 chiamate di rete a ogni passaggio.
  @override
  bool get wantKeepAlive => true;

  // Colori (coerenti con home_screen.dart)
  static const Color primaryDarkPink = AppColors.primary;
  static const Color secondaryPink = Color(0xFFFF1A60);
  static const Color accentYellow = Color(0xFFFFD042);
  static const Color successGold = Color(0xFFFFB83D);
  static const Color warningOrange = Color(0xFFE67700);
  static const Color darkColor = AppColors.dark;
  static const Color lightColor = Color(0xFFFFFFFF);
  static const Color grayColor = AppColors.grayDark;
  static const Color lightGrayColor = AppColors.grayLight;

  final DiscoveryService _discoveryService = DiscoveryService();

  WeatherSuggestion? _weatherSuggestion;
  List<TrendingDish> _trendingDishes = [];
  List<DiscoveryContent> _gzContent = [];
  FoodEvent? _todayEvent;

  bool _isLoadingWeather = true;
  bool _isLoadingTrending = true;
  bool _isLoadingGZ = true;
  bool _isLoadingEvent = true;

  @override
  void initState() {
    super.initState();
    _loadAllContent();
  }

  Future<void> _loadAllContent() async {
    _loadWeather();
    _loadTrending();
    _loadGialloZafferano();
    _loadEvent();
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoadingWeather = true);
    try {
      final weather = await _discoveryService.getWeatherSuggestion();
      if (mounted) {
        setState(() {
          _weatherSuggestion = weather;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoadingTrending = true);
    try {
      final trending = await _discoveryService.getTrendingDishes();
      if (mounted) {
        setState(() {
          _trendingDishes = trending;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  Future<void> _loadGialloZafferano() async {
    setState(() => _isLoadingGZ = true);
    try {
      final content = await _discoveryService.getGialloZafferanoContent();
      if (mounted) {
        setState(() {
          _gzContent = content;
          _isLoadingGZ = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGZ = false);
    }
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoadingEvent = true);
    try {
      final event = await _discoveryService.getTodayEvent();
      if (mounted) {
        setState(() {
          _todayEvent = event;
          _isLoadingEvent = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEvent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // richiesto da AutomaticKeepAliveClientMixin
    return RefreshIndicator(
      onRefresh: _loadAllContent,
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          // 1. Banner Meteo
          SliverToBoxAdapter(child: _buildWeatherBanner()),

          // 2. Popolare Ora
          SliverToBoxAdapter(child: _buildTrendingSection()),

          // 3. Giallo Zafferano
          SliverToBoxAdapter(child: _buildGialloZafferanoSection()),

          // 4. Evento del Giorno
          SliverToBoxAdapter(child: _buildEventSection()),

          // 5. Minigiochi
          SliverToBoxAdapter(child: _buildMiniGamesSection()),

          // Padding finale
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // ========== 1. BANNER METEO ==========

  Widget _buildWeatherBanner() {
    if (_isLoadingWeather) {
      return Container(
        margin: const EdgeInsets.fromLTRB(15, 15, 15, 8),
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_weatherSuggestion == null) {
      return const SizedBox.shrink();
    }

    final weather = _weatherSuggestion!;

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 15, 15, 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(weather.icon, width: 32, height: 32),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      weather.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${weather.temperature.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  weather.subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  // Chip TAPPABILI: portano alla ricerca ristoranti con il
                  // suggerimento come query (prima erano pura decorazione)
                  children: weather.suggestions
                      .take(3)
                      .map(
                        (suggestion) => GestureDetector(
                          onTap: () =>
                              widget.onSearchSuggestion?.call(suggestion),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  suggestion,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 2. POPOLARE ORA ==========

  Widget _buildTrendingSection() {
    if (_isLoadingTrending) {
      return _buildSectionSkeleton('I più Amati');
    }

    // 🔧 PLACEHOLDER se vuoto
    if (_trendingDishes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
            child: Row(
              children: [
                Image.asset(
                  'assets/icons/icons8-piu_amati-32.png',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 6),
                const Text(
                  'I più Amati',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: lightGrayColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: lightGrayColor, width: 1.5),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_outlined,
                    size: 40,
                    color: grayColor.withOpacity(0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ancora nessun piatto di tendenza',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: grayColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ordina qualcosa e diventa trendsetter!',
                    style: TextStyle(
                      fontSize: 12,
                      color: grayColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/icons8-piu_amati-32.png',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'I più Amati',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
            itemCount: _trendingDishes.length,
            itemBuilder: (context, index) {
              return _buildTrendingCard(_trendingDishes[index]);
            },
          ),
        ),
      ],
    );
  }

  /// Apre il piatto trending nel menu del suo ristorante: la card
  /// diventa conversione, non solo vetrina.
  Future<void> _openTrendingDish(TrendingDish dish) async {
    if (dish.restaurantId <= 0) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: primaryDarkPink),
      ),
    );

    Restaurant? restaurant;
    try {
      restaurant = await RestaurantService().getRestaurantDetail(
        dish.restaurantId,
      );
    } catch (_) {
      restaurant = null;
    }

    if (!mounted) return;
    Navigator.pop(context); // chiudi loading

    if (restaurant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ristorante non disponibile al momento'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMenuScreen(
          restaurant: restaurant!,
          openDishId: dish.dishId,
        ),
      ),
    );
  }

  Widget _buildTrendingCard(TrendingDish dish) {
    return GestureDetector(
      onTap: () => _openTrendingDish(dish),
      child: Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(15),
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
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: dish.imageUrl != null
                    ? Image.network(
                        dish.imageUrl!,
                        width: double.infinity,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: secondaryPink,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mostra 1, 2 o 3 icone in base alla popolarità
                      ...List.generate(
                        dish.orderCount >= 10 ? 3 : (dish.orderCount >= 5 ? 2 : 1),
                        (index) => Padding(
                          padding: EdgeInsets.only(left: index > 0 ? 2 : 0),
                          child: Image.asset(
                            'assets/icons/icons8-piu_amati-32.png',
                            width: 12,
                            height: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.dishName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dish.restaurantName,
                  style: const TextStyle(fontSize: 11, color: grayColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dish.timeAgo,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: grayColor,
                      ),
                    ),
                    Text(
                      '€${dish.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                      ),
                    ),
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

  // ========== 3. GIALLO ZAFFERANO ==========

  Widget _buildGialloZafferanoSection() {
    if (_isLoadingGZ) {
      return _buildSectionSkeleton('Ispirazioni');
    }

    if (_gzContent.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/icons8-cappello-dello-chef-32.png',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'Ispirazioni',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkColor,
                ),
              ),
              const Spacer(),
              Text(
                'by Misya',
                style: TextStyle(
                  fontSize: 10,
                  color: grayColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 10),
            itemCount: _gzContent.length,
            itemBuilder: (context, index) {
              return _buildGZCard(_gzContent[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGZCard(DiscoveryContent content) {
    return GestureDetector(
      onTap: () {
        if (content.sourceUrl != null) {
          _launchURL(content.sourceUrl!);
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(15),
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: content.imageUrl != null
                      ? Image.network(
                          content.imageUrl!,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _buildImagePlaceholder(height: 120),
                        )
                      : _buildImagePlaceholder(height: 120),
                ),
                if (content.badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        content.badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: darkColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: grayColor.withOpacity(0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 4. EVENTO DEL GIORNO ==========

  Widget _buildEventSection() {
    if (_isLoadingEvent) {
      return Container(
        margin: const EdgeInsets.fromLTRB(15, 12, 15, 8),
        height: 100,
        decoration: BoxDecoration(
          color: lightGrayColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(15),
        ),
      );
    }

    if (_todayEvent == null) {
      return const SizedBox.shrink();
    }

    final event = _todayEvent!;

    // Colore dal server con GUARDIA: un hex malformato non deve far
    // crashare la build della home (int.parse senza try lo faceva).
    Color baseColor = accentYellow;
    Color endColor = warningOrange;
    if (event.backgroundColor != null) {
      final parsed = int.tryParse(
        event.backgroundColor!.replaceFirst('#', '0xFF'),
      );
      if (parsed != null) {
        baseColor = Color(parsed);
        endColor = Color(parsed).withOpacity(0.7);
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 12, 15, 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [baseColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Text(event.icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
                if (event.suggestions != null &&
                    event.suggestions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    // Chip tappabili verso la ricerca ristoranti
                    children: event.suggestions!
                        .take(3)
                        .map(
                          (suggestion) => GestureDetector(
                            onTap: () =>
                                widget.onSearchSuggestion?.call(suggestion),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                suggestion,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                // CTA dell'evento: c'era nel modello (actionText) ma non
                // veniva mai renderizzata. Porta ai suggerimenti dell'evento.
                if (event.actionText != null &&
                    event.actionText!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      final target =
                          (event.suggestions?.isNotEmpty ?? false)
                          ? event.suggestions!.first
                          : event.title;
                      widget.onSearchSuggestion?.call(target);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        event.actionText!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: baseColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 5. MINIGIOCHI ==========

  Widget _buildMiniGamesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/icons8-sala-giochi-di-mele-32.png',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'Gioca e Scopri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkColor,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildGameCard(
                      '',
                      'Dish\nMatch',
                      warningOrange,
                      iconAsset: 'assets/icons/icons8-ingredienti-48.png',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DishMatchGameScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildGameCard(
                      '',
                      'Foodder',
                      secondaryPink,
                      iconAsset: 'assets/icons/icons8-tinder-48.png',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FoodSwipeGameScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildGameCard(
                      '',
                      'Pizza\nMatch',
                      successGold,
                      iconAsset: 'assets/icons/icons8-pizza-48.png',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PizzaMatchGameScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildGameCard(
                      '',
                      'Scrambler',
                      primaryDarkPink,
                      iconAsset: 'assets/icons/icons8-mattoncino-48.png',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RecipeScramblerGameScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard(
    String icon,
    String title,
    Color color, {
    VoidCallback? onTap,
    String? iconAsset,
  }) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            // TODO: Aprire gioco
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$title in arrivo!')));
          },
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconAsset != null)
              Image.asset(iconAsset, width: 24, height: 24)
            else
              Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              title.replaceAll('\n', ' '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== HELPERS ==========

  Widget _buildImagePlaceholder({double height = 100}) {
    return Container(
      width: double.infinity,
      height: height,
      color: lightGrayColor,
      child: Icon(Icons.restaurant_menu, size: height * 0.4, color: grayColor),
    );
  }

  Widget _buildSectionSkeleton(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                width: 170,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: lightGrayColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
