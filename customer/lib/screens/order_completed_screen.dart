import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../services/fcm_service.dart';
import 'dart:math' as math;
import 'live_orders_screen.dart';

/// Screen esplosivo per ordine completato con effetti festivi
class OrderCompletedScreen extends StatefulWidget {
  final int orderId;
  final String deliveryType;

  /// Info riepilogo mostrate al cliente subito dopo l'ordine. Opzionali per
  /// retrocompatibilita': se non passate, il riepilogo non viene mostrato.
  final String? orarioConsegna; // es. "Oggi, 13:30 - 14:00"
  final double? totale;
  final String? indirizzo;

  const OrderCompletedScreen({
    super.key,
    required this.orderId,
    required this.deliveryType,
    this.orarioConsegna,
    this.totale,
    this.indirizzo,
  });

  @override
  State<OrderCompletedScreen> createState() => _OrderCompletedScreenState();
}

class _OrderCompletedScreenState extends State<OrderCompletedScreen>
    with TickerProviderStateMixin {
  static const Color primaryColor = AppColors.primary;

  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    // Animazione di scala per il logo
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Animazione fade per il testo
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Animazione bounce per il bottone
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.bounceOut,
    );

    // Avvia le animazioni in sequenza
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _bounceController.forward();
    });

    // Il momento giusto per chiedere le notifiche: l'ordine e' appena stato
    // confermato e il beneficio ("ti avvisiamo quando arriva") e' concreto.
    // Pre-prompt nostro UNA VOLTA sola; il prompt di sistema parte solo se
    // l'utente accetta.
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) _maybeAskNotifications();
    });
  }

  Future<void> _maybeAskNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_prompt_done') ?? false) return;
    await prefs.setBool('notif_prompt_done', true);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 42,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            const Text(
              'Vuoi sapere quando arriva?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ti avvisiamo quando il tuo ordine viene confermato, '
              'preparato e consegnato.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  FcmService().requestPermissionWithContext();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Attiva le notifiche',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(
                'Non ora',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Sfondo con immagine e overlay velato
          Positioned.fill(
            child: Stack(
              children: [
                // Immagine di sfondo
                Image.asset(
                  'assets/images/order_background.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Overlay velato per attenuare i colori forti
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.7),
                        Colors.white.withOpacity(0.5),
                        Colors.white.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Coriandoli animati
          ...List.generate(
            20,
            (index) => _Confetti(
              delay: index * 50,
              left: (index % 5) * (MediaQuery.of(context).size.width / 5),
            ),
          ),

          // Contenuto principale
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Logo "ordine confermato" con animazione
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Image.asset(
                      'assets/images/ordine confermato.png',
                      width: MediaQuery.of(context).size.width * 0.75,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Testo con fade animation in card glassmorphism
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Fantastico!',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Ordine #${widget.orderId}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.deliveryType == 'delivery'
                                ? 'Il tuo cibo sta arrivando!\nRelax, pensiamo a tutto noi.'
                                : widget.deliveryType == 'pickup'
                                ? 'Perfetto! Passa a ritirarlo.\nTi aspettiamo con il tuo ordine pronto!'
                                : 'Il tuo ordine è stato confermato.\nGrazie per aver ordinato con Lenny!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          _buildRiepilogo(),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bottoni con bounce animation
                ScaleTransition(
                  scale: _bounceAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        // Primario: segui il tuo ordine (porta al tracking)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const LiveOrdersScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.local_shipping_outlined,
                                size: 20),
                            label: const Text(
                              'Segui il tuo ordine',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: primaryColor.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Secondario: torna alla home
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            child: Text(
                              'Torna alla Home',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Riepilogo mostrato al cliente subito dopo l'ordine: quando arriva/e' pronto,
  /// dove, e quanto ha speso. Ogni riga compare solo se il dato e' disponibile.
  Widget _buildRiepilogo() {
    final righe = <Widget>[];

    if (widget.orarioConsegna != null && widget.orarioConsegna!.isNotEmpty) {
      righe.add(
        _rigaInfo(
          widget.deliveryType == 'delivery'
              ? Icons.schedule
              : Icons.storefront,
          widget.deliveryType == 'delivery' ? 'Consegna' : 'Ritiro',
          widget.orarioConsegna!,
        ),
      );
    }

    if (widget.deliveryType == 'delivery' &&
        widget.indirizzo != null &&
        widget.indirizzo!.isNotEmpty) {
      righe.add(_rigaInfo(Icons.place_outlined, 'Indirizzo', widget.indirizzo!));
    }

    if (widget.totale != null) {
      righe.add(
        _rigaInfo(
          Icons.receipt_long_outlined,
          'Totale',
          '€${widget.totale!.toStringAsFixed(2)}',
        ),
      );
    }

    if (righe.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: righe),
    );
  }

  Widget _rigaInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text(
            '$label  ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget per i coriandoli animati
class _Confetti extends StatefulWidget {
  final int delay;
  final double left;

  const _Confetti({required this.delay, required this.left});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final _random = math.Random();
  late Color _color;
  late double _rotation;

  @override
  void initState() {
    super.initState();

    // Colori casuali festivi
    final colors = [
      AppColors.primary,
      const Color(0xFFFFB74D),
      const Color(0xFF66BB6A),
      const Color(0xFF5C6BC0),
      const Color(0xFFEF5350),
      const Color(0xFFFFD700),
    ];
    _color = colors[_random.nextInt(colors.length)];
    _rotation = _random.nextDouble() * 360;

    _controller = AnimationController(
      duration: Duration(milliseconds: 2000 + _random.nextInt(1000)),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: -50,
      end: 800,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          left: widget.left + _random.nextDouble() * 50 - 25,
          top: _animation.value,
          child: Transform.rotate(
            angle: _rotation * (_animation.value / 800),
            child: Container(
              width: 8,
              height: 12,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}
