import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';

/// Splash Screen - Animazione manuale con setState
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _logoScale = 0.3;
  double _logoOpacity = 0.0;
  double _taglineOpacity = 0.0;
  double _screenOpacity = 1.0;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    print('🚀 SPLASH SCREEN - initState');

    // Avvia animazione manuale (che gestirà anche la navigazione)
    _startAnimation();
  }

  void _startAnimation() async {
    // Fade in logo (500ms)
    for (int i = 0; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      if (mounted) {
        setState(() => _logoOpacity = i / 20.0);
      }
    }

    // Scale up (da 0.3 a 1.45 in 1500ms)
    for (int i = 0; i <= 60; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      if (mounted) {
        setState(() => _logoScale = 0.3 + (i / 60.0) * 1.15);
      }
    }

    // Pausa al massimo zoom (300ms)
    await Future.delayed(const Duration(milliseconds: 300));

    // Bounce back (da 1.45 a 1.0 in 1200ms - più lento)
    for (int i = 0; i <= 48; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      if (mounted) {
        setState(() => _logoScale = 1.45 - (i / 48.0) * 0.45);
      }
    }

    // Fade in tagline (500ms)
    for (int i = 0; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      if (mounted) setState(() => _taglineOpacity = i / 20.0);
    }

    // Pausa prima della transizione (600ms)
    await Future.delayed(const Duration(milliseconds: 600));

    // TRANSIZIONE ELEGANTE: Zoom-out + Fade-out (800ms)
    for (int i = 0; i <= 32; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      if (mounted) {
        setState(() {
          _logoScale = 1.0 + (i / 32.0) * 0.5; // Da 1.0 a 1.5 (zoom-out)
          _logoOpacity = 1.0 - (i / 32.0); // Da 1.0 a 0.0
          _taglineOpacity = 1.0 - (i / 32.0); // Fade-out tagline
          _screenOpacity = 1.0 - (i / 32.0) * 0.6; // Schermo da 1.0 a 0.4
        });
      }
    }

    // Naviga SOLO DOPO che la transizione è completata
    if (mounted) {
      _navigateNext();
    }
  }

  void _navigateNext() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!mounted) return;

    if (isLoggedIn) {
      context.go('/categories');
      return;
    }

    // Guest-first: chi non e' loggato entra comunque come ospite e naviga
    // liberamente (ristoranti e menu sono pubblici). L'account viene richiesto
    // solo al momento di completare l'ordine. L'onboarding si mostra solo alla
    // primissima apertura dell'app.
    final primaApertura = await _authService.isFirstLaunch();
    if (!mounted) return;
    context.go(primaApertura ? '/onboarding' : '/categories');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Opacity(
        opacity: _screenOpacity,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                Color(0xFFFFAA55), // Arancio centrale
                Color(0xFFFFBB33), // Arancio-giallo
                AppColors.splashGradientEnd, // Giallo oro #FFD000
                AppColors.splashGradientStart, // Giallo vivace #F6E644
                Color(0xFFFFF3AA), // Giallo chiaro
              ],
              stops: [0.0, 0.3, 0.5, 0.7, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animato
                Opacity(
                  opacity: _logoOpacity,
                  child: Transform.scale(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/images/logo_lenny.png',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Tagline
                Opacity(
                  opacity: _taglineOpacity,
                  child: Text(
                    AppConstants.appTagline,
                    style: GoogleFonts.poppins(
                      color: AppColors.splashDark,
                      fontWeight: FontWeight.w500,
                      fontSize: 20,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
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
