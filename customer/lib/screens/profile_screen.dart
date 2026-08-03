import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/auth_service.dart';
import '../services/loyalty_service.dart';
import '../models/loyalty_data.dart';
import '../models/loyalty_reward.dart';
import '../models/loyalty_redemption.dart';
import 'addresses_screen.dart';
import 'order_history_screen.dart';
import 'wallet_screen.dart';
import 'support_screen.dart';

/// Profile Screen con Drawer laterale
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final LoyaltyService _loyaltyService = LoyaltyService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _customerName = '';
  String _customerSurname = '';
  String _customerEmail = '';
  String _customerPhone = '';
  bool _isLoading = false;
  bool _isEditing = false;

  // Dati loyalty
  LoyaltyData? _loyaltyData;
  List<LoyaltyReward> _rewards = [];
  List<LoyaltyRedemption> _redemptions = [];
  bool _isLoadingLoyalty = true;

  // Tab controller (ora solo 2 tab: Punti e Premi)
  late TabController _tabController;

  // Animation controllers
  AnimationController? _shimmerController;

  // Controllers per l'editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Apri direttamente la tab Punti (index 0)
    _tabController.index = 0;

    // Setup shimmer animation (scorre continuamente)
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _loadUserData();
    _loadLoyaltyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shimmerController?.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadLoyaltyData() async {
    setState(() => _isLoadingLoyalty = true);

    try {
      // Carica dati loyalty in parallelo
      final results = await Future.wait([
        _loyaltyService.getLoyaltyData(),
        _loyaltyService.getRewards(),
        _loyaltyService.getRedemptions(),
      ]);

      setState(() {
        _loyaltyData = results[0] as LoyaltyData?;
        _rewards = results[1] as List<LoyaltyReward>;
        _redemptions = results[2] as List<LoyaltyRedemption>;
        _isLoadingLoyalty = false;
      });
    } catch (e) {
      print('❌ Errore caricamento loyalty: $e');
      setState(() => _isLoadingLoyalty = false);
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final fullName =
          prefs.getString(AppConstants.keyUserFullname) ?? 'Utente';
      final nameParts = fullName.split(' ');
      _customerName = nameParts.isNotEmpty ? nameParts[0] : '';
      _customerSurname = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';
      _customerEmail = prefs.getString(AppConstants.keyUserEmail) ?? '';
      _customerPhone = prefs.getString(AppConstants.keyUserPhone) ?? '';

      // Inizializza i controller
      _nameController.text = _customerName;
      _surnameController.text = _customerSurname;
      _emailController.text = _customerEmail;
      _phoneController.text = _customerPhone;
    });
  }

  Future<void> _saveUserData() async {
    setState(() => _isLoading = true);

    try {
      // Chiama l'API per aggiornare il profilo nel database
      final result = await _authService.updateProfile(
        firstName: _nameController.text.trim(),
        lastName: _surnameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (result['success'] == true) {
        setState(() {
          _customerName = _nameController.text.trim();
          _customerSurname = _surnameController.text.trim();
          _customerPhone = _phoneController.text.trim();
          _isEditing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Dati salvati con successo'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Errore durante il salvataggio',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _cancelEditing() {
    setState(() {
      _nameController.text = _customerName;
      _surnameController.text = _customerSurname;
      _emailController.text = _customerEmail;
      _phoneController.text = _customerPhone;
      _isEditing = false;
    });
  }

  void _showEditProfileDialog() {
    // Reset controllers
    _nameController.text = _customerName;
    _surnameController.text = _customerSurname;
    _phoneController.text = _customerPhone;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Modifica Profilo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _surnameController,
                decoration: InputDecoration(
                  labelText: 'Cognome',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefono',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annulla',
              style: TextStyle(color: AppColors.gray),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Chiudi dialog
              Navigator.pop(context);
              // Salva modifiche
              await _saveUserData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Salva',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Cancellazione dell'account su richiesta dell'utente.
  ///
  /// Due passaggi voluti: la prima schermata spiega cosa succede, la seconda
  /// chiede di scrivere ELIMINA. E' irreversibile e non deve poter partire per
  /// un tocco distratto.
  Future<void> _handleDeleteAccount() async {
    final primaConferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text(
          'Verranno eliminati definitivamente il tuo profilo, i tuoi indirizzi, '
          'i metodi di pagamento salvati e i tuoi preferiti.\n\n'
          'Gli ordini gia\' effettuati restano registrati in forma anonima, come '
          'richiesto dalla normativa fiscale.\n\n'
          'L\'operazione non puo\' essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Continua',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (primaConferma != true || !mounted) return;

    final controller = TextEditingController();
    final confermaFinale = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confermi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scrivi ELIMINA per confermare.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().toUpperCase() == 'ELIMINA',
            ),
            child: const Text(
              'Elimina definitivamente',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (confermaFinale != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await AuthService().deleteAccount();

    if (!mounted) return;
    Navigator.pop(context); // chiude il caricamento

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message),
        backgroundColor:
            response.success ? AppColors.success : AppColors.danger,
      ),
    );

    if (response.success) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/login');
    }
  }

  /// Diagnostica riservata (pressione lunga sul numero di versione).
  ///
  /// Serve a verificare che la catena di segnalazione arrivi davvero a Crashlytics:
  /// invia prima un evento NON fatale e poi, su conferma, provoca un crash reale.
  /// In debug le segnalazioni sono disattivate per scelta, quindi la prova va fatta
  /// su una build di release.
  Future<void> _diagnosticaCrash() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnostica'),
        content: const Text(
          'Invio una segnalazione di prova e poi chiudo l\'app forzando un crash.\n\n'
          'Serve solo a verificare che i report arrivino. Funziona sulle build di '
          'release, non in debug.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Procedi'),
          ),
        ],
      ),
    );

    if (conferma != true) return;

    // 1) Evento non fatale: arriva subito, senza chiudere l'app
    await FirebaseCrashlytics.instance.setCustomKey('diagnostica', true);
    await FirebaseCrashlytics.instance.recordError(
      'Test diagnostico dal profilo',
      StackTrace.current,
      reason: 'verifica manuale Crashlytics',
      fatal: false,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Segnalazione inviata. Ora forzo il crash...'),
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    // 2) Crash reale: viene inviato alla riapertura dell'app
    FirebaseCrashlytics.instance.crash();
  }

  Future<void> _handleLogout() async {
    // Mostra dialog di conferma
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      print('🚪 [LOGOUT] Inizio procedura logout...');
      await _authService.logout();
      print('✅ [LOGOUT] Logout completato');

      if (!mounted) return;

      // Torna al login
      context.go('/login');
    } catch (e) {
      print('💥 [LOGOUT] Errore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il logout: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text(
          'Profilo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: AppColors.light,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
            width: 24,
            height: 24,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Header fisso con dati cliente
          _buildFixedHeader(),
          // TabBar compatta
          Container(
            color: AppColors.light,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.gray,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/icons8-stella-32.png',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 6),
                      const Text('Punti'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/icons8-premi-32.png',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 6),
                      const Text('Premi'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPointsTab(), _buildRewardsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppColors.lightGray,
        child: Column(
          children: [
            // Header del drawer (senza avatar)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_customerName $_customerSurname',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.light,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Image.asset(
                          'assets/icons/icons8-modifica-32.png',
                          width: 20,
                          height: 20,
                          color: AppColors.light,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditProfileDialog();
                        },
                      ),
                    ],
                  ),
                  Text(
                    _customerEmail,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.light.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _buildDrawerItem(
                    icon: 'assets/icons/icons8-indirizzo-32.png',
                    title: 'I miei indirizzi',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddressesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: 'assets/icons/icons8-ordine-di-acquisto-32.png',
                    title: 'I miei ordini',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrderHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: 'assets/icons/icons8-portafoglio-32.png',
                    title: 'Wallet',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalletScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 20),
                  _buildDrawerItem(
                    icon: 'assets/icons/icons8-allarme-32.png',
                    title: 'Notifiche',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funzione in arrivo...')),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: 'assets/icons/icons8-supporto-32.png',
                    title: 'Supporto',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 20),
                  _buildDrawerItem(
                    icon: 'assets/icons/icons8-uscita-32.png',
                    title: 'Logout',
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                  ),

                  // Cancellazione account: obbligatoria per Google Play e diritto
                  // dell'interessato (GDPR). Volutamente in fondo e in rosso.
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.danger,
                      size: 22,
                    ),
                    title: const Text(
                      'Elimina account',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _handleDeleteAccount();
                    },
                  ),

                  // Numero di versione. La pressione LUNGA e' una diagnostica
                  // riservata: forza un crash di prova per verificare che le
                  // segnalazioni arrivino davvero in Crashlytics. Invisibile a chi
                  // non la conosce, e inerte finche' non si tiene premuto.
                  GestureDetector(
                    onLongPress: _diagnosticaCrash,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'Lenny v${AppConstants.appVersion}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required String icon,
    required String title,
    required VoidCallback onTap,
    String? badge,
  }) {
    return ListTile(
      leading: Image.asset(
        icon,
        width: 24,
        height: 24,
        color: AppColors.primary,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.dark,
              ),
            ),
          ),
          if (badge != null) Text(badge, style: const TextStyle(fontSize: 14)),
        ],
      ),
      onTap: onTap,
    );
  }

  // Header fisso con dati cliente
  Widget _buildFixedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.light,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditing) ...[
                      // Modalità editing compatta
                      _buildCompactEditField(
                        controller: _nameController,
                        hint: 'Nome',
                      ),
                      const SizedBox(height: 8),
                      _buildCompactEditField(
                        controller: _surnameController,
                        hint: 'Cognome',
                      ),
                      const SizedBox(height: 8),
                      _buildCompactEditField(
                        controller: _emailController,
                        hint: 'Email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 8),
                      _buildCompactEditField(
                        controller: _phoneController,
                        hint: 'Telefono',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _cancelEditing,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gray,
                                foregroundColor: AppColors.light,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Annulla',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveUserData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.light,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.light,
                                      ),
                                    )
                                  : const Text(
                                      'Salva',
                                      style: TextStyle(fontSize: 13),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Modalità visualizzazione - solo nome e badge
                      Row(
                        children: [
                          Text(
                            '$_customerName $_customerSurname',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_loyaltyData?.currentTier != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _loyaltyData!.currentTier!.color != null
                                    ? Color(
                                        int.parse(
                                          _loyaltyData!.currentTier!.color!
                                              .replaceFirst('#', '0xFF'),
                                        ),
                                      )
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _loyaltyData!.currentTier!.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tab Punti - Panoramica programma fedeltà
  Widget _buildPointsTab() {
    if (_isLoadingLoyalty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loyaltyData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: AppColors.gray.withOpacity(0.5),
              ),
              const SizedBox(height: 20),
              Text(
                'Errore caricamento dati',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadLoyaltyData,
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLoyaltyData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panoramica punti e tier
            _buildLoyaltyOverview(),
            const SizedBox(height: 16),

            // Progressi verso prossimo tier
            if (_loyaltyData!.nextTier != null) ...[
              _buildNextTierProgress(),
              const SizedBox(height: 16),
            ],

            // Vantaggi del tier corrente
            if (_loyaltyData!.currentTier != null) ...[
              const Text(
                'I tuoi vantaggi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),
              _buildCurrentTierBenefits(),
              const SizedBox(height: 16),
            ],

            // Tutti i tier disponibili
            const Text(
              'Tutti i livelli',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 15),
            _buildAllTiers(),
          ],
        ),
      ),
    );
  }

  // Tab Premi - Catalogo premi e riscatti
  Widget _buildRewardsTab() {
    if (_isLoadingLoyalty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadLoyaltyData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con punti disponibili
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.stars,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'I tuoi punti',
                        style: TextStyle(color: AppColors.gray, fontSize: 12),
                      ),
                      Text(
                        '${_loyaltyData?.customer.loyaltyPoints ?? 0} punti',
                        style: const TextStyle(
                          color: AppColors.dark,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Catalogo premi
            const Text(
              'Premi disponibili',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 12),
            _buildRewardsCatalog(),

            const SizedBox(height: 20),

            // Storico riscatti
            if (_redemptions.isNotEmpty) ...[
              const Text(
                'I tuoi riscatti',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),
              _buildRedemptionsHistory(),
            ],
          ],
        ),
      ),
    );
  }

  // Panoramica loyalty con punti e tier
  Widget _buildLoyaltyOverview() {
    final customer = _loyaltyData!.customer;
    final currentTier = _loyaltyData!.currentTier;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            currentTier?.color != null
                ? Color(
                    int.parse(currentTier!.color!.replaceFirst('#', '0xFF')),
                  )
                : AppColors.primary,
            currentTier?.color != null
                ? Color(
                    int.parse(currentTier!.color!.replaceFirst('#', '0xFF')),
                  ).withOpacity(0.7)
                : AppColors.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tier corrente
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Il tuo livello',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTier?.name ?? 'Nessun tier',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (currentTier?.slug != null &&
                  _getTierIconPath(currentTier!.slug) != null)
                Image.asset(
                  _getTierIconPath(currentTier.slug)!,
                  width: 48,
                  height: 48,
                  color: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white30),
          const SizedBox(height: 14),
          // Statistiche
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Punti',
                  '${customer.loyaltyPoints}',
                  'assets/icons/icons8-medaglia-32.png',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Ordini',
                  '${customer.totalOrdersCompleted}',
                  'assets/icons/icons8-ordine-di-acquisto-32.png',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Speso',
                  '€${customer.lifetimeSpending.toStringAsFixed(0)}',
                  'assets/icons/icons8-euro-32.png',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String iconPath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Image.asset(iconPath, width: 20, height: 20, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Progresso verso prossimo tier
  Widget _buildNextTierProgress() {
    final nextTier = _loyaltyData!.nextTier!;
    final progress = _loyaltyData!.progressToNext!;
    final customer = _loyaltyData!.customer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Prossimo livello: ${nextTier.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
              if (_getTierIconPath(nextTier.slug) != null)
                Image.asset(
                  _getTierIconPath(nextTier.slug)!,
                  width: 24,
                  height: 24,
                )
              else if (nextTier.icon != null)
                Icon(
                  _getIconData(nextTier.icon!),
                  color: AppColors.primary,
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Progressi spesa
          _buildProgressBar(
            label: 'Spesa lifetime',
            current: customer.lifetimeSpending,
            required: nextTier.unlockLifetimeSpending,
            unit: '€',
            progress: progress.spendingProgress,
          ),
          const SizedBox(height: 12),
          // Progressi ordini
          _buildProgressBar(
            label: 'Ordini completati',
            current: customer.totalOrdersCompleted.toDouble(),
            required: nextTier.unlockMinOrders.toDouble(),
            unit: '',
            progress: progress.ordersProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required double current,
    required double required,
    required String unit,
    required double progress,
  }) {
    final remaining = required - current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
            Text(
              remaining > 0
                  ? 'Mancano ${remaining.toStringAsFixed(remaining < 10 ? 1 : 0)}$unit'
                  : 'Completato!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: remaining > 0 ? AppColors.warning : AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: AppColors.lightGray,
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining > 0 ? AppColors.primary : AppColors.success,
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${current.toStringAsFixed(current < 10 ? 1 : 0)}$unit / ${required.toStringAsFixed(0)}$unit',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.gray.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  // Vantaggi tier corrente
  Widget _buildCurrentTierBenefits() {
    final currentTier = _loyaltyData!.currentTier!;
    final benefits = currentTier.benefits;

    if (benefits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Nessun vantaggio disponibile per questo livello',
          style: TextStyle(fontSize: 12, color: AppColors.gray),
        ),
      );
    }

    return Column(
      children: benefits.map((benefit) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    benefit,
                    style: const TextStyle(fontSize: 13, color: AppColors.dark),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Tutti i tier
  Widget _buildAllTiers() {
    final allTiers = _loyaltyData!.allTiers;
    final currentTierId = _loyaltyData!.currentTier?.id;

    return Column(
      children: allTiers.map((tier) {
        final isCurrent = tier.id == currentTierId;
        final isUnlocked =
            _loyaltyData!.customer.lifetimeSpending >=
                tier.unlockLifetimeSpending &&
            _loyaltyData!.customer.totalOrdersCompleted >= tier.unlockMinOrders;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.light,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent ? AppColors.primary : AppColors.lightGray,
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                if (_getTierIconPath(tier.slug) != null)
                  Image.asset(
                    _getTierIconPath(tier.slug)!,
                    width: 40,
                    height: 40,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tier.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? AppColors.primary
                                  : AppColors.dark,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ATTUALE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Spesa: €${tier.unlockLifetimeSpending.toStringAsFixed(0)} • Ordini: ${tier.unlockMinOrders}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gray.withOpacity(0.8),
                        ),
                      ),
                      if (tier.pointsMultiplier > 1.0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Punti x${tier.pointsMultiplier.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  isUnlocked ? Icons.check_circle : Icons.lock,
                  color: isUnlocked ? AppColors.success : AppColors.gray,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Catalogo premi
  Widget _buildRewardsCatalog() {
    if (_rewards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Nessun premio disponibile al momento',
            style: TextStyle(fontSize: 14, color: AppColors.gray),
          ),
        ),
      );
    }

    return Column(
      children: _rewards.map((reward) {
        final canAfford = reward.canAfford ?? false;
        final isAvailable = reward.isAvailable ?? true;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canAfford && isAvailable
                    ? AppColors.success
                    : AppColors.lightGray,
                width: canAfford && isAvailable ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reward.imageUrl != null && reward.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Image.network(
                      reward.imageUrl!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          color: AppColors.lightGray,
                          child: const Icon(
                            Icons.image,
                            size: 48,
                            color: AppColors.gray,
                          ),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reward.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: canAfford
                                  ? AppColors.success
                                  : AppColors.warning,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${reward.pointsRequired}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reward.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gray.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canAfford && isAvailable
                              ? () => _handleRedeemReward(reward)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford && isAvailable
                                ? AppColors.primary
                                : AppColors.gray,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            !isAvailable
                                ? 'Non disponibile'
                                : canAfford
                                ? 'Riscatta'
                                : 'Mancano ${reward.pointsMissing} punti',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Storico riscatti
  Widget _buildRedemptionsHistory() {
    return Column(
      children: _redemptions.map((redemption) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: redemption.isActive
                        ? AppColors.success.withOpacity(0.2)
                        : AppColors.gray.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    redemption.isActive ? Icons.card_giftcard : Icons.check,
                    color: redemption.isActive
                        ? AppColors.success
                        : AppColors.gray,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        redemption.rewardName ?? 'Premio',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${redemption.pointsSpent} punti • ${_formatDate(redemption.redeemedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gray.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: redemption.isActive
                        ? AppColors.success
                        : redemption.isUsed
                        ? AppColors.gray
                        : AppColors.danger,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    redemption.statusLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleRedeemReward(LoyaltyReward reward) async {
    // Conferma riscatto
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma riscatto'),
        content: Text(
          'Vuoi riscattare "${reward.name}" per ${reward.pointsRequired} punti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Riscatta'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Mostra loading
    setState(() => _isLoading = true);

    try {
      await _loyaltyService.redeemReward(reward.id);

      // Ricarica dati
      await _loadLoyaltyData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premio riscattato con successo!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _getTierIconPath(String? slug) {
    if (slug == null) return null;
    switch (slug) {
      case 'base':
        return 'assets/icons/icons8-esplosione-fuochi-artificio-48.png';
      case 'fan':
        return 'assets/icons/icons8-star-logo-48.png';
      case 'lover':
        return 'assets/icons/icons8-cuore-cucito-48.png';
      case 'legend':
        return 'assets/icons/icons8-iron-man-48.png';
      default:
        return null;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'diamond':
        return Icons.diamond;
      case 'crown':
        return Icons.workspace_premium;
      case 'trophy':
        return Icons.emoji_events;
      default:
        return Icons.card_membership;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Campo edit compatto
  Widget _buildCompactEditField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.gray.withOpacity(0.6)),
        filled: true,
        fillColor: AppColors.lightGray,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
