import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
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

  /// Calcola il magicHash SSO identico al vecchio sistema Lenny:
  ///   substr( md5( email + "LennY2022" ), 8, 6 )
  static String _computeMagicHash(String email) {
    const secret = 'LennY2022';
    final bytes = utf8.encode(email + secret);
    final digest = md5.convert(bytes);
    return digest.toString().substring(8, 14);
  }

  /// Costruisce l'URL finale, aggiungendo i parametri SSO se richiesto.
  Future<String> _buildFinalUrl() async {
    String finalUrl = widget.url;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    if (!widget.useLennySso) return finalUrl;

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(AppConstants.keyUserEmail);
    if (email == null || email.isEmpty) return finalUrl;

    // Usa il magicHash salvato oppure lo ricalcola al volo (es. utenti già loggati)
    String? magicHash = prefs.getString(AppConstants.keySpesaMagicHash);
    if (magicHash == null || magicHash.isEmpty) {
      magicHash = _computeMagicHash(email);
      // Salva per le prossime aperture
      await prefs.setString(AppConstants.keySpesaMagicHash, magicHash);
    }

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
