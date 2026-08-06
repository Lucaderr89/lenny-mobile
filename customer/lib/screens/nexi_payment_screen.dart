import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'order_completed_screen.dart';
import 'payment_error_screen.dart';

/// Schermata WebView per pagamento Nexi
/// Carica URL di pagamento Nexi, intercetta redirect di ritorno
class NexiPaymentScreen extends StatefulWidget {
  final int orderId;

  const NexiPaymentScreen({super.key, required this.orderId});

  @override
  State<NexiPaymentScreen> createState() => _NexiPaymentScreenState();
}

class _NexiPaymentScreenState extends State<NexiPaymentScreen> {
  static const Color primaryColor = AppColors.primary;
  static const Color darkColor = AppColors.dark;

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _returnUrl;
  bool _isRedirecting = true; // Nasconde WebView durante redirect iniziale
  int _loadingProgress = 0; // 🚀 OTTIMIZZAZIONE: Progress bar

  @override
  void initState() {
    super.initState();
    _initializePayment();
    // 🚀 OTTIMIZZAZIONE: Timeout di sicurezza 60 secondi
    _setLoadingTimeout();
  }

  /// 🚀 OTTIMIZZAZIONE: Timeout di sicurezza per evitare loading infinito
  void _setLoadingTimeout() {
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && _isLoading) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'Timeout: il caricamento sta impiegando troppo tempo. Riprova.';
        });
      }
    });
  }

  /// Inizializza il pagamento chiamando l'endpoint backend
  Future<void> _initializePayment() async {
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

      // Chiama API backend per ottenere URL di pagamento
      print(
        '🔵 [NEXI] Chiamata init-payment-mobile per ordine ${widget.orderId}',
      );
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/nexi/init-payment-mobile'),
        headers: {'Content-Type': 'application/json', 'X-API-Token': token},
        body: json.encode({'order_id': widget.orderId}),
      );

      print('🔵 [NEXI] Response status: ${response.statusCode}');
      print('🔵 [NEXI] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final paymentUrl = data['data']['payment_url'] as String;
          _returnUrl = data['data']['return_url'] as String;

          print('🔵 [NEXI] Payment URL: $paymentUrl');
          print('🔵 [NEXI] Return URL: $_returnUrl');

          // Inizializza WebView con URL di pagamento
          _controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            // 🚀 OTTIMIZZAZIONE: Abilita cache per velocizzare caricamenti
            ..enableZoom(false)
            // 🚀 OTTIMIZZAZIONE: Imposta user agent per evitare versione mobile lenta
            ..setUserAgent(
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            )
            // 🚀 OTTIMIZZAZIONE: Background bianco per ridurre flash
            ..setBackgroundColor(Colors.white)
            ..setNavigationDelegate(
              NavigationDelegate(
                onProgress: (int progress) {
                  // 🚀 OTTIMIZZAZIONE: Mostra progress durante il caricamento
                  if (mounted) {
                    setState(() {
                      _loadingProgress = progress;
                    });
                  }
                },
                onPageStarted: (String url) {
                  print('📄 Pagina iniziata: $url');

                  // 🚀 OTTIMIZZAZIONE: Mostra WebView subito al primo caricamento Nexi
                  if (url.contains('nexi.it') && _isRedirecting) {
                    setState(() {
                      _isRedirecting = false;
                      _isLoading = false;
                    });
                    print('✅ Form Nexi caricato');
                  }

                  // Intercetta quando Nexi fa redirect al nostro sito
                  if (url.contains('lenny-staging.com') &&
                      !url.contains('nexi.it')) {
                    print('🔍 Redirect intercettato, parsing parametri...');

                    // Parse URL per estrarre parametri
                    try {
                      final uri = Uri.parse(url);
                      final esito = uri.queryParameters['esito'];
                      final messaggio = uri.queryParameters['messaggio'];
                      final codiceEsito = uri.queryParameters['codiceEsito'];

                      print('📊 Esito: $esito');
                      print('📊 Messaggio: $messaggio');
                      print('📊 Codice: $codiceEsito');

                      if (esito == 'OK') {
                        print('✅ Pagamento RIUSCITO');
                        // Svuota il carrello: in questo flusso (retry da
                        // errore) nessun altro lo fa.
                        try {
                          Provider.of<CartProvider>(
                            context,
                            listen: false,
                          ).clearCart();
                        } catch (_) {}
                        // Stessa schermata di conferma di tutti gli altri
                        // flussi. Qui il tipo ordine non e' noto: copy neutro.
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => OrderCompletedScreen(
                                  orderId: widget.orderId,
                                  deliveryType: '',
                                ),
                              ),
                            );
                          }
                        });
                      } else if (esito == 'KO') {
                        print('❌ Pagamento FALLITO');
                        // Vai allo schermo di errore
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => PaymentErrorScreen(
                                  orderId: widget.orderId,
                                  errorMessage: messaggio?.replaceAll('+', ' '),
                                  errorCode: codiceEsito,
                                ),
                              ),
                            );
                          }
                        });
                      } else {
                        print('⚠️ Esito sconosciuto: $esito');
                      }
                    } catch (e) {
                      print('❌ Errore parsing URL: $e');
                    }
                  }
                },
                onPageFinished: (String url) {
                  print('✅ Pagina caricata: $url');
                  // 🚀 OTTIMIZZAZIONE: Nascondi loader appena finisce il caricamento
                  if (url.contains('nexi.it') && _isLoading) {
                    setState(() {
                      _isLoading = false;
                      _isRedirecting = false;
                    });
                  }
                },
                onWebResourceError: (WebResourceError error) {
                  // 🚀 OTTIMIZZAZIONE: Log più leggero, errori ignorati solo se non critici
                  if (error.errorCode != -1) {
                    print('⚠️ Errore WebView ignorato: ${error.description}');
                  }
                },
                // 🚀 NUOVA OTTIMIZZAZIONE: Impedisce navigazione a URL esterni non necessari
                onNavigationRequest: (NavigationRequest request) {
                  // Permetti solo Nexi e il nostro dominio
                  if (request.url.contains('nexi.it') ||
                      request.url.contains('lenny-staging.com')) {
                    return NavigationDecision.navigate;
                  }
                  print('🚫 Navigazione bloccata: ${request.url}');
                  return NavigationDecision.prevent;
                },
              ),
            )
            ..loadRequest(Uri.parse(paymentUrl));

          setState(() {
            _isLoading = false;
          });
        } else {
          print('❌ [NEXI] API error: ${data['error']}');
          setState(() {
            _hasError = true;
            _errorMessage =
                data['error'] ?? 'Errore nell\'inizializzazione del pagamento';
          });
        }
      } else {
        print('❌ [NEXI] HTTP error ${response.statusCode}: ${response.body}');
        setState(() {
          _hasError = true;
          _errorMessage = 'Errore del server (${response.statusCode})';
        });
      }
    } catch (e) {
      print('❌ Errore inizializzazione pagamento: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Errore di connessione al server';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Previeni back durante il pagamento
        return false;
      },
      child: Scaffold(backgroundColor: Colors.white, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: darkColor),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || _isRedirecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🚀 OTTIMIZZAZIONE: Progress indicator con percentuale
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 6,
                    value: _loadingProgress > 0 ? _loadingProgress / 100 : null,
                  ),
                  if (_loadingProgress > 0)
                    Text(
                      '$_loadingProgress%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              _loadingProgress > 0
                  ? 'Caricamento pagamento... $_loadingProgress%'
                  : 'Connessione al gateway di pagamento...',
              style: const TextStyle(fontSize: 16, color: darkColor),
            ),
            const SizedBox(height: 10),
            // 🚀 OTTIMIZZAZIONE: Messaggio rassicurante
            const Text(
              'L\'operazione potrebbe richiedere alcuni secondi',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 🚀 OTTIMIZZAZIONE: Stack con progress bar in cima alla WebView
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        // Mostra progress bar sottile in cima se sta ancora caricando
        if (_loadingProgress > 0 && _loadingProgress < 100)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _loadingProgress / 100,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 3,
            ),
          ),
      ],
    );
  }
}
