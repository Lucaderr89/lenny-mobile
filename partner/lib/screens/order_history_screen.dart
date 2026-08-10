import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../services/printer_service.dart';

/// Schermata storico ordini (consegnati e annullati)
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();

  late TabController _tabController;

  bool _isLoading = true;
  String? _error;

  List<Order> _delivered = [];
  List<Order> _cancelled = [];

  // Paginazione lato server: 30 ordini a pagina. Prima la schermata
  // caricava solo la pagina 1 e il resto del periodo era invisibile.
  int _days = 30;
  int _deliveredPage = 1;
  int _cancelledPage = 1;
  int _deliveredTotal = 0;
  int _cancelledTotal = 0;
  bool _caricamentoAltri = false;

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

  static int _totale(Map<String, dynamic> risposta) {
    final pag = risposta['pagination'];
    if (pag is Map) {
      return int.tryParse(pag['total']?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _deliveredPage = 1;
      _cancelledPage = 1;
    });
    try {
      final results = await Future.wait([
        _orderService.getOrderHistory(status: 'delivered', days: _days),
        _orderService.getOrderHistory(status: 'cancelled', days: _days),
      ]);

      if (mounted) {
        setState(() {
          _delivered = (results[0]['orders'] as List<Order>? ?? []);
          _cancelled = (results[1]['orders'] as List<Order>? ?? []);
          _deliveredTotal = _totale(results[0]);
          _cancelledTotal = _totale(results[1]);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Carica la pagina successiva di un tab e la accoda alla lista.
  Future<void> _caricaAltri(String status) async {
    if (_caricamentoAltri) return;
    setState(() => _caricamentoAltri = true);
    try {
      final paginaSuccessiva =
          (status == 'delivered' ? _deliveredPage : _cancelledPage) + 1;
      final risposta = await _orderService.getOrderHistory(
        status: status,
        days: _days,
        page: paginaSuccessiva,
      );
      if (!mounted) return;
      final nuovi = risposta['orders'] as List<Order>? ?? [];
      setState(() {
        if (status == 'delivered') {
          _delivered.addAll(nuovi);
          _deliveredPage = paginaSuccessiva;
          _deliveredTotal = _totale(risposta);
        } else {
          _cancelled.addAll(nuovi);
          _cancelledPage = paginaSuccessiva;
          _cancelledTotal = _totale(risposta);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nel caricamento. Riprova.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _caricamentoAltri = false);
    }
  }

  void _changeDays(int days) {
    setState(() => _days = days);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Storico Ordini'),
        actions: [
          // Filtro periodo
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: 'Periodo',
            onSelected: _changeDays,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('Ultimi 7 giorni')),
              PopupMenuItem(value: 15, child: Text('Ultimi 15 giorni')),
              PopupMenuItem(value: 30, child: Text('Ultimi 30 giorni')),
              PopupMenuItem(value: 90, child: Text('Ultimi 90 giorni')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            height: 36,
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              labelPadding: EdgeInsets.zero,
              indicatorPadding: EdgeInsets.zero,
              tabs: [
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14),
                      const SizedBox(width: 4),
                      Text('Consegnati ($_deliveredTotal)'),
                    ],
                  ),
                ),
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel_outlined, size: 14),
                      const SizedBox(width: 4),
                      Text('Annullati ($_cancelledTotal)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : Column(
              children: [
                _buildPeriodBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: _delivered.isEmpty
                            ? _buildEmpty('Nessun ordine consegnato')
                            : _buildList(
                                _delivered,
                                'delivered',
                                _deliveredTotal,
                              ),
                      ),
                      RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: _cancelled.isEmpty
                            ? _buildEmpty('Nessun ordine annullato')
                            : _buildList(
                                _cancelled,
                                'cancelled',
                                _cancelledTotal,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPeriodBanner() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Periodo: ultimi $_days giorni',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${_deliveredTotal + _cancelledTotal} ordini totali',
            style: TextStyle(fontSize: 12, color: AppColors.gray),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              'Errore nel caricamento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gray, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 72,
            color: AppColors.gray.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            msg,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: 8),
          Text(
            'negli ultimi $_days giorni',
            style: const TextStyle(color: AppColors.gray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Order> orders, String status, int totale) {
    final altriDaCaricare = orders.length < totale;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length + (altriDaCaricare ? 1 : 0),
      itemBuilder: (_, index) {
        if (index >= orders.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _caricamentoAltri
                  ? const CircularProgressIndicator()
                  : OutlinedButton.icon(
                      onPressed: () => _caricaAltri(status),
                      icon: const Icon(Icons.expand_more),
                      label: Text(
                        'Carica altri (${totale - orders.length} rimasti)',
                      ),
                    ),
            ),
          );
        }
        return _buildHistoryCard(orders[index]);
      },
    );
  }

  Widget _buildHistoryCard(Order order) {
    final isDelivered = order.status == 'delivered';
    final statusColor = isDelivered ? AppColors.success : AppColors.danger;
    final statusIcon = isDelivered ? Icons.check_circle : Icons.cancel;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.2), width: 1),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Riga 1: stato, ID, totale
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          isDelivered ? 'CONSEGNATO' : 'ANNULLATO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '#${order.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '€${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Riga 2: cliente e tipo
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: AppColors.gray),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.isDelivery ? 'Consegna' : 'Asporto',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Riga 3: data, orario, n. prodotti
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: AppColors.gray),
                  const SizedBox(width: 4),
                  Text(
                    '${order.formattedDate}  ${order.timeSlot}',
                    style: const TextStyle(fontSize: 12, color: AppColors.gray),
                  ),
                  const Spacer(),
                  Text(
                    '${order.items.length} prodotti',
                    style: const TextStyle(fontSize: 11, color: AppColors.gray),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.gray,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistoryOrderSheet(order: order),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bottom Sheet dettaglio ordine storico
// ─────────────────────────────────────────────────────────
class _HistoryOrderSheet extends StatelessWidget {
  final Order order;
  const _HistoryOrderSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.status == 'delivered';
    final statusColor = isDelivered ? AppColors.success : AppColors.danger;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Intestazione
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ordine #${order.id}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isDelivered ? 'CONSEGNATO' : 'ANNULLATO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info cliente
            _infoRow(Icons.person, order.customerName),
            if (order.customerPhone.isNotEmpty)
              _infoRow(Icons.phone, order.customerPhone),
            if (order.isDelivery && order.deliveryAddress.isNotEmpty)
              _infoRow(Icons.location_on, order.deliveryAddress),
            _infoRow(
              Icons.calendar_today,
              '${order.formattedDate}  ${order.timeSlot}',
            ),

            const Divider(height: 28),

            Text(
              'Articoli:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${item.quantity}x',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '€${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Totale',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '€${order.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            if (order.note != null && order.note!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sticky_note_2,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.note!,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Pulsante ristampa
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _reprintOrder(context),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Ristampa scontrino'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.gray),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _reprintOrder(BuildContext context) async {
    final printer = PrinterService();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final restaurantName = await _getRestaurantName();
      final esito = await printer.printOrder(order, restaurantName);
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              esito.ok
                  ? 'Comanda #${order.id} ristampata'
                  : (esito.motivo ?? 'Errore durante la stampa'),
            ),
            backgroundColor: esito.ok ? AppColors.success : AppColors.danger,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: esito.ok ? 3 : 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String> _getRestaurantName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('restaurant_name') ?? 'Ristorante';
  }
}
