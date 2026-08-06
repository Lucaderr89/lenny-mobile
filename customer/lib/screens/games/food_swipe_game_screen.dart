import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/food_swipe_card.dart';
import '../../services/games_service.dart';
import '../../services/restaurant_service.dart';
import '../restaurant_menu_screen.dart';

/// Food Swipe Game - Tinder-style per piatti
/// Swipe destra = Like, Swipe sinistra = Nope
/// Ogni 3-5 swipe mostra "Match!" e porta al ristorante
class FoodSwipeGameScreen extends StatefulWidget {
  const FoodSwipeGameScreen({super.key});

  @override
  State<FoodSwipeGameScreen> createState() => _FoodSwipeGameScreenState();
}

class _FoodSwipeGameScreenState extends State<FoodSwipeGameScreen>
    with TickerProviderStateMixin {
  // Colori (coerenti con scopri_tab.dart e dish_match_game_screen.dart)
  static const Color primaryDarkPink = AppColors.primary;
  static const Color accentYellow = AppColors.accent;
  static const Color warningOrange = AppColors.warning;
  static const Color darkColor = AppColors.dark;
  static const Color lightColor = Color(0xFFFFFFFF);
  static const Color grayColor = AppColors.grayDark;
  static const Color lightGrayColor = AppColors.grayLight;

  final GamesService _gamesService = GamesService();

  List<FoodSwipeCard> _cards = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  int _swipeCount = 0;
  int _likesCount = 0;

  // Animazione drag
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0.0;
  bool _isDragging = false;

  // Random per match timing (ogni 3-5 swipe)
  final Random _random = Random();
  int _nextMatchAt = 0;

  // Controllers per animazioni
  late AnimationController _buttonPulseController;
  late Animation<double> _buttonPulseAnimation;

  @override
  void initState() {
    super.initState();

    // Animazione pulse per i bottoni
    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _buttonPulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOut),
    );

    _loadCards();
    _nextMatchAt = 3 + _random.nextInt(3); // 3-5
  }

  @override
  void dispose() {
    _buttonPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    try {
      final cards = await _gamesService.getFoodSwipeCards();

      if (!mounted) return;

      if (cards.isEmpty) {
        _showError('Nessun piatto disponibile al momento. Riprova più tardi.');
        return;
      }

      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        _showError('Errore nel caricamento dei piatti. Riprova.');
      }
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragRotation = _dragOffset.dx / 1000;
      _isDragging = true;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Se drag oltre il 30% dello schermo, fai swipe
    if (_dragOffset.dx.abs() > screenWidth * 0.3) {
      final isLike = _dragOffset.dx > 0;
      _swipeCard(isLike);
    } else {
      // Resetta la posizione
      setState(() {
        _dragOffset = Offset.zero;
        _dragRotation = 0.0;
        _isDragging = false;
      });
    }
  }

  void _swipeCard(bool isLike) {
    final screenWidth = MediaQuery.of(context).size.width;

    setState(() {
      // Animazione swipe con curva verso l'alto/basso
      _dragOffset = Offset(
        isLike ? screenWidth * 1.5 : -screenWidth * 1.5,
        -100, // Esce verso l'alto con curva
      );
      _dragRotation = isLike ? 0.3 : -0.3; // Rotazione più marcata
      _swipeCount++;
      if (isLike) _likesCount++;
    });

    // Anima l'uscita della card
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
        _dragRotation = 0.0;
        _isDragging = false;
      });

      // Controlla se tutte le card sono finite
      if (_currentIndex >= _cards.length) {
        _showNoMoreCards();
        return;
      }

      // Match logic: ogni 3-5 swipe di like
      if (isLike && _swipeCount >= _nextMatchAt) {
        final matchedCard = _cards[_currentIndex - 1];
        _showMatchDialog(matchedCard);
        _nextMatchAt = _swipeCount + 3 + _random.nextInt(3); // Prossimo match
      }
    });
  }

  void _showMatchDialog(FoodSwipeCard card) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryDarkPink.withValues(alpha: 0.95),
                warningOrange.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryDarkPink.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stella animata
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentYellow.withValues(alpha: 0.6),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                "È UN MATCH!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hai matchato con',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  card.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'da ${card.restaurantName}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Pulsanti
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Continua',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToRestaurant(card);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryDarkPink,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'Ordina Ora!',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoMoreCards() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: lightColor,
        title: const Text(
          'Hai finito i piatti!',
          style: TextStyle(fontWeight: FontWeight.w900, color: darkColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 60, color: accentYellow),
            const SizedBox(height: 16),
            Text(
              'Hai swipato $_swipeCount piatti e fatto $_likesCount like!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: grayColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Esci',
              style: TextStyle(color: grayColor, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _swipeCount = 0;
                _likesCount = 0;
                _isLoading = true;
              });
              _loadCards();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDarkPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Gioca Ancora',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: lightColor,
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: primaryDarkPink, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Come Giocare',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: darkColor,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎯 Missione',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Scorri i piatti e scegli quelli che ti fanno venire l\'acquolina in bocca! Ogni like è un passo verso il tuo prossimo pasto stellare! 🌟',
                style: TextStyle(fontSize: 14, color: grayColor, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                '🕹️ Come funziona',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '1. Swipa a destra 👉 se il piatto ti conquista\n'
                '2. Swipa a sinistra 👈 se non fa per te\n'
                '3. Tap sul piatto per vedere il menu completo del ristorante',
                style: TextStyle(fontSize: 14, color: grayColor, height: 1.6),
              ),
              SizedBox(height: 16),
              Text(
                '💡 Trucchetto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Più swipe fai, più scopri! Non ti piace? Nessun problema, passa al prossimo. Il piatto perfetto è lì che ti aspetta! 😋',
                style: TextStyle(fontSize: 14, color: grayColor, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDarkPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Perfetto!',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToRestaurant(FoodSwipeCard card) async {
    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: primaryDarkPink),
      ),
    );

    try {
      // Carica dati REALI del ristorante via API
      final restaurantService = RestaurantService();
      final restaurant = await restaurantService.getRestaurantDetail(
        card.restaurantId,
      );

      if (mounted) Navigator.pop(context); // Chiudi loading

      if (restaurant != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantMenuScreen(
              restaurant: restaurant,
              openDishId: card.id,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore nel caricamento del ristorante'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Chiudi loading
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 56,
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
            width: 24,
            height: 24,
            color: darkColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/icons8-cuore-cucito-48.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Foodder',
              style: TextStyle(
                color: darkColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: lightColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/icons/icons8-informazioni-32.png',
              width: 24,
              height: 24,
            ),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: _isLoading ? _buildLoading() : _buildGame(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Caricamento piatti...',
            style: TextStyle(fontSize: 16, color: grayColor),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    if (_currentIndex >= _cards.length) {
      return const Center(
        child: Text(
          'Nessun piatto disponibile',
          style: TextStyle(fontSize: 16, color: grayColor),
        ),
      );
    }

    return Column(
      children: [
        // Istruzioni rimosse - ora nel dialog info
        // Stack di card
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Card successiva (preview)
              if (_currentIndex + 1 < _cards.length)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Transform.scale(
                    scale: 0.9,
                    child: Opacity(
                      opacity: 0.5,
                      child: _buildCard(_cards[_currentIndex + 1], false),
                    ),
                  ),
                ),

              // Card corrente (draggable)
              GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Transform.translate(
                  offset: _dragOffset,
                  child: Transform.rotate(
                    angle: _dragRotation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildCard(_cards[_currentIndex], true),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottoni Like/Nope
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.close,
                color: Colors.red,
                onTap: () => _swipeCard(false),
              ),
              _buildActionButton(
                icon: Icons.favorite,
                color: Colors.green,
                onTap: () => _swipeCard(true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(FoodSwipeCard card, bool isActive) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dragProgress = (_dragOffset.dx / screenWidth).clamp(-1.0, 1.0);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              // Glow colorato in base allo swipe
              if (isActive && _isDragging && dragProgress.abs() > 0.05)
                BoxShadow(
                  color: (dragProgress > 0 ? Colors.green : Colors.red)
                      .withValues(alpha: dragProgress.abs() * 0.6),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Immagine piatto
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        card.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: lightGrayColor,
                            child: const Icon(
                              Icons.restaurant,
                              size: 80,
                              color: grayColor,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: lightGrayColor,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      ),
                      // Overlay gradiente per leggibilità
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Info piatto
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            card.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: darkColor,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.restaurant, size: 14, color: grayColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                card.restaurantName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: grayColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '€${card.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryDarkPink,
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
        ),

        // Icona LIKE/NOPE durante drag
        if (isActive && _isDragging && dragProgress.abs() > 0.05)
          Positioned(
            top: 80,
            left: dragProgress > 0 ? null : 40,
            right: dragProgress > 0 ? 40 : null,
            child: Transform.scale(
              scale: 0.5 + (dragProgress.abs() * 1.5).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: dragProgress > 0 ? -0.3 : 0.3,
                child: Opacity(
                  opacity: (dragProgress.abs() * 2).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: dragProgress > 0 ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: (dragProgress > 0 ? Colors.green : Colors.red)
                              .withValues(alpha: 0.8),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Text(
                      dragProgress > 0 ? 'LIKE' : 'NOPE',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _buttonPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonPulseAnimation.value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 20 * _buttonPulseAnimation.value,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 36),
            ),
          ),
        );
      },
    );
  }
}
