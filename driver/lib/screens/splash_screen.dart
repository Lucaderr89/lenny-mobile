import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

/// Splash Screen per l'app Lenny Driver
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _explosionController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final AuthService _authService = AuthService();
  bool _showExplosion = false;

  // Emoji per driver (veicoli e consegne)
  final List<String> _deliveryEmojis = [
    '🚗', // Auto
    '🏍️', // Moto
    '🚴', // Bici
    '📦', // Pacco
    '🍕', // Pizza
    '🍔', // Burger
    '🍜', // Noodles
    '🥤', // Drink
    '🛵', // Scooter
    '📍', // Pin
    '🗺️', // Mappa
    '⏱️', // Timer
    '✅', // Check
    '🎯', // Target
    '🔔', // Notifica
    '⚡', // Veloce
  ];

  @override
  void initState() {
    super.initState();

    // Animazione ingresso slide dal basso con bounce
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    // Animazione pulsante continua
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animazione esplosione
    _explosionController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Listener per attivare esplosione
    _slideController.addListener(() {
      if (_slideController.value > 0.7 && !_showExplosion) {
        setState(() => _showExplosion = true);
        _explosionController.forward();
      }
    });

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _slideController.forward();

    // Controlla dove navigare dopo 4 secondi
    await Future.delayed(const Duration(seconds: 4));
    _navigateNext();
  }

  void _navigateNext() async {
    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      // Driver già loggato → registra token FCM e vai alla home
      FcmService().onUserLoggedIn();
      context.go('/home');
    } else {
      // Nessuna sessione → mostra login
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _explosionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final logoCenterY = screenHeight / 2 - 30;
    final logoCenterX = screenWidth / 2;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: Stack(
          children: [
            // Esplosione di emoji centrata sul logo
            if (_showExplosion)
              ..._buildDeliveryExplosion(logoCenterX, logoCenterY),

            // Logo e tagline centrati
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo con animazione pulsante
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Image.asset(
                        'assets/images/splash_driver.png',
                        width: 220,
                        height: 198, // Mantiene proporzioni 632x568
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Tagline
                  Text(
                    'Lenny Drivers',
                    style: GoogleFonts.poppins(
                      color: AppColors.splashDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDeliveryExplosion(double centerX, double centerY) {
    final random = math.Random(42);
    return List.generate(_deliveryEmojis.length, (index) {
      final angle =
          (index * (360.0 / _deliveryEmojis.length)) * (math.pi / 180);
      final distance = 130.0 + random.nextDouble() * 60;

      return AnimatedBuilder(
        animation: _explosionController,
        builder: (context, child) {
          final progress = Curves.easeOutCubic.transform(
            _explosionController.value,
          );

          final opacity = progress < 0.6
              ? 1.0
              : (1.0 - ((progress - 0.6) / 0.4)).clamp(0.0, 1.0);

          final xOffset = math.cos(angle) * distance * progress;
          final yOffset = math.sin(angle) * distance * progress;

          return Positioned(
            left: centerX + xOffset - 18,
            top: centerY + yOffset - 18,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.9),
                child: Transform.rotate(
                  angle: progress * math.pi * 3,
                  child: Text(
                    _deliveryEmojis[index],
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
