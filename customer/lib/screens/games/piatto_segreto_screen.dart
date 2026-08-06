import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../models/restaurant.dart';
import '../../services/games_service.dart';
import '../../services/restaurant_service.dart';
import '../restaurant_menu_screen.dart';

/// IL PIATTO SEGRETO — il gioco GIORNALIERO di Lenny.
///
/// Ogni giorno un piatto misterioso, uguale per tutti, da riconoscere tra
/// 12 foto usando indizi progressivi ricavati dai dati veri. Meno indizi
/// usi, piu' in alto e' il tuo "grado". Si gioca una volta al giorno: e'
/// l'appuntamento che fa tornare.
///
/// REGOLA DI PRODOTTO: nessun premio in denaro/coupon. Il payoff e' la
/// scoperta del piatto e il bottone "Ordinalo ora".
class PiattoSegretoScreen extends StatefulWidget {
  const PiattoSegretoScreen({super.key});

  @override
  State<PiattoSegretoScreen> createState() => _PiattoSegretoScreenState();
}

class _PiattoSegretoScreenState extends State<PiattoSegretoScreen> {
  final GamesService _gamesService = GamesService();

  Map<String, dynamic>? _round;
  bool _loading = true;
  String? _errore;

  int _indiziMostrati = 1;
  int _tentativiRestanti = 3;
  final Set<int> _sbagliati = {};

  /// null = in corso; true = vinto; false = rivelato dopo 3 errori
  bool? _vinto;
  int _streak = 0;

  /// Gia' giocato oggi (da SharedPreferences): si mostra l'esito
  bool _giaGiocato = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final round = await _gamesService.getPiattoSegretoOggi();
    if (!mounted) return;

    if (round == null) {
      setState(() {
        _loading = false;
        _errore = 'Il piatto segreto di oggi non è disponibile. Riprova!';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final data = round['date'] as String? ?? '';
    final esito = prefs.getString('segreto_esito_$data');
    final streak = prefs.getInt('segreto_streak') ?? 0;

    if (!mounted) return;
    setState(() {
      _round = round;
      _streak = streak;
      _loading = false;
      if (esito != null) {
        _giaGiocato = true;
        _vinto = esito == 'vinto';
      }
    });
  }

  Map<String, dynamic>? get _segreto {
    if (_round == null) return null;
    final id = _round!['secret_dish_id'];
    for (final c in (_round!['candidates'] as List)) {
      if (c['id'] == id) return Map<String, dynamic>.from(c as Map);
    }
    return null;
  }

  Future<void> _scegli(Map<String, dynamic> candidato) async {
    if (_vinto != null || _giaGiocato) return;

    final corretto = candidato['id'] == _round!['secret_dish_id'];

    if (corretto) {
      await _chiudiPartita(vinto: true);
    } else {
      setState(() {
        _sbagliati.add(candidato['id'] as int);
        _tentativiRestanti--;
        // Ogni errore regala l'indizio successivo
        if (_indiziMostrati < (_round!['clues'] as List).length) {
          _indiziMostrati++;
        }
      });
      if (_tentativiRestanti <= 0) {
        await _chiudiPartita(vinto: false);
      }
    }
  }

  Future<void> _chiudiPartita({required bool vinto}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _round!['date'] as String? ?? '';

    // Streak: vittorie in giorni consecutivi
    var streak = prefs.getInt('segreto_streak') ?? 0;
    if (vinto) {
      final ieri = DateTime.now().subtract(const Duration(days: 1));
      final ieriStr =
          '${ieri.year.toString().padLeft(4, '0')}-'
          '${ieri.month.toString().padLeft(2, '0')}-'
          '${ieri.day.toString().padLeft(2, '0')}';
      final ultimaVittoria = prefs.getString('segreto_ultima_vittoria');
      streak = (ultimaVittoria == ieriStr) ? streak + 1 : 1;
      await prefs.setString('segreto_ultima_vittoria', data);
    } else {
      streak = 0;
    }
    await prefs.setInt('segreto_streak', streak);
    await prefs.setString('segreto_esito_$data', vinto ? 'vinto' : 'perso');

    if (!mounted) return;
    setState(() {
      _vinto = vinto;
      _streak = streak;
    });
  }

  /// Apre il piatto nel menu del suo ristorante: il vero premio del gioco
  Future<void> _ordina() async {
    final segreto = _segreto;
    if (segreto == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    Restaurant? restaurant;
    try {
      restaurant = await RestaurantService().getRestaurantDetail(
        segreto['restaurant_id'] as int,
      );
    } catch (_) {
      restaurant = null;
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (restaurant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ristorante non disponibile al momento')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMenuScreen(
          restaurant: restaurant!,
          openDishId: segreto['id'] as int,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Il Piatto Segreto',
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Serie: $_streak',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errore != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _errore!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.gray),
                ),
              ),
            )
          : _vinto != null
          ? _buildEsito()
          : _buildGioco(),
    );
  }

  Widget _buildGioco() {
    final clues = (_round!['clues'] as List).cast<String>();
    final candidates = (_round!['candidates'] as List)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();

    return Column(
      children: [
        // Indizi
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Column(
            children: [
              for (var i = 0; i < _indiziMostrati && i < clues.length; i++)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [AppColors.cardShadow],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          clues[i],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_indiziMostrati < clues.length)
                    TextButton.icon(
                      onPressed: () => setState(() => _indiziMostrati++),
                      icon: const Icon(Icons.lightbulb_outline, size: 16),
                      label: const Text(
                        'Altro indizio',
                        style: TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Text(
                    _tentativiRestanti == 1
                        ? 'Ultimo tentativo!'
                        : '$_tentativiRestanti tentativi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _tentativiRestanti == 1
                          ? AppColors.danger
                          : AppColors.grayDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Griglia foto: trova il piatto che corrisponde agli indizi
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final c = candidates[index];
              final escluso = _sbagliati.contains(c['id']);
              return GestureDetector(
                onTap: escluso ? null : () => _scegli(c),
                child: Opacity(
                  opacity: escluso ? 0.25 : 1.0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Image.network(
                          c['image_url'] as String? ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.lightGray,
                            child: const Icon(
                              Icons.restaurant,
                              color: AppColors.gray,
                            ),
                          ),
                        ),
                      ),
                      if (escluso)
                        const Center(
                          child: Icon(
                            Icons.close,
                            color: AppColors.danger,
                            size: 32,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEsito() {
    final segreto = _segreto;
    if (segreto == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            _vinto == true ? 'Trovato!' : 'Era questo!',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _vinto == true
                ? (_streak > 1
                      ? 'Serie di $_streak giorni. Torna domani per continuarla!'
                      : 'Torna domani per il prossimo piatto segreto')
                : 'Domani un nuovo piatto segreto ti aspetta',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.grayDark),
          ),
          const SizedBox(height: 20),

          // Il piatto rivelato
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [AppColors.cardShadow],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.card),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      segreto['image_url'] as String? ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.lightGray),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        segreto['name'] as String? ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${segreto['restaurant_name']} · '
                        '€${(segreto['price'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.grayDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Il premio del gioco: ordinare il piatto appena scoperto
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _ordina,
              icon: const Icon(Icons.restaurant_menu, size: 20),
              label: const Text(
                'Ordinalo ora',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Torna a Scopri',
              style: TextStyle(fontSize: 14, color: AppColors.grayDark),
            ),
          ),
        ],
      ),
    );
  }
}
