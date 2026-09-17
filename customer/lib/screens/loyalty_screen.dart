import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../services/loyalty_service.dart';
import '../models/loyalty_data.dart';
import '../models/loyalty_reward.dart';
import '../models/loyalty_redemption.dart';
import 'wallet_screen.dart';
import '../widgets/app_icon.dart';
import '../widgets/foto_rete.dart';

/// Programma fedelta': punti, tier e premi.
/// Estratta dal vecchio ProfileScreen (che la teneva come corpo
/// dell'intera pagina profilo, con l'account nascosto in un drawer).
class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen>
    with TickerProviderStateMixin {
  final LoyaltyService _loyaltyService = LoyaltyService();

  String _customerName = '';
  String _customerSurname = '';
  String _customerEmail = '';
  String _customerPhone = '';

  // Dati loyalty
  LoyaltyData? _loyaltyData;
  List<LoyaltyReward> _rewards = [];
  List<LoyaltyRedemption> _redemptions = [];
  bool _isLoadingLoyalty = true;

  // Tab controller (ora solo 2 tab: Punti e Premi)
  late TabController _tabController;

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

    _loadUserData();
    _loadLoyaltyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text(
          'Programma fedeltà',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: AppColors.light,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(
            'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
            width: 24,
            height: 24,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
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
                      AppIcon(
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
                      AppIcon(
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

  // Header fisso con dati cliente
  Widget _buildFixedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.light,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    ...[
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
                color: AppColors.gray.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 20),
              Text(
                'Errore caricamento dati',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray.withValues(alpha: 0.7),
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

            // Il prossimo premio e' la cosa che muove davvero: sta in alto.
            if (_loyaltyData!.nextReward != null ||
                _loyaltyData!.affordableRewards > 0) ...[
              _buildNextRewardCard(),
              const SizedBox(height: 16),
            ],

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
                    child: const AppIcon(
                      'assets/icons_svg/icons8-stella-32.svg',
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
                      if (_loyaltyData != null)
                        Text(
                          _loyaltyData!.affordableRewards > 0
                              ? (_loyaltyData!.affordableRewards == 1
                                    ? 'Un premio riscattabile adesso'
                                    : '${_loyaltyData!.affordableRewards} premi riscattabili adesso')
                              : (_loyaltyData!.nextReward != null
                                    ? 'Mancano ${_loyaltyData!.nextReward!.pointsMissing} punti al prossimo premio'
                                    : 'Ordina e accumula punti'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _loyaltyData!.affordableRewards > 0
                                ? AppColors.success
                                : AppColors.gray,
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
                  ).withValues(alpha: 0.7)
                : AppColors.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                    if (currentTier != null && currentTier.pointsMultiplier > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _loyaltyData!.tierValidUntil != null
                              ? 'Punti ${currentTier.moltiplicatoreLabel} fino al ${_formatDate(_loyaltyData!.tierValidUntil!)}'
                              : 'Punti ${currentTier.moltiplicatoreLabel} su ogni ordine',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (currentTier?.slug != null &&
                  _getTierIconPath(currentTier!.slug) != null)
                AppIcon(
                  _getTierIconPath(currentTier.slug)!,
                  size: 48,
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
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          AppIcon(iconPath, size: 20, color: Colors.white),
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
    final finestra = _loyaltyData!.nextTierWindow;

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
                AppIcon(_getTierIconPath(nextTier.slug)!, size: 24)
              else if (nextTier.icon != null)
                Icon(
                  _getIconData(nextTier.icon!),
                  color: AppColors.primary,
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Il livello si conquista con gli ordini recenti, non con la
          // spesa di una vita: la barra conta gli ordini nella finestra.
          Text(
            finestra != null && finestra.windowDays > 0
                ? (finestra.ordersMissing > 0
                      ? 'Ti mancano ${finestra.ordersMissing} ${finestra.ordersMissing == 1 ? 'ordine' : 'ordini'} in ${finestra.windowDays} giorni: punti ${nextTier.moltiplicatoreLabel} per ${finestra.keepDays} giorni'
                      : 'Requisito raggiunto: dal prossimo ordine consegnato sei ${nextTier.name}')
                : 'Punti ${nextTier.moltiplicatoreLabel} su ogni ordine',
            style: const TextStyle(fontSize: 12, color: AppColors.grayDark),
          ),
          const SizedBox(height: 14),
          if (finestra != null && finestra.windowDays > 0)
            _buildProgressBar(
              label: 'Ordini negli ultimi ${finestra.windowDays} giorni',
              current: finestra.ordersInWindow.toDouble(),
              required: finestra.ordersRequired.toDouble(),
              unit: '',
              progress: finestra.progress * 100,
            )
          else
            _buildProgressBar(
              label: 'Ordini completati',
              current: _loyaltyData!.customer.totalOrdersCompleted.toDouble(),
              required: nextTier.unlockMinOrders.toDouble(),
              unit: '',
              progress: _loyaltyData!.progressToNext?.ordersProgress ?? 0,
            ),
        ],
      ),
    );
  }

  /// Numeri interi senza decimali: "3", non "3.0".
  String _num(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  /// "5 EUR" oppure "2,50 EUR".
  String _euro(double? v) {
    final x = v ?? 0;
    if (x == x.roundToDouble()) return '${x.toInt()} EUR';
    return '${x.toStringAsFixed(2).replaceAll('.', ',')} EUR';
  }

  /// Prossimo premio e premi gia' riscattabili, con la barra dei punti.
  Widget _buildNextRewardCard() {
    final dati = _loyaltyData!;
    final punti = dati.customer.loyaltyPoints;
    final prossimo = dati.nextReward;
    final riscattabili = dati.affordableRewards;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: riscattabili > 0 ? AppColors.success : AppColors.lightGray,
          width: riscattabili > 0 ? 2 : 1,
        ),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  riscattabili > 0
                      ? (riscattabili == 1
                            ? 'Hai un premio da riscattare'
                            : 'Hai $riscattabili premi da riscattare')
                      : 'Prossimo premio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: riscattabili > 0
                        ? AppColors.success
                        : AppColors.dark,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  riscattabili > 0 ? 'Riscatta' : 'Vedi i premi',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (prossimo != null) ...[
            const SizedBox(height: 6),
            Text(
              '${prossimo.name}: ti mancano ${prossimo.pointsMissing} punti',
              style: const TextStyle(fontSize: 12, color: AppColors.grayDark),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: prossimo.pointsRequired > 0
                    ? (punti / prossimo.pointsRequired).clamp(0, 1).toDouble()
                    : 1,
                backgroundColor: AppColors.lightGray,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$punti / ${prossimo.pointsRequired} punti',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.gray.withValues(alpha: 0.8),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Hai i punti per ogni premio del catalogo',
              style: TextStyle(fontSize: 12, color: AppColors.grayDark),
            ),
          ],
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
              remaining > 0 ? 'Mancano ${_num(remaining)}$unit' : 'Completato!',
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
          '${_num(current)}$unit / ${_num(required)}$unit',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.gray.withValues(alpha: 0.8),
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
            tier.displayOrder <= (_loyaltyData!.currentTier?.displayOrder ?? 0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primary.withValues(alpha: 0.1)
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
                  AppIcon(_getTierIconPath(tier.slug)!, size: 40),
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
                                  fontSize: 11,
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
                        tier.durata.isEmpty
                            ? tier.requisito
                            : '${tier.requisito}, ${tier.durata.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gray.withValues(alpha: 0.8),
                        ),
                      ),
                      if (tier.pointsMultiplier > 1.0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Punti ${tier.moltiplicatoreLabel} su ogni ordine',
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

    final punti = _loyaltyData?.customer.loyaltyPoints ?? 0;
    // Dal piu' vicino al piu' lontano: cosi' la scala si legge da sola.
    final lista = [..._rewards]
      ..sort((a, b) => a.pointsRequired.compareTo(b.pointsRequired));

    return Column(
      children: lista.map((reward) {
        final inArrivo = reward.comingSoon;
        final canAfford = (reward.canAfford ?? false) && !inArrivo;
        final isAvailable = (reward.isAvailable ?? true) && !inArrivo;
        final attivo = canAfford && isAvailable;
        final Color coloreBadge = attivo
            ? AppColors.success
            : inArrivo
            ? AppColors.primaryLight
            : AppColors.warning;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: attivo
                    ? AppColors.success
                    : inArrivo
                    ? AppColors.primaryLight
                    : AppColors.lightGray,
                width: attivo ? 2 : 1,
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
                    child: FotoRete(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reward.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dark,
                                  ),
                                ),
                                if (inArrivo || reward.typeLabel.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      inArrivo ? 'In arrivo' : reward.typeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: inArrivo
                                            ? AppColors.primaryLight
                                            : AppColors.gray,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: coloreBadge,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppIcon(
                                  'assets/icons_svg/icons8-stella-32.svg',
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
                          color: AppColors.gray.withValues(alpha: 0.8),
                        ),
                      ),
                      // Quanto manca, a colpo d'occhio, per i premi non
                      // ancora raggiunti.
                      if (!canAfford && !inArrivo && isAvailable) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: reward.progresso(punti),
                            backgroundColor: AppColors.lightGray,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.warning,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: attivo
                              ? () => _handleRedeemReward(reward)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: attivo
                                ? AppColors.primary
                                : AppColors.gray,
                            disabledBackgroundColor: inArrivo
                                ? AppColors.primaryLight.withValues(alpha: 0.35)
                                : AppColors.lightGray,
                            disabledForegroundColor: AppColors.grayDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            inArrivo
                                ? 'In arrivo'
                                : !isAvailable
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
                        ? AppColors.success.withValues(alpha: 0.2)
                        : AppColors.gray.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // Il premio attivo porta l'icona regalo del set di casa;
                  // quello gia' usato resta una spunta, che e' segnaletica.
                  child: redemption.isActive
                      ? const AppIcon(
                          'assets/icons_svg/icons8-regalo-32.svg',
                          color: AppColors.success,
                          size: 20,
                        )
                      : const Icon(
                          Icons.check,
                          color: AppColors.gray,
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
                        '${redemption.pointsSpent} punti, ${_formatDate(redemption.redeemedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.gray.withValues(alpha: 0.8),
                        ),
                      ),
                      if (redemption.isActive &&
                          redemption.couponCode != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Coupon ${redemption.couponCode}: lo trovi al checkout',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
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
                        : redemption.isPending
                        ? AppColors.warning
                        : AppColors.danger,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    redemption.statusLabel,
                    style: const TextStyle(
                      fontSize: 11,
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
    final String dettaglio = reward.isCredit
        ? '${_euro(reward.creditAmount)} finiscono subito nel tuo wallet, pronti per il prossimo ordine.'
        : reward.isCoupon
        ? 'Il coupon compare da solo al prossimo checkout, tra quelli suggeriti, e vale 30 giorni.'
        : 'Ti contatteremo per la consegna del premio.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Riscatti questo premio?'),
        content: Text(
          '${reward.name} per ${reward.pointsRequired} punti.\n\n$dettaglio',
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

    try {
      final esito = await _loyaltyService.redeemReward(reward.id);

      // Ricarica dati
      await _loadLoyaltyData();
      if (!mounted) return;

      final tipo = esito?['reward_type']?.toString() ?? reward.rewardType;
      final codice = esito?['coupon_code']?.toString();
      final importo =
          double.tryParse(
            '${esito?['credit_amount'] ?? reward.creditAmount ?? 0}',
          ) ??
          0;
      final bool crediti = tipo == 'app_credit';

      // Una finestra, non un toast: il cliente deve capire DOVE e' finito
      // il premio (nel wallet o al checkout), altrimenti lo cerca a vuoto.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(crediti ? 'Crediti accreditati' : 'Premio riscattato'),
          content: Text(
            crediti
                ? '${_euro(importo)} sono nel tuo wallet: al prossimo ordine li scali dal totale, anche su più ordini.'
                : codice != null && codice.isNotEmpty
                ? 'Il coupon $codice è pronto. Al prossimo checkout lo trovi tra i coupon suggeriti: un tocco e lo applichi. Vale 30 giorni.'
                : 'Premio registrato: ti contatteremo a breve.',
          ),
          actions: [
            if (crediti)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WalletScreen(),
                    ),
                  );
                },
                child: const Text('Vai al wallet'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
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
}
