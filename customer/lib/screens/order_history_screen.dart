import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/live_order.dart';
import '../services/live_order_service.dart';
import '../config/app_colors.dart';

/// Screen storico ordini - Mostra ordini completati/annullati (status 5-6)
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final LiveOrderService _service = LiveOrderService();
  List<LiveOrder> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<int> _expandedOrders = {}; // Track expanded orders

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _service.getOrderHistory();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento dello storico';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 56,
        leading: IconButton(
          icon: Image.asset(
            'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
            width: 24,
            height: 24,
            color: const Color(0xFF0A0A0A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'I miei ordini',
          style: TextStyle(
            color: Color(0xFF0A0A0A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0A0A0A)),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/icons/icons8-aggiornamenti-disponibili-32.png',
              width: 22,
              height: 22,
              color: const Color(0xFF0A0A0A),
            ),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadOrders, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrders,
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: AppColors.gray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun ordine passato',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.gray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gli ordini completati appariranno qui',
              style: TextStyle(fontSize: 14, color: AppColors.gray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      itemCount: _orders.length,
      itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
    );
  }

  Widget _buildOrderCard(LiveOrder order) {
    final isExpanded = _expandedOrders.contains(order.id);

    // Colori diversi per consegnato/annullato
    final bool isDelivered = order.statusId == 5;
    final Color cardColor = isDelivered
        ? const Color(0xFF00C853) // Verde per consegnato
        : const Color(0xFFEF5350); // Rosso per annullato

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header cliccabile
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedOrders.remove(order.id);
                } else {
                  _expandedOrders.add(order.id);
                }
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11),
              topRight: Radius.circular(11),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(11),
                  topRight: const Radius.circular(11),
                  bottomLeft: isExpanded
                      ? Radius.zero
                      : const Radius.circular(11),
                  bottomRight: isExpanded
                      ? Radius.zero
                      : const Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDelivered ? Icons.check_circle : Icons.cancel,
                              color: cardColor,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Ordine #${order.id}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cardColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                order.statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cardColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.startTime != null && order.endTime != null
                              ? '${DateFormat('dd/MM/yyyy').format(DateTime.parse(order.dateOrder))} • ${order.startTime!.substring(0, 5)} - ${order.endTime!.substring(0, 5)}'
                              : DateFormat(
                                  'dd/MM/yyyy',
                                ).format(DateTime.parse(order.dateOrder)),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: cardColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          // Contenuto espandibile
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ristorante
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.restaurantName ?? 'Ristorante',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (order.restaurantAddress != null)
                              Text(
                                order.restaurantAddress!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.gray,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Items dell'ordine
                  if (order.items.isNotEmpty) ...[
                    const Text(
                      'Prodotti ordinati:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lightGray,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.quantity}x',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.foodName ?? 'Prodotto',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '€${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 16),
                  ],

                  // Totale
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Totale',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '€${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ],
                  ),

                  // Info pagamento
                  if (order.paymentMethod != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payment, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          order.paymentMethod!,
                          style: TextStyle(fontSize: 11, color: AppColors.gray),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
