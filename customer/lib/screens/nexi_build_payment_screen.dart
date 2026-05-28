import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_success_screen.dart';
import 'payment_error_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

/// 🆕 XPay Build Payment Screen con InAppWebView
///
/// Caratteristiche:
/// - InAppWebView con JavaScript bridge bidirezionale
/// - Comunicazione WebView ↔ Flutter via JavaScript handlers
/// - Caricamento pagina custom nexi_build_payment.html
/// - Supporto OneClick (salvataggio carte)
/// - Gestione eventi: success, error, cancel
class NexiBuildPaymentScreen extends StatefulWidget {
  final int orderId;
  final bool saveCard;
  final String? numContratto; // Per pagamenti successivi OneClick

  const NexiBuildPaymentScreen({
    super.key,
    required this.orderId,
    this.saveCard = false,
    this.numContratto, // null = primo pagamento, != null = successivo
  });

  @override
  State<NexiBuildPaymentScreen> createState() => _NexiBuildPaymentScreenState();
}

class _NexiBuildPaymentScreenState extends State<NexiBuildPaymentScreen> {
  static const Color primaryColor = Color(0xFFFF7566);
  static const Color darkColor = Color(0xFF212121);

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _loadingProgress = 0;

  // Dati sessione Build
  String? _paymentUrl;
  Map<String, dynamic>? _buildConfig;

  @override
  void initState() {
    super.initState();
    _initializeBuildPayment();
  }

  /// Inizializza pagamento XPay Build
  Future<void> _initializeBuildPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      if (token == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Sessione scaduta. Effettua nuovamente il login.';
        });
        return;
      }

      print(
        '🚀 [NEXI BUILD] Init payment - Order: ${widget.orderId}, SaveCard: ${widget.saveCard}, NumContratto: ${widget.numContratto}',
      );

      // Chiama API backend per inizializzare Build session
      final requestBody = {
        'order_id': widget.orderId,
        'save_card': widget.saveCard,
      };

      // Se è un pagamento successivo OneClick, passa num_contratto
      if (widget.numContratto != null) {
        requestBody['num_contratto'] = widget.numContratto!;
      }

      print('📤 [NEXI BUILD] Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/nexi/init-build-payment'),
        headers: {'Content-Type': 'application/json', 'X-API-Token': token},
        body: json.encode(requestBody),
      );

      print('🔵 [NEXI BUILD] Response status: ${response.statusCode}');
      print('🔵 [NEXI BUILD] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            _paymentUrl = data['data']['payment_url'] as String;
            _buildConfig = data['data']['build_config'] as Map<String, dynamic>;
          });

          print('✅ [NEXI BUILD] Payment URL: $_paymentUrl');
          print('✅ [NEXI BUILD] Config received');
        } else {
          throw Exception(
            data['message'] ?? 'Errore inizializzazione pagamento',
          );
        }
      } else {
        throw Exception('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [NEXI BUILD] Error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Errore inizializzazione pagamento: $e';
      });
    }
  }

  /// Gestisce completamento pagamento
  Future<void> _handlePaymentComplete(Map<String, dynamic> eventData) async {
    print('✅ [NEXI BUILD] Payment completed!');
    print('📊 [NEXI BUILD] Event data: $eventData');

    // ✅ SVUOTA IL CARRELLO dopo pagamento riuscito
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.clearCart();
      print('🛒 [NEXI BUILD] Cart cleared after successful payment');
    } catch (e) {
      print('⚠️ [NEXI BUILD] Error clearing cart: $e');
    }

    // Naviga allo schermo di successo
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PaymentSuccessScreen(orderId: widget.orderId),
        ),
      );
    }
  }

  /// Gestisce errore pagamento
  void _handlePaymentError(Map<String, dynamic> eventData) {
    print('❌ [NEXI BUILD] Payment error!');
    print('📊 [NEXI BUILD] Error data: $eventData');

    final errorMessage =
        eventData['error_message'] as String? ??
        eventData['error'] as String? ??
        'Pagamento non riuscito';

    // Naviga allo schermo di errore
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PaymentErrorScreen(
            orderId: widget.orderId,
            errorMessage: errorMessage,
            errorCode: eventData['error_code'] as String?,
          ),
        ),
      );
    }
  }

  /// Gestisce annullamento pagamento
  void _handlePaymentCancel(Map<String, dynamic> eventData) {
    print('⚠️ [NEXI BUILD] Payment cancelled');

    // Torna indietro
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Chiedi conferma prima di uscire
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Annulla pagamento?'),
            content: const Text('Vuoi davvero annullare il pagamento?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sì', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(backgroundColor: Colors.white, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return _buildErrorView();
    }

    if (_paymentUrl == null || _buildConfig == null) {
      return _buildLoadingView();
    }

    return Stack(
      children: [
        // InAppWebView
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_paymentUrl!)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            useHybridComposition: true,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            // iOS specific
            allowsBackForwardNavigationGestures: false,
            // Android specific
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          ),
          onWebViewCreated: (controller) {
            // 🔥 REGISTRA JAVASCRIPT HANDLERS per comunicazione WebView → Flutter
            controller.addJavaScriptHandler(
              handlerName: 'PAYMENT_SUCCESS',
              callback: (args) {
                print('📥 [FLUTTER] Received PAYMENT_SUCCESS');
                final data = args.isNotEmpty && args[0] is Map
                    ? Map<String, dynamic>.from(args[0] as Map)
                    : <String, dynamic>{};
                _handlePaymentComplete(data);
              },
            );

            controller.addJavaScriptHandler(
              handlerName: 'PAYMENT_ERROR',
              callback: (args) {
                print('📥 [FLUTTER] Received PAYMENT_ERROR');
                final data = args.isNotEmpty && args[0] is Map
                    ? Map<String, dynamic>.from(args[0] as Map)
                    : <String, dynamic>{};
                _handlePaymentError(data);
              },
            );

            controller.addJavaScriptHandler(
              handlerName: 'PAYMENT_CANCEL',
              callback: (args) {
                print('📥 [FLUTTER] Received PAYMENT_CANCEL');
                final data = args.isNotEmpty && args[0] is Map
                    ? Map<String, dynamic>.from(args[0] as Map)
                    : <String, dynamic>{};
                _handlePaymentCancel(data);
              },
            );

            print('✅ [NEXI BUILD] JavaScript handlers registered');
          },
          onLoadStart: (controller, url) {
            print('📄 [NEXI BUILD] Page load started: $url');
          },
          onLoadStop: (controller, url) async {
            print('✅ [NEXI BUILD] Page loaded: $url');

            // Invia configurazione Build E token API alla pagina HTML
            final prefs = await SharedPreferences.getInstance();
            final apiToken = prefs.getString('api_token') ?? '';

            final configJson = json.encode(_buildConfig);
            await controller.evaluateJavascript(
              source:
                  '''
              window.postMessage({
                type: 'BUILD_CONFIG',
                config: $configJson,
                apiToken: '$apiToken'
              }, '*');
            ''',
            );

            print('📤 [NEXI BUILD] Config sent to WebView');

            setState(() {
              _isLoading = false;
            });
          },
          onProgressChanged: (controller, progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onConsoleMessage: (controller, consoleMessage) {
            // Log console JavaScript per debug
            print('🖥️ [JS CONSOLE] ${consoleMessage.message}');
          },
          onReceivedError: (controller, request, error) {
            print('❌ [WEBVIEW ERROR] ${error.description}');
          },
        ),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Caricamento pagamento sicuro...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: _loadingProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Inizializzazione pagamento...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Errore',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Torna indietro',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
