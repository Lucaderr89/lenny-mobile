import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../models/delivery_history.dart';
import '../services/driver_service.dart';

/// DeliveryHistoryScreen - Storico consegne completate con statistiche
class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen>
    with SingleTickerProviderStateMixin {
  final DriverService _driverService = DriverService();
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;

  List<DeliveryHistory> _deliveries = [];
  DeliveryStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? startDateStr = _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null;
      final String? endDateStr = _endDate != null
          ? DateFormat('yyyy-MM-dd').format(_endDate!)
          : null;

      final result = await _driverService.getDeliveryHistory(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (mounted) {
        setState(() {
          _deliveries = result['deliveries'] as List<DeliveryHistory>;
          _stats = result['stats'] as DeliveryStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Errore caricamento storico: $e';
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    // Seleziona data inizio con dialog centralizzato (stile customer)
    final DateTime? startDate = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
      helpText: 'Seleziona data inizio',
      cancelText: 'Annulla',
      confirmText: 'Avanti',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: (context.notte ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
              primary: AppColors.primaryLight, // Azzurro chiaro per data inizio
              onPrimary: Colors.white,
              surface: context.cCard,
              onSurface: context.cTesto,
              surfaceContainerHighest: context.cBordo,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: context.cCard,
              headerBackgroundColor: AppColors.primaryLight, // Azzurro chiaro
              headerForegroundColor: Colors.white,
              dayStyle: const TextStyle(fontSize: 14),
              yearStyle: const TextStyle(fontSize: 16),
              todayForegroundColor: const WidgetStatePropertyAll(
                AppColors.primary,
              ),
              todayBackgroundColor: WidgetStatePropertyAll(
                AppColors.primaryLight.withOpacity(0.2),
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return context.cTestoSec;
                }
                return context.cTesto;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryLight;
                }
                return Colors.transparent;
              }),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (startDate == null) return; // Utente ha annullato

    // Seleziona data fine
    final DateTime? endDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: startDate, // Non può essere prima della data inizio
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
      helpText: 'Seleziona data fine',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: (context.notte ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
              primary: AppColors.primary, // Blu standard per data fine
              onPrimary: Colors.white,
              surface: context.cCard,
              onSurface: context.cTesto,
              surfaceContainerHighest: context.cBordo,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: context.cCard,
              headerBackgroundColor: AppColors.primary, // Blu standard
              headerForegroundColor: Colors.white,
              dayStyle: const TextStyle(fontSize: 14),
              yearStyle: const TextStyle(fontSize: 16),
              todayForegroundColor: const WidgetStatePropertyAll(
                AppColors.primary,
              ),
              todayBackgroundColor: WidgetStatePropertyAll(
                AppColors.primaryLight.withOpacity(0.2),
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return context.cTestoSec;
                }
                return context.cTesto;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (endDate == null) return; // Utente ha annullato

    // Applica il filtro
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
    });
    _loadHistory();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cSfondo,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Storico Consegne',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Statistiche'),
            Tab(text: 'Consegne'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : TabBarView(
              controller: _tabController,
              children: [_buildStatsTab(), _buildDeliveriesTab()],
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.cTestoSec),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadHistory, child: const Text('Riprova')),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(child: Text('Nessuna statistica disponibile'));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          // Riga 1: Totale consegne + Record personale
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: _buildHeroCard(
                    icon: Icons.local_shipping,
                    color: AppColors.primary,
                    darkBg: true,
                    value: '${_stats!.total.deliveries}',
                    label: 'Totale consegne',
                    subtitle: _stats!.total.avgDeliveryMinutes > 0
                        ? 'media ${_stats!.total.avgDeliveryMinutes.toStringAsFixed(0)} min'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeroCard(
                    icon: Icons.emoji_events,
                    color: Colors.amber,
                    darkBg: false,
                    value: _stats!.bestDay != null
                        ? '${_stats!.bestDay!.deliveries}'
                        : '—',
                    label: 'Record giorno',
                    subtitle: _stats!.bestDay != null
                        ? DateFormat('dd/MM/yy')
                            .format(DateTime.parse(_stats!.bestDay!.date))
                        : 'nessun dato',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Riga 2: Oggi / Settimana / Mese
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniPeriodCard(
                    'Oggi',
                    _stats!.today.deliveries,
                    Icons.today,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniPeriodCard(
                    'Settimana',
                    _stats!.thisWeek.deliveries,
                    Icons.date_range,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniPeriodCard(
                    'Mese',
                    _stats!.thisMonth.deliveries,
                    Icons.calendar_month,
                    AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Riga 3: Ristorante più frequente
          Expanded(
            flex: 3,
            child: _buildTopRestaurantCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    return Column(
      children: [
        // Filtri
        Container(
          color: context.cCard,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.date_range, size: 20),
                      label: Text(
                        _startDate != null && _endDate != null
                            ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                            : 'Filtra per data',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_startDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.danger,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.danger.withOpacity(0.1),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Lista consegne
        Expanded(
          child: _deliveries.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _deliveries.length,
                  itemBuilder: (context, index) {
                    return _buildDeliveryCard(_deliveries[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeroCard({
    required IconData icon,
    required Color color,
    required bool darkBg,
    required String value,
    required String label,
    String? subtitle,
  }) {
    final Color bg = darkBg ? color : color.withOpacity(0.09);
    final Color textColor = darkBg ? Colors.white : context.cTesto;
    final Color secondaryColor =
        darkBg ? Colors.white.withOpacity(0.85) : context.cTestoSec;
    final Color iconBg =
        darkBg ? Colors.white.withOpacity(0.2) : color.withOpacity(0.18);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(darkBg ? 0.25 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration:
                  BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(
                icon,
                color: darkBg ? Colors.white : color,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 10, color: secondaryColor))],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPeriodCard(
      String label, int count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        border: context.cBordoCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.cTesto,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: context.cTestoSec)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRestaurantCard() {
    final restaurant = _stats?.topRestaurant;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cCard,
        border: context.cBordoCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.restaurant, color: AppColors.accent, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ristorante più frequente',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.cTestoSec,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant?.name ?? '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.cTesto,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (restaurant != null) ...[const SizedBox(width: 12), Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${restaurant.deliveries}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      height: 1,
                    ),
                  ),
                  Text(
                    'consegne',
                    style: TextStyle(fontSize: 10, color: context.cTestoSec),
                  ),
                ],
              )],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(DeliveryHistory delivery) {
    final deliveredDate = DateTime.parse(delivery.deliveredAt);

    return InkWell(
      onTap: () => _showDeliveryDetailsModal(delivery),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cCard,
          border: context.cBordoCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${delivery.id}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(deliveredDate),
                  style: TextStyle(fontSize: 12, color: context.cTestoSec),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.restaurant, size: 16, color: context.cTestoSec),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    delivery.restaurantName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.cTesto,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: context.cTestoSec),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    delivery.customerAddress,
                    style: TextStyle(fontSize: 13, color: context.cTestoSec),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (delivery.deliveryTimeMinutes != null)
                  _buildDeliveryDetail(
                    Icons.access_time,
                    '${delivery.deliveryTimeMinutes} min',
                  ),
                _buildDeliveryDetail(
                  Icons.euro,
                  '€${delivery.total.toStringAsFixed(2)}',
                ),
                if (delivery.paymentMethod != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          delivery.paymentMethod == 'cash'
                              ? Icons.money
                              : delivery.paymentMethod == 'pos'
                              ? Icons.credit_card
                              : Icons.payment,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          delivery.paymentMethod == 'cash'
                              ? 'Contanti'
                              : delivery.paymentMethod == 'pos'
                              ? 'POS'
                              : delivery.paymentMethod?.toUpperCase() ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryDetailsModal(DeliveryHistory delivery) {
    final deliveredDate = DateTime.parse(delivery.deliveredAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.cBordo,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ordine #${delivery.id}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.cTesto,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '€${delivery.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Data consegna
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cBordo.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: context.cTestoSec,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Consegnato: ${DateFormat('dd/MM/yyyy HH:mm').format(deliveredDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.cTesto,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ristorante
              _buildModalSection(
                'RISTORANTE',
                Icons.restaurant,
                delivery.restaurantName,
                delivery.restaurantAddress,
              ),
              const SizedBox(height: 16),

              // Cliente
              _buildModalSection(
                'CLIENTE',
                Icons.person,
                delivery.customerName,
                delivery.customerAddress,
              ),
              const SizedBox(height: 20),

              // Prodotti
              if (delivery.products.isNotEmpty) ...[
                Text(
                  'PRODOTTI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.cTestoSec,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cBordo.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: delivery.products.asMap().entries.map((entry) {
                      final index = entry.key;
                      final product = entry.value;
                      return Column(
                        children: [
                          if (index > 0) const Divider(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    '${product.quantity}x',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.cTesto,
                                  ),
                                ),
                              ),
                              Text(
                                '€${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: context.cTesto,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Info consegna
              if (delivery.deliveryTimeMinutes != null) ...[
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: context.cTestoSec),
                    const SizedBox(width: 8),
                    Text(
                      'Tempo di consegna: ${delivery.deliveryTimeMinutes} minuti',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.cTesto,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Metodo pagamento
              if (delivery.paymentMethod != null) ...[
                Row(
                  children: [
                    Icon(
                      delivery.paymentMethod == 'cash'
                          ? Icons.money
                          : delivery.paymentMethod == 'pos'
                          ? Icons.credit_card
                          : Icons.payment,
                      size: 16,
                      color: context.cTestoSec,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pagamento: ${delivery.paymentMethodDescription ?? delivery.paymentMethod}',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.cTesto,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalSection(
    String title,
    IconData icon,
    String mainText,
    String subText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.cTestoSec,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cBordo.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.cTesto,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subText,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cTestoSec,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.cTestoSec),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: context.cTesto,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: context.cTestoSec.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Nessuna consegna trovata',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.cTestoSec,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Le tue consegne appariranno qui',
            style: TextStyle(
              fontSize: 14,
              color: context.cTestoSec.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
