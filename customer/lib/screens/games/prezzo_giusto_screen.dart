import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/restaurant.dart';
import '../../services/games_service.dart';
import '../../services/restaurant_service.dart';
import '../restaurant_menu_screen.dart';
import '../../widgets/foto_rete.dart';

/// IL PREZZO E' GIUSTO? — round infiniti di scoperta del menu.
///
/// Un piatto vero con foto: l'utente stima il prezzo con lo slider e
/// scopre quanto ci e' andato vicino. Ogni round e' un piatto che magari
/// non conosceva, con il bottone "Ordinalo" a un tap.
///
/// REGOLA DI PRODOTTO: nessun premio in denaro/coupon. Il payoff e' la
/// scoperta e la CTA d'ordine.
class PrezzoGiustoScreen extends StatefulWidget {
  const PrezzoGiustoScreen({super.key});

  @override
  State<PrezzoGiustoScreen> createState() => _PrezzoGiustoScreenState();
}

class _PrezzoGiustoScreenState extends State<PrezzoGiustoScreen> {
  final GamesService _gamesService = GamesService();

  Map<String, dynamic>? _dish;
  bool _loading = true;
  String? _errore;

  double _stima = 0;
  double _sliderMax = 20;
  bool _confermato = false;

  // Punteggio di sessione: quante stime "da chef" (entro il 15%)
  int _round = 0;
  int _centrati = 0;

  @override
  void initState() {
    super.initState();
    _caricaRound();
  }

  Future<void> _caricaRound() async {
    setState(() {
      _loading = true;
      _confermato = false;
      _errore = null;
    });

    final dish = await _gamesService.getPrezzoGiustoRound();
    if (!mounted) return;

    if (dish == null) {
      setState(() {
        _loading = false;
        _errore = 'Nessun piatto disponibile al momento. Riprova!';
      });
      return;
    }

    final prezzo = (dish['price'] as num).toDouble();
    // Slider: da 1 al doppio del prezzo (arrotondato ai 5), cosi' il
    // valore vero non e' mai al centro esatto
    final max = (math.max(prezzo * 2, 10) / 5).ceil() * 5.0;

    setState(() {
      _dish = dish;
      _sliderMax = max;
      _stima = (max / 2).roundToDouble();
      _loading = false;
    });
  }

  double get _prezzoVero => (_dish!['price'] as num).toDouble();

  /// Scarto percentuale della stima
  double get _scarto =>
      ((_stima - _prezzoVero).abs() / _prezzoVero * 100).clamp(0, 999);

  String get _giudizio {
    final s = _scarto;
    if (s <= 5) return 'Palato assoluto!';
    if (s <= 15) return 'Quasi da chef';
    if (s <= 30) return 'Ci sei andato vicino';
    return 'Da assaggiare per credere';
  }

  void _conferma() {
    if (_confermato) return;
    setState(() {
      _confermato = true;
      _round++;
      if (_scarto <= 15) _centrati++;
    });
  }

  Future<void> _ordina() async {
    final dish = _dish;
    if (dish == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    Restaurant? restaurant;
    try {
      restaurant = await RestaurantService().getRestaurantDetail(
        dish['restaurant_id'] as int,
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
          openDishId: dish['id'] as int,
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
          'Il Prezzo è Giusto?',
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_round > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '$_centrati/$_round',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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
          : _buildRound(),
    );
  }

  Widget _buildRound() {
    final dish = _dish!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Foto del piatto: la protagonista
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
                    child: FotoRete(
                      dish['image_url'] as String? ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.lightGray),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Text(
                        dish['name'] as String? ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dish['restaurant_name'] as String? ?? '',
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

          if (!_confermato) ...[
            const Text(
              'Quanto costa secondo te?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '€${_stima.toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Slider(
              value: _stima,
              min: 1,
              max: _sliderMax,
              divisions: ((_sliderMax - 1) * 2).round(),
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _stima = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _conferma,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                child: const Text(
                  'Conferma',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            // Esito del round
            Text(
              _giudizio,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Text(
                      'La tua stima',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grayDark,
                      ),
                    ),
                    Text(
                      '€${_stima.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Column(
                  children: [
                    const Text(
                      'Prezzo vero',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grayDark,
                      ),
                    ),
                    Text(
                      '€${_prezzoVero.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _ordina,
                icon: const Icon(Icons.restaurant_menu, size: 20),
                label: const Text(
                  'Ordinalo',
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
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _caricaRound,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                child: const Text(
                  'Prossimo piatto',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
