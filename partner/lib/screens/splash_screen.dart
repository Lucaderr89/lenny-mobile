import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';

/// Splash dell'app Ristoranti: stesso schema dell'app driver, schermo blu
/// con l'icona dell'app. Corto: copre solo il check della sessione.
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

  /// Stesso blu notte dello splash driver.
  static const LinearGradient _gradienteBlu = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1626), Color(0xFF0B3A6B)],
  );

  @override
  void initState() {
    super.initState();

    // Il fascio di luce attraversa lo schermo una volta sola
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
        decoration: const BoxDecoration(gradient: _gradienteBlu),
        child: Stack(
          children: [
            // Fascio di luce diagonale, una passata da sinistra a destra
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

            // Icona dell'app e nome: la stessa immagine che si tocca sul
            // launcher, per coerenza tra icona e apertura.
            Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 132,
                        height: 132,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Lenny Partner',
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
