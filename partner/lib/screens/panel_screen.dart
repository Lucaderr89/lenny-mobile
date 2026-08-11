import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/credenziali_sicure.dart';

/// Pannello platform in WebView con autologin.
/// Stesso meccanismo dell'app driver: le credenziali dell'app sono le stesse
/// di platform, quindi si compila il form di login via JavaScript e si invia.
class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key});

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _email;
  String? _password;

  static const String _panelUrl = 'https://platform.lenny-staging.com';

  @override
  void initState() {
    super.initState();
    _initWebView(); // sincrono: _controller pronto prima di build()
    _loadCredentials(); // asincrono: pronte prima che la pagina finisca
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _email = prefs.getString(AppConstants.keyPartnerEmail);
    _password = await CredenzialiSicure.leggiPassword();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _tryAutoLogin(url);
          },
        ),
      )
      ..loadRequest(Uri.parse(_panelUrl));
  }

  Future<void> _tryAutoLogin(String url) async {
    if (_email == null || _password == null) return;
    // Prova auto-login solo se la pagina contiene un form di login
    final escapedEmail = _email!.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final escapedPassword = _password!
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"');

    await Future.delayed(const Duration(milliseconds: 600));
    await _controller.runJavaScript('''
      (function() {
        var emailField = document.querySelector(
          'input[name="username"], input[id="username"], input[name="email"], input[id="email"], input[type="email"]'
        );
        var passField = document.querySelector(
          'input[type="password"], input[name="password"], input[id="password"]'
        );
        if (!emailField || !passField) return;
        var nativeInputSetter = Object.getOwnPropertyDescriptor(
          window.HTMLInputElement.prototype, 'value'
        ).set;
        nativeInputSetter.call(emailField, '$escapedEmail');
        emailField.dispatchEvent(new Event('input', { bubbles: true }));
        nativeInputSetter.call(passField, '$escapedPassword');
        passField.dispatchEvent(new Event('input', { bubbles: true }));
        var form = emailField.closest('form');
        if (form) {
          var submitBtn = form.querySelector(
            'button[type="submit"], input[type="submit"]'
          );
          if (submitBtn) { submitBtn.click(); }
          else { form.submit(); }
        }
      })();
    ''');
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
        title: const Text(
          'Pannello Ristorante',
          style: TextStyle(
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
