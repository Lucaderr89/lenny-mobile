import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../services/auth_service.dart';

/// Onboarding v5: Clean Modern Style
/// Ispirato al design con illustrazioni grandi, sfondo bianco e sezione colorata
class OnboardingScreenV5 extends StatefulWidget {
  const OnboardingScreenV5({super.key});

  @override
  State<OnboardingScreenV5> createState() => _OnboardingScreenV5State();
}

class _OnboardingScreenV5State extends State<OnboardingScreenV5>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  int _currentPage = 0;

  late AnimationController _bounceController;

  final List<OnboardingPageV5> _pages = [
    OnboardingPageV5(
      title: "Scopri il Gusto",
      description:
          "Dalla pizza alla stella Michelin, tutti i locali che ami (e quelli che amerai) sono qui",
      imagePath: "assets/images/ESPLORA.png",
      backgroundColor: Colors.white,
      bottomColor: const Color(0xFFCDDC39), // Lime vibrante
      accentColor: const Color(0xFF8BC34A), // Verde lime accent
    ),
    OnboardingPageV5(
      title: "Ordina in un Click",
      description:
          "Personalizza ogni dettaglio del tuo piatto preferito e ordina in 30 secondi netti",
      imagePath: "assets/images/ORDINA.png",
      backgroundColor: Colors.white,
      bottomColor: const Color(0xFFFFD042), // Giallo accent brillante
      accentColor: AppColors.accent, // Giallo accent
    ),
    OnboardingPageV5(
      title: "Ricevi a Casa Tua",
      description:
          "Tracciamento live del tuo ordine. Preparati ad aprire la porta (e l'appetito)",
      imagePath: "assets/images/RICEVI.png",
      backgroundColor: Colors.white,
      bottomColor: const Color(0xFFFF8F6B), // sfondo illustrazione (asset)
      accentColor: AppColors.primary, // blu del logo
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  /// Fine onboarding: si entra come ospite. Ristoranti e menu sono navigabili
  /// senza account; la registrazione viene proposta al momento di ordinare.
  Future<void> _entraComeOspite() async {
    await _authService.setFirstLaunchComplete();
    if (mounted) context.go('/categories');
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _entraComeOspite();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    // Determina quale immagine usare in base al colore
    String backgroundImage = 'assets/images/LIME.png';
    if (page.bottomColor.value == 0xFFFFD042) {
      backgroundImage = 'assets/images/GIALLO.png';
    } else if (page.bottomColor.value == 0xFFFF8F6B) {
      backgroundImage = 'assets/images/ARANCIONE.png';
    }

    return Scaffold(
      backgroundColor: page.backgroundColor,
      body: Stack(
        children: [
          // Immagine a tutto schermo - transizione fluida senza flash
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Image.asset(
                backgroundImage,
                key: ValueKey<String>(backgroundImage),
                fit: BoxFit.cover,
                alignment: const Alignment(-0.9, 0),
              ),
            ),
          ),

          // Contenuto sopra l'immagine
          SafeArea(
            bottom: false, // La sezione colorata in basso copre l'home indicator
            child: Column(
              children: [
                // Top content area
                Expanded(
                  flex: 7,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double value = 1.0;
                          if (_pageController.position.haveDimensions) {
                            value = _pageController.page! - index;
                            value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
                          }
                          return Transform.scale(
                            scale: value,
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: _buildPageContent(_pages[index]),
                      );
                    },
                  ),
                ),

                // Bottom colored section
                Expanded(flex: 3, child: _buildBottomSection(page)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(OnboardingPageV5 page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Large illustration with bounce
          AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              final bounce = math.sin(_bounceController.value * math.pi) * 10;
              return Transform.translate(
                offset: Offset(0, -bounce),
                child: Transform.scale(
                  scale:
                      1.0 +
                      (math.sin(_bounceController.value * math.pi) * 0.05),
                  child: Image.asset(
                    page.imagePath,
                    width: 288,
                    height: 288,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBottomSection(OnboardingPageV5 page) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: page.bottomColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          const Spacer(),

          // Page indicator
          SmoothPageIndicator(
            controller: _pageController,
            count: _pages.length,
            effect: ExpandingDotsEffect(
              activeDotColor: Colors.black87,
              dotColor: Colors.black.withValues(alpha: 0.2),
              dotHeight: 8,
              dotWidth: 8,
              expansionFactor: 4,
              spacing: 8,
            ),
          ),

          const Spacer(),

          // Navigation buttons
          Padding(
            padding: EdgeInsets.only(
              left: 32.0,
              right: 32.0,
              top: 24.0,
              // Aggiunge home indicator iOS (0 su Android)
              bottom: 24.0 + MediaQuery.of(context).padding.bottom,
            ),
            child: _currentPage < _pages.length - 1
                ? Stack(
                    children: [
                      // Back button (left)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _currentPage > 0
                            ? TextButton(
                                onPressed: _previousPage,
                                child: const Text(
                                  "Indietro",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Next button (always centered)
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black87,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _nextPage,
                              borderRadius: BorderRadius.circular(32),
                              child: Center(
                                child: Image.asset(
                                  'assets/icons/icons8-arrow-WHITE-32.png',
                                  width: 24,
                                  height: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Skip button (right)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _entraComeOspite,
                          child: const Text(
                            "Salta",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _entraComeOspite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          "Inizia Subito",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageV5 {
  final String title;
  final String description;
  final String imagePath;
  final Color backgroundColor;
  final Color bottomColor;
  final Color accentColor;

  OnboardingPageV5({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.backgroundColor,
    required this.bottomColor,
    required this.accentColor,
  });
}
