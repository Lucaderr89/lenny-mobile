import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'external_webview_screen.dart';
import '../providers/location_provider.dart';
import '../widgets/address_selector_bottom_sheet.dart';
import '../widgets/first_launch_location_dialog.dart';
import '../models/app_category.dart';
import '../services/app_category_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_icon.dart';

/// Schermata di selezione categorie in stile Glovo
/// Mostra le varie sezioni dell'app: Cibo, Spesa, Negozi, etc.
class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;

  // Posizioni originali delle categorie (fisse)
  final Map<String, Offset> _originalPositions = {};
  final Map<String, Offset> _categoryPositions = {};

  // Categorie dall'API
  final AppCategoryService _categoryService = AppCategoryService();
  List<AppCategory> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Ospite o loggato: decide se l'header mostra "Esci" o "Accedi".
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _loadCategories();

    AuthService().isLoggedIn().then((value) {
      if (mounted) setState(() => _isLoggedIn = value);
    });

    _fadeController.forward();
    _scaleController.forward();

    // 🎯 Mostra SOLO dialog GPS (DOPO il primo frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFirstLaunchLocationDialogIfNeeded(context);
    });
  }

  /// Carica le categorie dall'API
  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getActiveCategories();

      // CATEGORIA "CIBO" SEMPRE PRESENTE E FISSA (non dal server)
      final ciboCategory = AppCategory(
        id: 0, // ID fittizio
        key: 'cibo',
        label: 'Cibo',
        iconPath: 'assets/icons/cibo.png',
        actionType: 'internal',
        actionValue: '/home', // Va alla home dell'app
        isActive: true,
        isComingSoon: false,
        displayOrder: 0,
      );

      if (mounted) {
        setState(() {
          // Cibo sempre prima, poi le altre categorie dal server
          _categories = [ciboCategory, ...categories];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Errore caricamento categorie: $e');
      if (mounted) {
        setState(() {
          // Anche in caso di errore, mostra almeno "Cibo"
          _categories = [
            AppCategory(
              id: 0,
              key: 'cibo',
              label: 'Cibo',
              iconPath: 'assets/icons/cibo.png',
              actionType: 'internal',
              actionValue: '/home',
              isActive: true,
              isComingSoon: false,
              displayOrder: 0,
            ),
          ];
          _errorMessage = 'Errore nel caricamento delle categorie aggiuntive';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _showAddressSelector() {
    showAddressSelectorBottomSheet(context);
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
'assets/icons/icons8-uscita-32.png',
                  width: 48,
                  height: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Logout',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sei sicuro di voler uscire?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Annulla',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Esci',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && context.mounted) {
      // Esegui logout
      final authService = AuthService();
      await authService.logout();

      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/sfondo_categorie.jpeg'),
            fit: BoxFit.fill,
          ),
        ),
        child: SafeArea(
          bottom: false, // Il pannello "Ti trovi qui" si estende fino al bordo
          child: Column(
            children: [
              _buildHeader(locationProvider),

              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? Center(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(color: Colors.red),
                          ),
                        )
                      : _buildCategoriesGrid(),
                ),
              ),

              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LocationProvider locationProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Barra di ricerca con logout
          Row(
            children: [
              Expanded(
                // Non e' decorativa: porta alla home cibo con la ricerca.
                child: InkWell(
                  onTap: () => context.go('/home'),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'Cosa ti va oggi?',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // Ospite: "Accedi" (il logout di un ospite non ha senso).
                // Loggato: "Esci" con conferma, come prima.
                child: _isLoggedIn
                    ? IconButton(
                        onPressed: () => _handleLogout(context),
                        icon: AppIcon(
'assets/icons/icons8-uscita-32.png',
                          width: 24,
                          height: 24,
                          color: AppColors.primary,
                        ),
                        padding: EdgeInsets.zero,
                      )
                    : IconButton(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(
                          Icons.person_outline,
                          size: 26,
                          color: AppColors.primary,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Accedi',
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    if (_categories.isEmpty) {
      return Center(
        child: Text(
          'Nessuna categoria disponibile',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final centerY = constraints.maxHeight * 0.5;
        final centerX = constraints.maxWidth * 0.5;

        // Calcola posizioni dinamiche in base al numero di categorie
        _calculateCategoryPositions(centerX, centerY);

        return Stack(
          children: _categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;

            // Categoria "Cibo" (key = 'cibo') è sempre più grande e centrale
            final isCibo = category.key.toLowerCase() == 'cibo';
            final size = isCibo ? 130.0 : 100.0; // Uniforme per tutte le altre

            return _buildDraggableCategoryCircle(
              key: category.key,
              label: category.label,
              iconPath: _getIconPath(category),
              size: size,
              delay: index * 100,
              position: _categoryPositions[category.key]!,
              onTap: () => _handleCategoryTap(category),
              isComingSoon: category.isComingSoon,
              actionType: category.actionType,
            );
          }).toList(),
        );
      },
    );
  }

  /// Calcola le posizioni delle categorie in modo dinamico
  /// Dispone elegantemente le categorie attorno a "Cibo" centrale
  void _calculateCategoryPositions(double centerX, double centerY) {
    if (_categories.isEmpty) return;

    for (int i = 0; i < _categories.length; i++) {
      final category = _categories[i];
      final isCibo = category.key.toLowerCase() == 'cibo';

      Offset position;

      if (isCibo) {
        // "Cibo" sempre al centro
        position = Offset(centerX - 65, centerY - 65);
      } else {
        // Altre categorie disposte in cerchio attorno a Cibo
        // Indice effettivo (escluso Cibo che è i=0)
        final satelliteIndex = i - 1;
        final totalSatellites = _categories.length - 1;

        // Disponi in cerchio, partendo da alto-destra (come Glovo)
        // Angolo iniziale: -60° (ore 2 del quadrante)
        final startAngle = -math.pi / 3; // -60 gradi
        final angleStep = (2 * math.pi) / math.max(totalSatellites, 5);
        final angle = startAngle + (satelliteIndex * angleStep);

        // Raggio variabile in base al numero di categorie
        double radius;
        if (totalSatellites <= 4) {
          radius = 140.0; // Più lontano se poche categorie
        } else if (totalSatellites <= 6) {
          radius = 130.0; // Standard
        } else {
          radius = 120.0; // Più vicino se molte categorie
        }

        // Calcola posizione in cerchio
        final x = centerX + radius * math.cos(angle) - 50;
        final y = centerY + radius * math.sin(angle) - 50;

        position = Offset(x, y);
      }

      _originalPositions.putIfAbsent(category.key, () => position);
      _categoryPositions.putIfAbsent(category.key, () => position);
    }
  }

  /// Ottieni il path corretto dell'icona
  String _getIconPath(AppCategory category) {
    // Se l'icona viene dal DB, usa il percorso completo dal server
    // Altrimenti usa assets locali (per "Cibo" hardcoded)
    if (category.id > 0 && category.iconPath.startsWith('assets/images/')) {
      // Icona dal DB - usa URL completo del server
      return 'https://lenny-staging.com/${category.iconPath}';
    }
    // Icona locale (Cibo hardcoded)
    return category.iconPath;
  }

  /// Gestisci il tap su una categoria
  void _handleCategoryTap(AppCategory category) {
    print('🔍 Tap su categoria: ${category.label} (${category.actionType})');

    // Se è coming soon, mostra dialog
    if (category.isComingSoon) {
      _showComingSoon(category.label);
      return;
    }

    // Altrimenti gestisci in base al tipo di azione
    if (category.actionType == 'internal') {
      // Naviga a schermata interna (es: /home per Cibo)
      if (category.key.toLowerCase() == 'cibo') {
        context.go('/home');
      } else {
        // Per altre schermate interne non implementate
        _showComingSoon(category.label);
      }
    } else if (category.actionType == 'external') {
      // Apri link esterno nella webview in-app
      if (category.actionValue != null && category.actionValue!.isNotEmpty) {
        // La categoria 'spesa' usa il SSO Lenny (magicHash)
        final useSso = category.key.toLowerCase() == 'spesa';
        _openInAppWebView(
          category.label,
          category.actionValue!,
          useLennySso: useSso,
        );
      } else {
        _showComingSoon(category.label);
      }
    }
  }

  /// Apri un link esterno nella webview in-app con autologin
  void _openInAppWebView(String title, String url, {bool useLennySso = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExternalWebViewScreen(
          url: url,
          title: title,
          useLennySso: useLennySso,
        ),
      ),
    );
  }

  Widget _buildDraggableCategoryCircle({
    required String key,
    required String label,
    required String iconPath,
    required double size,
    required int delay,
    required Offset position,
    required VoidCallback onTap,
    required bool isComingSoon,
    required String actionType,
  }) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      top: position.dy,
      left: position.dx,
      child: Draggable(
        feedback: Opacity(
          opacity: 0.8,
          child: _buildCategoryContent(
            label: label,
            iconPath: iconPath,
            size: size,
            delay: delay,
            isComingSoon: isComingSoon,
            actionType: actionType,
            isDragging: true,
          ),
        ),
        childWhenDragging:
            const SizedBox.shrink(), // Nasconde completamente durante il drag
        onDragEnd: (details) {
          // Aggiorna temporaneamente la posizione
          setState(() {
            _categoryPositions[key] = details.offset;
          });

          // Dopo 100ms, riporta alla posizione originale con animazione
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _categoryPositions[key] = _originalPositions[key]!;
              });
            }
          });
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 800 + delay),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: GestureDetector(
            onTap: onTap,
            child: _buildCategoryContent(
              label: label,
              iconPath: iconPath,
              size: size,
              delay: delay,
              isComingSoon: isComingSoon,
              actionType: actionType,
              isDragging: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryContent({
    required String label,
    required String iconPath,
    required double size,
    required int delay,
    required bool isComingSoon,
    required String actionType,
    required bool isDragging,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _OrganicShapePainter(delay: delay),
          child: SizedBox(
            width: size,
            height: size,
            child: Padding(
              padding: EdgeInsets.all(size * 0.06),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: size * 0.02,
                    child: iconPath.startsWith('http')
                        ? Image.network(
                            iconPath,
                            width: size * 0.65,
                            height: size * 0.65,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported,
                                size: size * 0.65,
                                color: Colors.grey,
                              );
                            },
                          )
                        : Image.asset(
                            iconPath,
                            width: size * 0.65,
                            height: size * 0.65,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                  ),
                  Positioned(
                    left: size * 0.05,
                    right: size * 0.05,
                    bottom: size * 0.18,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: label == 'News & Eventi' ? 10.0 : size * 0.10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Badge "In Arrivo" SOLO per categorie internal non implementate
        // Se è external, il link funziona già quindi niente badge
        if (isComingSoon && !isDragging && actionType == 'internal')
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'In Arrivo',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, _) {
        final address = locationProvider.displayAddress;

        return ClipPath(
          clipper: _WavyTopClipper(),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), AppColors.light],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 70,
                  bottom: 16,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "Ti trovi qui" separato e più grande
                    Text(
                      'Ti trovi qui',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Indirizzo cliccabile
                    InkWell(
                      onTap: _showAddressSelector,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            AppIcon(
'assets/icons/icons8-location-32.png',
                              width: 20,
                              height: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.dark,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon(String category) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icona animata
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD042), Color(0xFFFFA726)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rocket_launch,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'In Arrivo!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La sezione $category sarà presto disponibile.\nRimani sintonizzato!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF757575),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD042),
                  foregroundColor: AppColors.dark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Ho capito!',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Painter per forme organiche irregolari stile Glovo
class _OrganicShapePainter extends CustomPainter {
  final int delay;

  _OrganicShapePainter({this.delay = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Ombra principale per profondità
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    // Ombra leggera esterna tipo "taped" per effetto elegante
    final outerShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);

    // Bordo grigio per definire i contorni (come Glovo)
    final strokePaint = Paint()
      ..color = const Color(0xFFCC8800)
          .withValues(alpha: 0.40) // Tonalità scura del giallo/arancione di sfondo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    final path = _createOrganicPath(size, delay);

    // Ombra esterna molto leggera (effetto taped)
    canvas.drawPath(path.shift(const Offset(0, 12)), outerShadowPaint);
    // Ombra principale
    canvas.drawPath(path.shift(const Offset(0, 8)), shadowPaint);

    // Disegna forma bianca
    canvas.drawPath(path, paint);

    // Disegna bordo sottile per definire i contorni
    canvas.drawPath(path, strokePaint);
  }

  Path _createOrganicPath(Size size, int seed) {
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final baseRadius = size.width / 2.15;

    // Genera molti punti per una forma super fluida
    final numPoints = 24; // Molti punti = zero spigoli
    final points = <Offset>[];

    // Crea forme diverse in base al seed (ogni categoria ha una forma diversa)
    // Seed = delay, quindi ogni categoria avrà una forma unica
    final shapeType = seed % 6; // 6 diverse forme organiche

    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;
      double radiusVariation = 1.0;

      switch (shapeType) {
        case 0: // Forma organica 1 - quasi circolare con leggera irregolarità
          final noise1 = math.sin(angle * 2.1 + seed * 0.3) * 0.025;
          final noise2 = math.cos(angle * 1.7) * 0.020;
          radiusVariation = 1.0 + noise1 + noise2;
          break;

        case 1: // Forma organica 2 - leggermente ovale
          final oval = math.sin(angle) * 0.030;
          final wobble = math.cos(angle * 3) * 0.015;
          radiusVariation = 1.0 + oval + wobble;
          break;

        case 2: // Forma organica 3 - blob morbido
          final blob1 = math.sin(angle * 2.3) * 0.028;
          final blob2 = math.cos(angle * 3.7) * 0.018;
          radiusVariation = 1.0 + blob1 + blob2;
          break;

        case 3: // Forma organica 4 - quasi cerchio con ondulazioni delicate
          final wave = math.cos(angle * 2) * 0.032;
          final ripple = math.sin(angle * 5) * 0.012;
          radiusVariation = 1.0 + wave + ripple;
          break;

        case 4: // Forma organica 5 - blob asimmetrico leggero
          final asym1 = math.sin(angle * 1.7 + 0.5) * 0.030;
          final asym2 = math.cos(angle * 2.9) * 0.022;
          radiusVariation = 1.0 + asym1 + asym2;
          break;

        case 5: // Forma organica 6 - ovale con texture
          final base = math.sin(angle) * 0.026;
          final texture = math.sin(angle * 7) * 0.010;
          radiusVariation = 1.0 + base + texture;
          break;
      }

      final radius = baseRadius * radiusVariation;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      points.add(Offset(x, y));
    }

    // Inizio percorso
    path.moveTo(points[0].dx, points[0].dy);

    // Crea curve super fluide usando cubic bezier con tensione ottimale
    for (int i = 0; i < points.length; i++) {
      final p0 = points[(i - 1 + points.length) % points.length];
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final p3 = points[(i + 2) % points.length];

      // Calcola punti di controllo per Catmull-Rom spline (massima morbidezza)
      final tension = 0.5; // Tensione per curve fluide

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6 * tension;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6 * tension;

      final cp2x = p2.dx - (p3.dx - p1.dx) / 6 * tension;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6 * tension;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Clipper per il bordo ondulato superiore
class _WavyTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Forma organica irregolare come un blob (simile ai cerchi delle categorie)
    path.moveTo(0, 40);

    // Curve irregolari con altezze e lunghezze diverse per effetto blob
    path.cubicTo(
      size.width * 0.05,
      28,
      size.width * 0.12,
      15,
      size.width * 0.22,
      20,
    );

    path.cubicTo(
      size.width * 0.30,
      24,
      size.width * 0.36,
      35,
      size.width * 0.45,
      30,
    );

    path.cubicTo(
      size.width * 0.52,
      26,
      size.width * 0.58,
      18,
      size.width * 0.65,
      22,
    );

    path.cubicTo(
      size.width * 0.72,
      27,
      size.width * 0.78,
      38,
      size.width * 0.86,
      33,
    );

    path.cubicTo(size.width * 0.91, 29, size.width * 0.96, 35, size.width, 38);

    // Completa il resto del contenitore
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
