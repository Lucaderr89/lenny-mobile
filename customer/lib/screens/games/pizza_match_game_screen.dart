import 'package:flutter/material.dart';
import '../../models/pizza_match_round.dart';
import '../../services/games_service.dart';
import '../../services/restaurant_service.dart';
import '../restaurant_menu_screen.dart';

/// Schermata gioco Pizza Match
/// L'utente deve indovinare gli ingredienti corretti di una pizza
class PizzaMatchGameScreen extends StatefulWidget {
  const PizzaMatchGameScreen({super.key});

  @override
  State<PizzaMatchGameScreen> createState() => _PizzaMatchGameScreenState();
}

class _PizzaMatchGameScreenState extends State<PizzaMatchGameScreen>
    with TickerProviderStateMixin {
  // Colori (coerenti con scopri_tab.dart)
  static const Color primaryDarkPink = Color(0xFFD91546);
  static const Color accentYellow = Color(0xFFFFD042);
  static const Color successGold = Color(0xFFFFB83D);
  static const Color warningOrange = Color(0xFFE67700);
  static const Color darkColor = Color(0xFF0A0A0A);
  static const Color lightColor = Color(0xFFFFFFFF);
  static const Color grayColor = Color(0xFF595959);
  static const Color lightGrayColor = Color(0xFFD8D8D8);

  final GamesService _gamesService = GamesService();

  // Stato del gioco
  PizzaMatchRound? _currentRound;
  Set<int> _selectedIngredientIds = {}; // ID degli ingredienti selezionati
  bool _isLoading = true;
  bool _isChecking = false;
  bool _showResult = false;
  int _correctCount = 0;
  int _totalCorrect = 0;
  int _failedAttempts = 0; // Traccia i tentativi falliti per l'aiuto

  late AnimationController _pulseController;
  late AnimationController _imageController;
  late Animation<double> _imageAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _imageAnimation = CurvedAnimation(
      parent: _imageController,
      curve: Curves.easeOutBack,
    );

    _loadRound();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _loadRound() async {
    setState(() {
      _isLoading = true;
      _showResult = false;
      _selectedIngredientIds.clear();
      _correctCount = 0;
      _totalCorrect = 0;
      // _failedAttempts NON si resetta quando cambi pizza (continua ad accumularsi)
    });

    try {
      final round = await _gamesService.getPizzaMatchRound();

      if (round == null) {
        if (mounted) {
          _showError('Impossibile caricare la pizza. Riprova più tardi.');
        }
        return;
      }

      setState(() {
        _currentRound = round;
        _totalCorrect = round.correctIngredients.length;
        _isLoading = false;
      });

      // Anima l'immagine in ingresso
      _imageController.forward();
    } catch (e) {
      if (mounted) {
        _showError('Errore nel caricamento del gioco. Riprova.');
      }
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _toggleIngredient(int ingredientId) {
    if (_showResult || _isChecking) return;

    setState(() {
      if (_selectedIngredientIds.contains(ingredientId)) {
        _selectedIngredientIds.remove(ingredientId);
      } else {
        _selectedIngredientIds.add(ingredientId);
      }
    });
  }

  void _checkIngredients() {
    if (_selectedIngredientIds.isEmpty || _currentRound == null) return;

    setState(() => _isChecking = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      // Conta quanti ingredienti corretti sono stati selezionati
      final correctIngredientNames = _currentRound!.correctIngredients.toSet();
      final selectedIngredientNames = _currentRound!.allIngredients
          .where((ing) => _selectedIngredientIds.contains(ing.id))
          .map((ing) => ing.name)
          .toSet();

      // Ingredienti corretti selezionati
      final correctSelected = correctIngredientNames.intersection(
        selectedIngredientNames,
      );

      final totalSelected = selectedIngredientNames.length;

      setState(() {
        _correctCount = correctSelected.length;
        _showResult = true;
        _isChecking = false;
      });

      // CASO 1: Ha selezionato TUTTI gli ingredienti corretti e NESSUN falso
      if (correctSelected.length == _totalCorrect &&
          totalSelected == _totalCorrect) {
        setState(() => _failedAttempts = 0); // Reset su successo
        _showSuccessDialog();
      }
      // CASO 2: Ha selezionato PIÙ ingredienti del necessario
      else if (totalSelected > _totalCorrect) {
        setState(() => _failedAttempts++);
        // Mostra aiuto dopo 2 errori
        if (_failedAttempts >= 2) {
          _showHelpDialog(() => _showTooManyIngredientsDialog(totalSelected));
        } else {
          _showTooManyIngredientsDialog(totalSelected);
        }
      }
      // CASO 3: Ha indovinato alcuni ingredienti ma non tutti (senza aggiungerne troppi)
      else {
        setState(() => _failedAttempts++);
        // Mostra aiuto dopo 2 errori
        if (_failedAttempts >= 2) {
          _showHelpDialog(_showRetryDialog);
        } else {
          _showRetryDialog();
        }
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: successGold.withOpacity(0.95),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: lightColor,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/icons/icons8-pizza-48.png',
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'PERFETTO!',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: darkColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        content: Text(
          'Hai indovinato tutti gli ingredienti della ${_currentRound?.pizza.name ?? 'pizza'}!\nVuoi ordinarla subito?',
          style: const TextStyle(fontSize: 14, color: darkColor),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRound(); // Gioca ancora
            },
            style: TextButton.styleFrom(
              foregroundColor: darkColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
            child: const Text(
              'Passa',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRestaurant();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: darkColor,
              foregroundColor: lightColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              elevation: 2,
            ),
            child: const Text(
              'Ordina',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: lightColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: warningOrange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh, color: warningOrange, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Riprova!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: Text(
          'Hai indovinato $_correctCount su $_totalCorrect ingredienti.\nProva ancora o cambia pizza!',
          style: const TextStyle(fontSize: 14, color: grayColor),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRound(); // Carica nuova pizza
            },
            style: TextButton.styleFrom(
              foregroundColor: grayColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
            child: const Text(
              'Passa',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showResult = false;
                _selectedIngredientIds.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: warningOrange,
              foregroundColor: lightColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              elevation: 2,
            ),
            child: const Text(
              'Riprova',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showTooManyIngredientsDialog(int totalSelected) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: lightColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryDarkPink.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu,
                color: primaryDarkPink,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Ops!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Questa pizza ha solo $_totalCorrect ingredienti,\nma tu ne hai selezionati $totalSelected!',
              style: const TextStyle(
                fontSize: 14,
                color: darkColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Hai indovinato $_correctCount ingredienti corretti,\nma hai aggiunto ${totalSelected - _totalCorrect} ingredienti di troppo!',
              style: const TextStyle(fontSize: 13, color: grayColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRound();
            },
            style: TextButton.styleFrom(
              foregroundColor: grayColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
            child: const Text(
              'Passa',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showResult = false;
                _selectedIngredientIds.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDarkPink,
              foregroundColor: lightColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              elevation: 2,
            ),
            child: const Text(
              'Riprova',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(VoidCallback onContinue) {
    if (_currentRound == null) return;

    final List<String> hints = [
      'Ti do un super aiuto! 🎁\nHo selezionato quasi tutti gli ingredienti,\ntrova l\'ultimo!',
      'Colpo di fortuna! 🍀\nTi ho fatto il lavoro duro,\nmanca solo un ingrediente!',
      'Aiutino speciale! ✨\nTi ho preselezionato quasi tutto,\nindovina l\'ultimo ingrediente!',
      'Regalo dello chef! 👨‍🍳\nHo scelto quasi tutti gli ingredienti,\na te l\'onore del tocco finale!',
    ];

    // Scegli hint random
    final hint = hints[_failedAttempts % hints.length];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: accentYellow.withOpacity(0.95),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: lightColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb,
                color: Color(0xFFFFB83D),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Aiutino!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👨‍🍳', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 16,
                color: darkColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyHelpHint();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: darkColor,
                foregroundColor: lightColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 32,
                ),
                elevation: 2,
              ),
              child: const Text(
                'Capito! 💪',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyHelpHint() {
    if (_currentRound == null) return;

    // Ottieni gli ID degli ingredienti corretti
    final correctIngredientIds = _currentRound!.allIngredients
        .where((ing) => _currentRound!.correctIngredients.contains(ing.name))
        .map((ing) => ing.id)
        .toList();

    if (correctIngredientIds.isEmpty) return;

    // Se c'è solo 1 ingrediente, non preselezionare nulla (lascia che indovini)
    if (correctIngredientIds.length == 1) {
      setState(() {
        _showResult = false;
        _selectedIngredientIds.clear();
      });
      return;
    }

    // Seleziona N-1 ingredienti corretti casuali
    final shuffled = List<int>.from(correctIngredientIds)..shuffle();
    final toSelect = shuffled.take(correctIngredientIds.length - 1).toSet();

    setState(() {
      _selectedIngredientIds = toSelect;
      _showResult = false;
    });

    // Mostra messaggio di conferma
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ho selezionato ${toSelect.length} ingrediente${toSelect.length > 1 ? 'i' : ''} per te! Trova l\'ultimo! 🔍',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: successGold,
      ),
    );
  }

  Future<void> _navigateToRestaurant() async {
    if (_currentRound == null) return;

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
        _currentRound!.pizza.restaurantId,
      );

      if (mounted) Navigator.pop(context); // Chiudi loading

      if (restaurant != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantMenuScreen(
              restaurant: restaurant,
              openDishId: _currentRound!.pizza.id,
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
              'assets/icons/icons8-pizza-48.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Pizza Match',
              style: TextStyle(
                color: darkColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
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
      body: _isLoading ? _buildLoadingState() : _buildGameContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _pulseController,
            child: Image.asset(
              'assets/icons/icons8-pizza-48.png',
              width: 64,
              height: 64,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryDarkPink),
          ),
          const SizedBox(height: 16),
          const Text(
            'Preparazione pizza...',
            style: TextStyle(
              fontSize: 16,
              color: grayColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    if (_currentRound == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: warningOrange),
            const SizedBox(height: 16),
            const Text(
              'Errore nel caricamento\ndella pizza',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: grayColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRound,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDarkPink,
                foregroundColor: lightColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Istruzioni rimosse - ora nel dialog info
            // Immagine Pizza
            _buildPizzaImage(),
            const SizedBox(height: 16),

            // Nome Pizza + Ristorante
            _buildPizzaInfo(),
            const SizedBox(height: 24),

            // Ingredienti selezionabili
            _buildIngredientsGrid(),
            const SizedBox(height: 24),

            // Bottoni Azione
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
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
                'Sei un pizzaiolo esperto! Guarda la pizza e indovina quali ingredienti la compongono. Facile? Vedremo! 🍕😎',
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
                '1. Osserva bene la pizza\n'
                '2. Seleziona gli ingredienti giusti dalla griglia\n'
                '3. Controlla se hai indovinato tutti!\n'
                '4. Tap sulla pizza per ordinarla dal ristorante',
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
                'Se sbagli 2 volte, ti darò un aiutino pre-selezionando quasi tutti gli ingredienti. Dovrai trovare solo l\'ultimo! 🤫',
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

  Widget _buildPizzaImage() {
    return ScaleTransition(
      scale: _imageAnimation,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: darkColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            _currentRound!.pizza.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: lightGrayColor,
              child: const Icon(Icons.local_pizza, size: 80, color: grayColor),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: lightGrayColor,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      primaryDarkPink,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPizzaInfo() {
    return Column(
      children: [
        Text(
          _currentRound!.pizza.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: darkColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant, size: 16, color: grayColor),
            const SizedBox(width: 6),
            Text(
              _currentRound!.pizza.restaurantName,
              style: const TextStyle(
                fontSize: 14,
                color: grayColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIngredientsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ingredienti',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: darkColor,
              ),
            ),
            if (_selectedIngredientIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryDarkPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedIngredientIds.length} selezionati',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryDarkPink,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _currentRound!.allIngredients.map((ingredient) {
            final isSelected = _selectedIngredientIds.contains(ingredient.id);
            return _buildIngredientChip(ingredient, isSelected);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIngredientChip(PizzaIngredient ingredient, bool isSelected) {
    return InkWell(
      onTap: () => _toggleIngredient(ingredient.id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryDarkPink : lightColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryDarkPink : lightGrayColor,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryDarkPink.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          ingredient.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? lightColor : darkColor,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Bottone Skip
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isChecking ? null : _loadRound,
            icon: const Icon(Icons.skip_next),
            label: const Text('Passa'),
            style: OutlinedButton.styleFrom(
              foregroundColor: grayColor,
              side: BorderSide(color: lightGrayColor, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Bottone Conferma
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: (_isChecking || _selectedIngredientIds.isEmpty)
                ? null
                : _checkIngredients,
            icon: _isChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(lightColor),
                    ),
                  )
                : const Icon(Icons.check_circle),
            label: Text(_isChecking ? 'Verifica...' : 'Conferma'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDarkPink,
              foregroundColor: lightColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              disabledBackgroundColor: lightGrayColor,
              disabledForegroundColor: grayColor,
            ),
          ),
        ),
      ],
    );
  }
}
