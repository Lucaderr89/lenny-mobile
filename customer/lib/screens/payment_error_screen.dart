import 'package:flutter/material.dart';
import '../widgets/app_icon.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import 'nexi_payment_screen.dart';
import 'order_completed_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

class PaymentErrorScreen extends StatefulWidget {
  final int? orderId;
  final String? errorMessage;
  final String? errorCode;

  const PaymentErrorScreen({
    super.key,
    this.orderId,
    this.errorMessage,
    this.errorCode,
  });

  @override
  State<PaymentErrorScreen> createState() => _PaymentErrorScreenState();
}

class _PaymentErrorScreenState extends State<PaymentErrorScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;
  bool _isChangingMethod = false;

  @override
  void initState() {
    super.initState();

    // Animazione principale (scale + fade)
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Animazione shake separata (solo per il cerchio)
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    _animationController.forward();

    // Avvia shake dopo l'animazione iniziale
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// 🔄 Riprova pagamento con carta (reset ordine a waiting_payment)
  Future<void> _retryWithCard() async {
    setState(() => _isChangingMethod = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      if (token == null || widget.orderId == null) {
        _showError('Errore: sessione scaduta');
        return;
      }

      // Resetta payment_status da 'failed' a 'waiting_payment'
      final response = await http.put(
        Uri.parse(
          '${AppConstants.baseUrl}/api/orders/${widget.orderId}/reset-payment',
        ),
        headers: {'Content-Type': 'application/json', 'X-API-Token': token},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Riapri pagamento Nexi
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    NexiPaymentScreen(orderId: widget.orderId!),
              ),
            );
          }
        } else {
          _showError(data['error'] ?? 'Errore sconosciuto');
        }
      } else {
        _showError('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Errore di connessione: $e');
    } finally {
      if (mounted) {
        setState(() => _isChangingMethod = false);
      }
    }
  }

  /// 🔄 Cambia metodo di pagamento e riprova
  Future<void> _changePaymentMethod() async {
    setState(() => _isChangingMethod = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      if (token == null || widget.orderId == null) {
        _showError('Errore: sessione scaduta');
        return;
      }

      // Mostra dialog per scegliere metodo
      final newMethodId = await _showPaymentMethodDialog();

      if (newMethodId == null) {
        setState(() => _isChangingMethod = false);
        return;
      }

      // Aggiorna metodo nel DB e resetta payment_status a 'pending'
      final response = await http.put(
        Uri.parse(
          '${AppConstants.baseUrl}/api/orders/${widget.orderId}/payment-method',
        ),
        headers: {'Content-Type': 'application/json', 'X-API-Token': token},
        body: json.encode({
          'payment_method_id': newMethodId,
          'reset_payment_status': true, // Reset da failed a pending
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Svuota il carrello (ordine confermato con nuovo metodo)
          final cartProvider = Provider.of<CartProvider>(
            context,
            listen: false,
          );
          cartProvider.clearCart();

          // Stessa schermata di conferma di tutti gli altri flussi.
          // Il tipo ordine non e' noto in questo contesto: copy neutro.
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => OrderCompletedScreen(
                  orderId: widget.orderId!,
                  deliveryType: '',
                ),
              ),
            );
          }
        } else {
          _showError(data['error'] ?? 'Errore sconosciuto');
        }
      } else {
        _showError('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Errore di connessione: $e');
    } finally {
      if (mounted) {
        setState(() => _isChangingMethod = false);
      }
    }
  }

  /// Mostra dialog per scegliere metodo pagamento (escluso Nexi)
  Future<int?> _showPaymentMethodDialog() async {
    // Metodi disponibili (escluso Nexi ID 5)
    final availableMethods = [
      {
        'id': 1,
        'name': 'Contanti alla consegna',
        'icon': 'assets/icons_svg/icons8-soldi-32.svg',
        'color': Colors.green,
      },
      {
        'id': 2,
        'name': 'POS/Bancomat alla consegna',
        'icon': 'assets/icons_svg/icons8-carta-32.svg',
        'color': Colors.blue,
      },
      {
        'id': 3,
        'name': 'SMAC',
        'icon': 'assets/icons_svg/icons8-card-32.svg',
        'color': AppColors.primary,
      },
    ];

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scegli metodo di pagamento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableMethods.map((method) {
              return ListTile(
                leading: AppIcon(
                  method['icon'] as String,
                  size: 24,
                  color: method['color'] as Color,
                ),
                title: Text(method['name'] as String),
                onTap: () => Navigator.pop(context, method['id'] as int),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Previeni back
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Icona errore animata
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.2),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 70,
                            color: Colors.red.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Titolo con fade
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Pagamento Rifiutato',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // Messaggio errore
                if (widget.errorMessage != null)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        widget.errorMessage!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Info ordine
                if (widget.orderId != null)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIcon(
                                'assets/icons_svg/icons8-fattura-32.svg',
                                color: Colors.grey.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ordine #${widget.orderId}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'L\'ordine è stato creato ma non pagato',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),

                // Pulsanti
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      if (widget.orderId != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isChangingMethod
                                ? null
                                : _retryWithCard,
                            icon: _isChangingMethod
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.refresh, size: 20),
                            label: const Text(
                              'Riprova con Carta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isChangingMethod
                                ? null
                                : _changePaymentMethod,
                            icon: const Icon(Icons.swap_horiz, size: 20),
                            label: const Text(
                              'Cambia Metodo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          icon: const AppIcon(
                            'assets/icons_svg/icons8-home-32.svg',
                            size: 20,
                          ),
                          label: const Text(
                            'Torna alla Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
