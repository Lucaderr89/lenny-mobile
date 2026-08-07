import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

/// Splash dell'app Driver: CORTO e dedicato al mondo "strada".
///
/// Niente precaricamenti da app cliente: qui copre solo il check della
/// sessione (~1,4s minimi per non far lampeggiare). Fondo blu notte con
/// un fascio di luce che attraversa lo schermo come un faro: identita'
/// sorella del cliente, non gemella.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _faroController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;

  final AuthService _authService = AuthService();

  // Durata minima a schermo: sotto questa soglia lo splash "sfarfalla"
  static const Duration _permanenzaMinima = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();

    // Il faro attraversa lo schermo una volta sola
    _faroController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..forward();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _avvia();
  }

  Future<void> _avvia() async {
    // Check sessione e permanenza minima IN PARALLELO: si naviga quando
    // entrambe sono concluse (di norma comanda la permanenza minima).
    final risultati = await Future.wait<dynamic>([
      _authService.isLoggedIn(),
      Future<void>.delayed(_permanenzaMinima),
    ]);

    if (!mounted) return;

    final loggato = risultati[0] == true;
    if (loggato) {
      FcmService().onUserLoggedIn();
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _faroController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final larghezza = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.splashNotteGradient,
        ),
        child: Stack(
          children: [
            // Fascio di luce: banda diagonale chiara che attraversa lo
            // schermo una volta, da sinistra a destra
            AnimatedBuilder(
              animation: _faroController,
              builder: (context, _) {
                final progresso = Curves.easeInOut.transform(
                  _faroController.value,
                );
                return Positioned(
                  top: 0,
                  bottom: 0,
                  left: -larghezza * 0.6 + progresso * larghezza * 1.8,
                  child: Transform.rotate(
                    angle: -math.pi / 10,
                    child: Container(
                      width: larghezza * 0.35,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Logo e nome
            Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/splash_driver.png',
                      width: 190,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Lenny Driver',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                        letterSpacing: 0.5,
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
}
