import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

/// Splash dell'app Lenny Partner: breve e sobrio, questo e' uno strumento
/// di lavoro sul banco del ristorante. Logo, nome, e dentro.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _avvia();
  }

  Future<void> _avvia() async {
    await Future.delayed(const Duration(seconds: AppConstants.splashDuration));
    if (!mounted) return;

    final isLoggedIn = await _authService.isLoggedIn();
    if (!mounted) return;

    if (isLoggedIn) {
      FcmService().onUserLoggedIn();
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/splash_partners.png',
                  width: 260,
                  height: 260,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  'Lenny Partner',
                  style: GoogleFonts.poppins(
                    color: AppColors.splashDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
