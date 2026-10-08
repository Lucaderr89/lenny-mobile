import 'package:flutter/material.dart';
import '../widgets/app_icon.dart';
import '../config/app_colors.dart';
import '../services/order_service.dart';
import 'dart:async';
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

  final OrderService _orderService = OrderService();

  /// Ricevuta via email: invio in corso, oppure gia' partita (a che indirizzo).
  bool _invioRicevuta = false;
  String? _ricevutaInviataA;

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

    // NB: qui non si chiedono piu' le notifiche. Il permesso viene chiesto
    // una volta sola al primo avvio, insieme al GPS, dal dialog che spiega
    // entrambi (FirstLaunchLocationDialog): un secondo pre-prompt a ordine
    // concluso sarebbe un modale in piu' senza aggiungere nulla.
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
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0.7),
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
                // Parte alta scrollabile: sugli schermi bassi il blocco
                // fisso (logo + card riepilogo) sforava di ~16px.
                // I bottoni restano ancorati in fondo.
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
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
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
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

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

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
                                  builder: (context) =>
                                      const LiveOrdersScreen(),
                                ),
                              );
                            },
                            icon: const AppIcon(
                              'assets/icons_svg/lenny-consegna.svg',
                              size: 20,
                            ),
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
                              shadowColor: primaryColor.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Ricevuta PDF via email, su richiesta
                        _buildRicevuta(),
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

  /// Il server genera la ricevuta PDF e la manda all'email dell'account.
  /// Se non parte, il motivo (limite di invii, email mancante, posta del
  /// server giu') arriva dal server e si mostra cosi' com'e'.
  Future<void> _richiediRicevuta() async {
    setState(() => _invioRicevuta = true);
    try {
      final email = await _orderService.richiediRicevutaEmail(widget.orderId);
      if (!mounted) return;
      setState(
        () => _ricevutaInviataA = email.isNotEmpty ? email : 'la tua email',
      );
    } on TimeoutException {
      if (!mounted) return;
      _avvisoRicevuta('Il server non risponde: riprova tra poco');
    } catch (e) {
      if (!mounted) return;
      _avvisoRicevuta(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _invioRicevuta = false);
    }
  }

  void _avvisoRicevuta(String testo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testo),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Tasto "Ricevi la ricevuta via email". Una volta partita lascia il posto
  /// alla conferma con l'indirizzo: non serve mandarla due volte.
  Widget _buildRicevuta() {
    final inviataA = _ricevutaInviataA;
    if (inviataA != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF66BB6A), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ricevuta inviata a $inviataA',
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

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _invioRicevuta ? null : _richiediRicevuta,
        icon: _invioRicevuta
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const AppIcon(
                'assets/icons_svg/icons8-email-32.svg',
                size: 20,
                color: primaryColor,
              ),
        label: Text(
          _invioRicevuta ? 'Invio in corso...' : 'Ricevi la ricevuta via email',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          backgroundColor: Colors.white.withValues(alpha: 0.85),
          side: BorderSide(
            color: primaryColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
              ? 'assets/icons_svg/icons8-orologio-32.svg'
              : 'assets/icons_svg/icons8-negozio-32.svg',
          widget.deliveryType == 'delivery' ? 'Consegna' : 'Ritiro',
          widget.orarioConsegna!,
        ),
      );
    }

    if (widget.deliveryType == 'delivery' &&
        widget.indirizzo != null &&
        widget.indirizzo!.isNotEmpty) {
      righe.add(
        _rigaInfo(
          'assets/icons_svg/icons8-location-32.svg',
          'Indirizzo',
          widget.indirizzo!,
        ),
      );
    }

    if (widget.totale != null) {
      righe.add(
        _rigaInfo(
          'assets/icons_svg/icons8-fattura-32.svg',
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

  Widget _rigaInfo(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text(
            '$label  ',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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
