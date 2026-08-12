import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'registration_screen.dart';
import '../widgets/app_icon.dart';

/// Login Screen basato sul prototipo 1-loginpage.html
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    print('\n🚀 [UI] Inizio procedura login...');

    if (!_formKey.currentState!.validate()) {
      print('❌ [UI] Validazione form fallita');
      return;
    }

    print('✅ [UI] Form validato, chiamata API...');
    setState(() => _isLoading = true);

    try {
      print('📧 [UI] Email: ${_emailController.text.trim()}');
      print('🔑 [UI] Password length: ${_passwordController.text.length}');

      final response = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('📬 [UI] Risposta ricevuta: success=${response.success}');
      print('📬 [UI] Message: ${response.message}');

      if (!mounted) return;

      if (response.success) {
        print('✅ [UI] Login SUCCESS - navigazione categories');
        _showToast('Login effettuato con successo!', isError: false);
        // Registra token FCM ora che l'utente è autenticato
        FcmService().onUserLoggedIn();
        // Chiudi la tastiera prima di navigare
        FocusScope.of(context).unfocus();
        // Piccolo delay per permettere alla tastiera di chiudersi
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        // Naviga alla schermata di selezione categorie
        context.go('/categories');
      } else {
        print('❌ [UI] Login FAILED: ${response.message}');
        _showToast(response.message, isError: true);
      }
    } catch (e) {
      print('💥 [UI] ERRORE CATCH: $e');
      if (mounted) {
        _showToast('Errore durante il login: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          FocusScope.of(context).unfocus(), // Chiudi tastiera toccando fuori
      child: Scaffold(
        backgroundColor: AppColors.cream,
        // Barra col solo tasto indietro, e solo quando c'e' davvero dove
        // tornare: l'ospite che arriva qui per curiosita' deve poter
        // riprendere a navigare. Dopo un logout invece il login e' la radice,
        // canPop e' falso e la barra non compare.
        appBar: context.canPop()
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                foregroundColor: AppColors.dark,
              )
            : null,
        body: SafeArea(
          bottom: false, // La card bianca estende fino al bordo inferiore
          child: Column(
            children: [
              // Header con immagine chef
              _buildHeader(),

              // Card con form login (esteso fino in fondo)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        28,
                        20,
                        28,
                        // Padding bottom = 40 fissi + home indicator iOS (0 su Android)
                        40 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titolo Login
                          const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Form
                          _buildLoginForm(),

                          const SizedBox(height: 16),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.dark,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Switch to register
                          _buildAuthSwitch(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          // Testo Hello!
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 0, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ciao!',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          // Immagine chef posizionata in basso a destra (appoggiata al box)
          Positioned(
            right: -125,
            bottom: -140,
            child: Image.asset(
              'assets/images/CHEF_LOGIN.png',
              width: 380,
              height: 380,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label Email
          const Text(
            'Email',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Inserisci la tua email',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: AppIcon(
                  'assets/icons/icons8-email-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.gray,
                ),
              ),
              filled: true,
              fillColor: AppColors.lightGray.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Inserisci la tua email';
              }
              if (!value.contains('@')) {
                return 'Inserisci un\'email valida';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Label Password
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: AppIcon(
                  'assets/icons/icons8-password-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.gray,
                ),
              ),
              suffixIcon: IconButton(
                icon: AppIcon(
                  'assets/icons/icons8-hide-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.gray,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: AppColors.lightGray.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Inserisci la password';
              }
              if (value.length < AppConstants.minPasswordLength) {
                return 'La password deve essere di almeno ${AppConstants.minPasswordLength} caratteri';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/forgot-password'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 30),
              ),
              child: const Text(
                'Password dimenticata?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthSwitch() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Non hai un account?',
            style: TextStyle(
              color: AppColors.gray,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextButton(
            onPressed: () {
              // Apri modale registrazione
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (context, _, _) => const RegistrationScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 30),
            ),
            child: const Text(
              'Registrati',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
