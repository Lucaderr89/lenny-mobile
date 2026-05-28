import 'package:flutter/material.dart';
import '../../models/dish_match_dish.dart';
import '../../services/games_service.dart';

/// Schermata gioco Dish Match
/// L'utente deve associare 4 immagini di piatti ai loro nomi corretti
class DishMatchGameScreen extends StatefulWidget {
  const DishMatchGameScreen({super.key});

  @override
  State<DishMatchGameScreen> createState() => _DishMatchGameScreenState();
}

class _DishMatchGameScreenState extends State<DishMatchGameScreen>
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
  List<DishMatchDish> _dishes = [];
  List<String> _shuffledNames = [];
  final Map<int, int> _userMatches = {}; // imageIndex -> nameIndex
  int? _selectedImageIndex;
  bool _isLoading = true;
  bool _isChecking = false;
  bool _showResult = false;
  int _correctMatches = 0;
  int _failedAttempts = 0; // Traccia errori per l'aiuto

  late AnimationController _pulseController;
  late AnimationController _cardController;
  final Map<int, AnimationController> _cardAnimations = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Crea animazioni per ogni card
    for (int i = 0; i < 4; i++) {
      _cardAnimations[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
    }

    _loadRound();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cardController.dispose();
    for (var controller in _cardAnimations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRound() async {
    setState(() {
      _isLoading = true;
      _showResult = false;
      _userMatches.clear();
      _selectedImageIndex = null;
      _correctMatches = 0;
    });

    try {
      final dishes = await _gamesService.getDishMatchRound();

      if (dishes.isEmpty || dishes.length < 4) {
        if (mounted) {
          _showError('Piatti insufficienti per il gioco. Riprova più tardi.');
        }
        return;
      }

      // Mischia i nomi per renderlo più difficile
      final shuffledNames = dishes.map((d) => d.name).toList()..shuffle();

      setState(() {
        _dishes = dishes;
        _shuffledNames = shuffledNames;
        _isLoading = false;
      });

      // Anima le card all'ingresso
      _animateCardsIn();
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

  void _animateCardsIn() {
    for (int i = 0; i < _cardAnimations.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        _cardAnimations[i]?.forward();
      });
    }
  }

  void _onImageTap(int imageIndex) {
    if (_showResult || _isChecking) return;

    setState(() {
      _selectedImageIndex = imageIndex;
    });

    // Anima la card selezionata
    _cardAnimations[imageIndex]?.forward(from: 0.8).then((_) {
      _cardAnimations[imageIndex]?.reverse();
    });
  }

  void _onNameTap(int nameIndex) {
    if (_selectedImageIndex == null || _showResult || _isChecking) return;

    setState(() {
      // Associa l'immagine selezionata al nome tappato
      _userMatches[_selectedImageIndex!] = nameIndex;
      _selectedImageIndex = null;
    });

    // Controlla se tutte e 4 le associazioni sono state fatte
    if (_userMatches.length == 4) {
      _checkMatches();
    }
  }

  void _checkMatches() {
    setState(() => _isChecking = true);

    // Aspetta un attimo per dare feedback visivo
    Future.delayed(const Duration(milliseconds: 500), () {
      int correct = 0;

      for (int imageIndex = 0; imageIndex < _dishes.length; imageIndex++) {
        final userNameIndex = _userMatches[imageIndex];
        if (userNameIndex != null) {
          final selectedName = _shuffledNames[userNameIndex];
          final correctName = _dishes[imageIndex].name;

          if (selectedName == correctName) {
            correct++;
          }
        }
      }

      setState(() {
        _correctMatches = correct;
        _showResult = true;
        _isChecking = false;
      });

      if (correct == 4) {
        setState(() => _failedAttempts = 0); // Reset su successo
        _showSuccessDialog();
      } else {
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
        title: const Text(
          'PERFETTO!',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: darkColor,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Hai indovinato tutti i piatti! Torna alla home per esplorare i ristoranti.',
          style: TextStyle(fontSize: 15, color: darkColor),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRound(); // Gioca ancora
            },
            child: const Text('Gioca ancora'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Chiudi dialog
              Navigator.pop(context); // Torna alla home (Scopri tab)
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: successGold,
              foregroundColor: darkColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Vai alla Home'),
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
                fontSize: 22,
                color: darkColor,
              ),
            ),
          ],
        ),
        content: Text(
          'Hai indovinato $_correctMatches su 4 piatti.\nVuoi riprovare o tornare indietro?',
          style: const TextStyle(fontSize: 15, color: grayColor),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Torna alla tab Scopri
            },
            style: TextButton.styleFrom(
              foregroundColor: grayColor,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
            child: const Text(
              'Esci',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRound(); // Riprova
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/icons8-ingredienti-48.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'Come si gioca?',
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
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Sei il detective del menu! Abbina ogni piatto al suo nome giusto. Sembra facile? Beh, proviamoci! 😏',
                style: TextStyle(fontSize: 14, color: grayColor, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                '🕹️ Come funziona',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '1. Tap su un piatto\n'
                '2. Tap sul nome che pensi sia corretto\n'
                '3. Ripeti per tutti e 4 i piatti\n'
                '4. Incrocia le dita! 🤞',
                style: TextStyle(fontSize: 14, color: grayColor, height: 1.6),
              ),
              SizedBox(height: 16),
              Text(
                '💡 Trucchetto',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: darkColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Se sbagli 2 volte, ti do un aiutino speciale. Ma non esagerare, eh! 😉',
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ho capito! 🚀',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  void _showHelpDialog(VoidCallback onContinue) {
    final List<String> hints = [
      'Ti regalo un super aiuto! 🎁\nHo abbinato 2 piatti per te,\ntrova gli altri 2!',
      'Colpo di fortuna! 🍀\nHo fatto metà del lavoro,\nabbina i rimanenti 2 piatti!',
      'Aiutino dello chef! 👨‍🍳\nTi ho già abbinato 2 piatti,\na te trovare gli ultimi 2!',
      'Regalo speciale! ✨\nDue piatti già abbinati,\ncompl eta gli altri 2!',
    ];

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
    if (_dishes.isEmpty || _shuffledNames.isEmpty) return;

    // Auto-abbina 2 piatti corretti casuali su 4
    final List<int> availableIndices = [0, 1, 2, 3];
    availableIndices.shuffle();

    // Prendi i primi 2 indici casuali
    final toAutoMatch = availableIndices.take(2).toList();

    setState(() {
      _userMatches.clear();
      _showResult = false;

      // Auto-abbina questi 2 piatti
      for (final imageIndex in toAutoMatch) {
        final correctName = _dishes[imageIndex].name;
        final nameIndex = _shuffledNames.indexOf(correctName);
        if (nameIndex != -1) {
          _userMatches[imageIndex] = nameIndex;
        }
      }
    });

    // Mostra conferma
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Ho abbinato 2 piatti per te! Trova gli altri 2! 🔍',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: successGold,
      ),
    );
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
              'assets/icons/icons8-ingredienti-48.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Dish Match',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Istruzioni rimosse - ora nel dialog info

          // Griglia 2x2 delle immagini
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemCount: _dishes.length,
            itemBuilder: (context, index) => _buildDishImage(index),
          ),
          const SizedBox(height: 20),

          // Nomi dei piatti (bottoni)
          const Text(
            'Seleziona il nome:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 8),
          ..._shuffledNames.asMap().entries.map(
            (entry) => _buildNameButton(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildDishImage(int imageIndex) {
    final dish = _dishes[imageIndex];
    final isSelected = _selectedImageIndex == imageIndex;
    final hasMatch = _userMatches.containsKey(imageIndex);
    final matchedNameIndex = _userMatches[imageIndex];

    // Determina il colore del bordo
    Color borderColor = lightGrayColor;
    if (_showResult && hasMatch) {
      final selectedName = _shuffledNames[matchedNameIndex!];
      final correctName = dish.name;
      borderColor = selectedName == correctName ? Colors.green : Colors.red;
    } else if (isSelected) {
      borderColor = primaryDarkPink;
    } else if (hasMatch) {
      borderColor = successGold;
    }

    return AnimatedBuilder(
      animation: _cardAnimations[imageIndex]!,
      builder: (context, child) {
        final scale = 0.95 + (_cardAnimations[imageIndex]!.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () => _onImageTap(imageIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: lightColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 4 : (hasMatch ? 3 : 2),
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: primaryDarkPink.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                      child: Stack(
                        children: [
                          Image.network(
                            dish.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, _, _) => Container(
                              color: lightGrayColor,
                              child: const Icon(
                                Icons.restaurant_menu,
                                size: 40,
                                color: grayColor,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryDarkPink.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (hasMatch && matchedNameIndex != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _showResult
                            ? (_shuffledNames[matchedNameIndex] == dish.name
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1))
                            : successGold.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(13),
                        ),
                      ),
                      child: Text(
                        _shuffledNames[matchedNameIndex],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _showResult
                              ? (_shuffledNames[matchedNameIndex] == dish.name
                                    ? Colors.green
                                    : Colors.red)
                              : darkColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNameButton(int nameIndex, String name) {
    final isUsed = _userMatches.values.contains(nameIndex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: isUsed
                ? [lightGrayColor, lightGrayColor]
                : [accentYellow, successGold],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (!isUsed)
              BoxShadow(
                color: accentYellow.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isUsed ? null : () => _onNameTap(nameIndex),
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isUsed)
                    Icon(Icons.check_circle, size: 20, color: grayColor),
                  if (isUsed) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isUsed ? grayColor : darkColor,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
