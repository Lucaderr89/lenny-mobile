import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';

/// Schermata WebView in-app per link esterni (es. Spesa).
/// Mostra un header con freccia indietro e tasto refresh.
///
/// Se [useLennySso] è true, l'URL viene arricchito con
/// `?email=...&magicHash=...` per l'autologin SSO Lenny.
class ExternalWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  /// Se true, aggiunge i parametri SSO Lenny all'URL prima di aprire la pagina.
  final bool useLennySso;

  const ExternalWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.useLennySso = false,
  });

  @override
  State<ExternalWebViewScreen> createState() => _ExternalWebViewScreenState();
}

class _ExternalWebViewScreenState extends State<ExternalWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  /// Chiede al SERVER i parametri SSO del cliente autenticato.
  ///
  /// Il magicHash non viene piu' calcolato qui: il segreto condiviso non deve
  /// stare nell'app, altrimenti chi decompila l'APK puo' generare l'hash di
  /// qualunque email e impersonare altri utenti.
  static Future<Map<String, String>?> _fetchSsoParams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);
      if (token == null || token.isEmpty) return null;

      final response = await http
          .get(
            Uri.parse('${AppConstants.apiUrl}/customer/sso/spesa'),
            headers: {'X-API-Token': token},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final data =
          (json.decode(response.body) as Map<String, dynamic>)['data']
              as Map<String, dynamic>?;
      final email = data?['email'] as String?;
      final hash = data?['magic_hash'] as String?;
      if (email == null || hash == null) return null;

      return {'email': email, 'magicHash': hash};
    } catch (_) {
      return null;
    }
  }

  /// Costruisce l'URL finale, aggiungendo i parametri SSO se richiesto.
  Future<String> _buildFinalUrl() async {
    String finalUrl = widget.url;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    if (!widget.useLennySso) return finalUrl;

    final sso = await _fetchSsoParams();
    if (sso == null) return finalUrl;

    final email = sso['email']!;
    final magicHash = sso['magicHash']!;

    final uri = Uri.parse(finalUrl);
    final updatedUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'email': email,
        'magicHash': magicHash,
      },
    );
    return updatedUri.toString();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    // Carica l'URL (eventualmente arricchito con SSO) in modo asincrono
    _buildFinalUrl().then((url) {
      _controller.loadRequest(Uri.parse(url));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
