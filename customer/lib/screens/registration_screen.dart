import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';

/// Registration Screen - Modale all'80%
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _smacController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _smacController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      _showToast('Devi accettare i Termini e Condizioni', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        address: _addressController.text.trim(),
        smacNumber: _smacController.text.trim(),
      );

      if (!mounted) return;

      if (response.success) {
        // Auto-login con le credenziali appena inserite: obbligare l'utente
        // a ridigitarle subito dopo la registrazione era un passaggio a vuoto
        // nel momento di massima motivazione.
        final loginResponse = await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;

        if (loginResponse.success) {
          _showToast('Benvenuto su Lenny!', isError: false);
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            context.go('/categories');
          }
        } else {
          // Registrato ma login fallito (caso raro): si ripiega sul login
          // manuale, senza far ripetere la registrazione.
          _showToast(
            'Registrazione completata! Effettua il login',
            isError: false,
          );
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.pop(context);
            context.go('/login');
          }
        }
      } else {
        _showToast(response.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showToast('Errore durante la registrazione', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Apre un'informativa legale nel browser. Se non si riesce, l'utente deve
  /// saperlo: un tap che non fa nulla e' peggio di un errore.
  Future<void> _apriLink(String url) async {
    final uri = Uri.parse(url);
    final aperto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!aperto && mounted) {
      _showToast('Impossibile aprire $url', isError: true);
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
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      body: SafeArea(
        child: Stack(
          children: [
            // Sfondo trasparente cliccabile per chiudere
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(color: Colors.transparent),
            ),

            // Modale all'80% in basso
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header con titolo e bottone chiudi
                    _buildHeader(context),

                    // Form scrollabile
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                        child: _buildRegistrationForm(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 20, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.lightGray, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Registrati',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.dark,
            ),
          ),
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close, color: AppColors.dark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome
          const Text(
            'Nome',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _firstNameController,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Mario',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/icons/icons8-user-male-32.png',
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
                return 'Inserisci il tuo nome';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Cognome
          const Text(
            'Cognome',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _lastNameController,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Rossi',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/icons/icons8-user-male-32.png',
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
                return 'Inserisci il tuo cognome';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Email
          const Text(
            'Email',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'mario.rossi@email.com',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
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

          // Phone Number
          const Text(
            'Numero di telefono',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: '(+39) 555-0101',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/icons/icons8-telephone-32.png',
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
                return 'Inserisci il tuo numero di telefono';
              }
              if (value.length < AppConstants.phoneMinLength) {
                return 'Numero di telefono non valido';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Password
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/icons/icons8-password-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.gray,
                ),
              ),
              suffixIcon: IconButton(
                icon: Image.asset(
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

          // Indirizzo (opzionale)
          const Text(
            'Indirizzo di consegna',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _addressController,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Via Roma 123 (opzionale)',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/icons/icons8-location-32.png',
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
          ),

          const SizedBox(height: 12),

          // SMAC (opzionale)
          const Text(
            'Numero SMAC',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _smacController,
            keyboardType: TextInputType.number,
            maxLength: AppConstants.smacLength,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'SMAC (opzionale)',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.6),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/icons/icons8-card-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.gray,
                ),
              ),
              counterText: '',
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
              if (value != null && value.isNotEmpty) {
                if (value.length != AppConstants.smacLength) {
                  return 'Il numero Smac deve essere di ${AppConstants.smacLength} cifre';
                }
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Remember me checkbox
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: _agreedToTerms,
                  onChanged: (value) {
                    setState(() => _agreedToTerms = value ?? false);
                  },
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                // Il testo dei termini deve essere raggiungibile: e' un requisito
                // del Play Store e, prima, un obbligo verso l'utente che li accetta.
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: AppColors.dark,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      const TextSpan(text: 'Accetto i '),
                      TextSpan(
                        text: 'Termini e Condizioni',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _apriLink(AppConstants.termsUrl),
                      ),
                      const TextSpan(text: ' e la '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _apriLink(AppConstants.privacyPolicyUrl),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.dark,
                        ),
                      ),
                    )
                  : const Text(
                      'Registrati',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Already have account
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hai già un account?',
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  child: const Text(
                    'Accedi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
