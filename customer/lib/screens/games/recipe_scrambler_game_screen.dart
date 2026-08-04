import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/recipe_scrambler_round.dart';
import '../../services/games_service.dart';
import '../../services/restaurant_service.dart';
import '../restaurant_menu_screen.dart';

/// Schermata gioco Recipe Scrambler
/// L'utente deve riordinare le lettere scramblate per scoprire il nome del piatto
class RecipeScramblerGameScreen extends StatefulWidget {
  const RecipeScramblerGameScreen({super.key});

  @override
  State<RecipeScramblerGameScreen> createState() =>
      _RecipeScramblerGameScreenState();
}

class _RecipeScramblerGameScreenState extends State<RecipeScramblerGameScreen>
    with TickerProviderStateMixin {
  // Colori (coerenti con scopri_tab.dart)
  static const Color primaryDarkPink = AppColors.primary;
  static const Color accentYellow = Color(0xFFFFD042);
  static const Color successGold = Color(0xFFFFB83D);
  static const Color warningOrange = Color(0xFFE67700);
  static const Color darkColor = AppColors.dark;
  static const Color lightColor = Color(0xFFFFFFFF);
  static const Color grayColor = AppColors.grayDark;
  static const Color lightGrayColor = AppColors.grayLight;

  final GamesService _gamesService = GamesService();

  // Stato del gioco
  RecipeScramblerRound? _currentRound;
  List<String?> _userAnswer =
      []; // Lettere posizionate dall'utente (null se slot vuoto)
  List<String> _availableLetters = []; // Lettere disponibili da posizionare
  bool _isLoading = true;
  bool _isChecking = false;
  int _hintsUsed = 0; // Max 2 aiuti
  final Set<int> _revealedPositions = {}; // Posizioni rivelate dagli aiuti

  late AnimationController _imageController;
  late Animation<double> _imageAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _imageAnimation = CurvedAnimation(
      parent: _imageController,
      curve: Curves.easeOutBack,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _loadRound();
  }

  @override
  void dispose() {
    _imageController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadRound() async {
    setState(() {
      _isLoading = true;
      _userAnswer.clear();
      _availableLetters.clear();
      _hintsUsed = 0;
      _revealedPositions.clear();
    });

    try {
      final round = await _gamesService.getRecipeScramblerRound();

      if (round == null) {
        if (mounted) {
          _showError('Impossibile caricare il gioco. Riprova più tardi.');
        }
        return;
      }

      setState(() {
        _currentRound = round;
        // Inizializza slots vuoti (null = slot vuoto, ' ' = spazio fisso)
        _userAnswer = round.scrambledLetters.map((letter) {
          return letter == ' ' ? ' ' : null;
        }).toList();
        // Lettere disponibili (escludi spazi)
        _availableLetters = round.scrambledLetters
            .where((letter) => letter != ' ')
            .toList();
        _isLoading = false;
      });

      // Anima l'immagine in ingresso
      _imageController.forward();
    } catch (e) {
      if (mounted) {
        _showError('Errore nel caricamento del gioco: $e');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: lightColor,
        title: Row(
          children: [
            Icon(Icons.error_outline, color: primaryDarkPink, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Errore',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, color: grayColor),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Chiudi dialog errore
              Navigator.pop(context); // Torna alla tab Scopri
            },
            child: const Text('Chiudi'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRound();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDarkPink,
              foregroundColor: lightColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  /// Posiziona una lettera in uno slot
  void _placeLetter(String letter, int slotIndex) {
    if (_currentRound == null) return;

    setState(() {
      // Se lo slot era già occupato, rimetti la lettera nelle disponibili
      if (_userAnswer[slotIndex] != null && _userAnswer[slotIndex] != ' ') {
        _availableLetters.add(_userAnswer[slotIndex]!);
      }

      // Posiziona la nuova lettera
      _userAnswer[slotIndex] = letter;
      _availableLetters.remove(letter);
    });
  }

  /// Rimuove una lettera da uno slot (torna nelle disponibili)
  void _removeLetter(int slotIndex) {
    if (_currentRound == null) return;
    if (_userAnswer[slotIndex] == null || _userAnswer[slotIndex] == ' ') return;
    if (_revealedPositions.contains(slotIndex)) {
      return; // Non rimuovere lettere rivelate
    }

    setState(() {
      _availableLetters.add(_userAnswer[slotIndex]!);
      _userAnswer[slotIndex] = null;
    });
  }

  /// Usa un aiuto (rivela 2 lettere casuali)
  void _useHint() {
    if (_currentRound == null) return;
    if (_hintsUsed >= 2) return;

    final correctAnswer = _currentRound!.dish.name.split('');
    final unrevealedIndices = <int>[];

    // Trova posizioni non rivelate e non spazi
    for (int i = 0; i < correctAnswer.length; i++) {
      if (correctAnswer[i] != ' ' && !_revealedPositions.contains(i)) {
        unrevealedIndices.add(i);
      }
    }

    if (unrevealedIndices.isEmpty) return;

    // Rivela 2 lettere casuali (o meno se non ce ne sono abbastanza)
    final toReveal = (unrevealedIndices..shuffle()).take(2).toList();

    setState(() {
      for (final index in toReveal) {
        final correctLetter = correctAnswer[index];

        // Se c'era già una lettera nello slot, rimettila nelle disponibili
        if (_userAnswer[index] != null && _userAnswer[index] != ' ') {
          _availableLetters.add(_userAnswer[index]!);
        }

        // Posiziona la lettera corretta
        _userAnswer[index] = correctLetter;
        _availableLetters.remove(correctLetter);
        _revealedPositions.add(index);
      }

      _hintsUsed++;
    });
  }

  /// Verifica se la risposta è corretta
  void _checkAnswer() {
    if (_currentRound == null) return;

    // Controlla che tutti gli slot siano riempiti
    if (_userAnswer.any((letter) => letter == null)) {
      _showIncompleteDialog();
      return;
    }

    setState(() => _isChecking = true);

    final userSolution = _userAnswer.join('');
    final correctSolution = _currentRound!.dish.name;

    if (userSolution == correctSolution) {
      // ✅ Risposta corretta
      _showSuccessDialog();
    } else {
      // ❌ Risposta errata
      _shakeController.forward(from: 0);
      _showRetryDialog();
    }

    setState(() => _isChecking = false);
  }

  void _showIncompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: lightColor,
        title: const Text(
          'Attenzione',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: darkColor,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Posiziona tutte le lettere prima di confermare!',
          style: TextStyle(fontSize: 15, color: grayColor),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDarkPink,
              foregroundColor: lightColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    if (_currentRound == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: successGold.withOpacity(0.95),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🎉', style: TextStyle(fontSize: 32)),
            SizedBox(width: 8),
            Text(
              'BRAVO!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hai scoperto "${_currentRound!.dish.name}"!',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Vuoi ordinarlo da ${_currentRound!.dish.restaurantName}?',
              style: const TextStyle(fontSize: 14, color: darkColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRound(); // Gioca ancora
            },
            child: const Text(
              'Altro piatto',
              style: TextStyle(color: darkColor, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Chiudi dialog
              _navigateToRestaurant();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDarkPink,
              foregroundColor: lightColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Ordina'),
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
              'Non è corretto',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: const Text(
          'Le lettere non formano il nome corretto.\nVuoi riprovare o cambiare piatto?',
          style: TextStyle(fontSize: 15, color: grayColor),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRound(); // Cambia piatto
            },
            style: TextButton.styleFrom(
              foregroundColor: grayColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
            child: const Text(
              'Altro piatto',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Riprova con stesso piatto
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: warningOrange,
              foregroundColor: lightColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: lightColor,
        title: Row(
          children: const [
            Icon(Icons.help_outline, color: primaryDarkPink, size: 28),
            SizedBox(width: 12),
            Text(
              'Come Giocare',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '🎯 Missione',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Le lettere sono tutte mischiate! È come un puzzle linguistico dove devi riordinare tutto per scoprire quale delizioso piatto si nasconde. Sei pronto per la sfida? 🤓',
                style: TextStyle(fontSize: 14, color: grayColor, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                '🕹️ Come funziona',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '1. Tap su una lettera disponibile (in basso)\n'
                '2. Si posizionerà automaticamente nella prima casella libera!\n'
                '3. Tap su una lettera già posizionata per rimuoverla\n'
                '4. Gli spazi sono fissi, lasciami fare il lavoro! 😉\n'
                '5. Quando sei sicuro, premi "Controlla"',
                style: TextStyle(fontSize: 14, color: grayColor, height: 1.6),
              ),
              SizedBox(height: 16),
              Text(
                '💡 Trucchetto',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bloccato? Usa il bottone "Aiuto" (fino a 2 volte)! Ti rivelerò una lettera alla volta. Non è barare, è strategia! 😎',
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
              foregroundColor: lightColor,
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
      // Carica dati del ristorante via API
      final restaurantService = RestaurantService();
      final restaurant = await restaurantService.getRestaurantDetail(
        _currentRound!.dish.restaurantId,
      );

      if (mounted) Navigator.pop(context); // Chiudi loading

      if (restaurant != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantMenuScreen(
              restaurant: restaurant,
              openDishId: _currentRound!.dish.id,
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
              'assets/icons/icons8-mattoncino-48.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Scrambler',
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
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildGameContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryDarkPink),
          SizedBox(height: 20),
          Text(
            'Caricamento piatto...',
            style: TextStyle(fontSize: 16, color: grayColor),
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
            Icon(Icons.error_outline, size: 64, color: primaryDarkPink),
            const SizedBox(height: 16),
            const Text(
              'Nessun piatto disponibile',
              style: TextStyle(fontSize: 16, color: grayColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRound,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDarkPink,
                foregroundColor: lightColor,
              ),
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Istruzioni rimosse - ora nel dialog info

          // Immagine piatto
          _buildDishImage(),
          const SizedBox(height: 24),

          // Area slots per ricomporre il nome
          _buildAnswerSlots(),
          const SizedBox(height: 24),

          // Lettere disponibili
          _buildAvailableLetters(),
          const SizedBox(height: 32),

          // Bottoni azione
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildDishImage() {
    return ScaleTransition(
      scale: _imageAnimation,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: darkColor.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            _currentRound!.dish.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: lightGrayColor,
                child: const Center(
                  child: Icon(Icons.restaurant, size: 64, color: grayColor),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerSlots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ricomponi il nome:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: darkColor,
              ),
            ),
            Text(
              'Aiuti usati: $_hintsUsed/2',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _hintsUsed >= 2 ? grayColor : primaryDarkPink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Wrap(
            spacing: 6,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(
              _userAnswer.length,
              (index) => _buildAnswerSlot(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerSlot(int index) {
    final letter = _userAnswer[index];
    final isSpace = letter == ' ';
    final isRevealed = _revealedPositions.contains(index);

    if (isSpace) {
      // Spazio fisso
      return const SizedBox(width: 12);
    }

    return GestureDetector(
      onTap: isRevealed ? null : () => _removeLetter(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 50,
        decoration: BoxDecoration(
          color: isRevealed
              ? successGold.withOpacity(0.3)
              : (letter != null
                    ? primaryDarkPink.withOpacity(0.1)
                    : lightColor),
          border: Border.all(
            color: isRevealed
                ? successGold
                : (letter != null ? primaryDarkPink : lightGrayColor),
            width: isRevealed ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: letter == null
              ? const SizedBox.shrink()
              : Text(
                  letter,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isRevealed ? successGold : darkColor,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAvailableLetters() {
    if (_availableLetters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lettere disponibili:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: darkColor,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _availableLetters
              .asMap()
              .entries
              .map((entry) => _buildAvailableLetter(entry.value))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAvailableLetter(String letter) {
    return GestureDetector(
      onTap: () {
        // Trova il primo slot vuoto e posiziona la lettera
        final emptySlotIndex = _userAnswer.indexWhere((slot) => slot == null);

        if (emptySlotIndex != -1) {
          _placeLetter(letter, emptySlotIndex);
        }
      },
      child: Container(
        width: 44,
        height: 50,
        decoration: BoxDecoration(
          color: accentYellow.withOpacity(0.3),
          border: Border.all(color: accentYellow, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: accentYellow.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: darkColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final canUseHint = _hintsUsed < 2 && _availableLetters.isNotEmpty;
    final canConfirm = !_userAnswer.any((letter) => letter == null);

    return Column(
      children: [
        // Row bottoni: Aiuto + Altro piatto
        Row(
          children: [
            // Bottone Aiuto
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canUseHint ? _useHint : null,
                icon: const Icon(Icons.lightbulb_outline),
                label: Text('Aiuto ($_hintsUsed/2)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: canUseHint ? warningOrange : grayColor,
                  side: BorderSide(
                    color: canUseHint ? warningOrange : lightGrayColor,
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Bottone Altro piatto
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loadRound,
                icon: const Icon(Icons.skip_next),
                label: const Text('Altro piatto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: grayColor,
                  side: const BorderSide(color: lightGrayColor, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Bottone Conferma (full width)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canConfirm ? _checkAnswer : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canConfirm ? primaryDarkPink : lightGrayColor,
              foregroundColor: lightColor,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: canConfirm ? 4 : 0,
            ),
            child: _isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: lightColor,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Conferma',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
          ),
        ),
      ],
    );
  }
}
