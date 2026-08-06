import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/live_order.dart';
import '../services/live_order_service.dart';
import '../config/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/guest_gate.dart';
import '../widgets/app_icon.dart';
import '../widgets/foto_rete.dart';

/// Screen ordini attivi - Mostra ordini in corso (status 1-4)
class LiveOrdersScreen extends StatefulWidget {
  const LiveOrdersScreen({super.key});

  @override
  State<LiveOrdersScreen> createState() => _LiveOrdersScreenState();
}

class _LiveOrdersScreenState extends State<LiveOrdersScreen> {
  final LiveOrderService _service = LiveOrderService();
  List<LiveOrder> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<int> _expandedOrders = {}; // Track expanded orders

  // Aggiornamento automatico leggero: ricarica lo stato degli ordini attivi
  // ogni 30s, cosi' la schermata "evolve" da sola mentre l'ordine avanza, senza
  // che l'utente debba trascinare per aggiornare. Non usa GPS ne' mappa: e' una
  // singola chiamata leggera, e si ferma quando non ci sono piu' ordini attivi.
  static const Duration _intervalloRefresh = Duration(seconds: 30);
  Timer? _timerRefresh;

  /// null = non ancora verificato. Un ospite non ha ordini da mostrare: si
  /// presenta l'invito a registrarsi invece di far fallire la chiamata.
  bool? _loggato;

  @override
  void initState() {
    super.initState();
    _avvia();
  }

  Future<void> _avvia() async {
    final loggato = await AuthService().isLoggedIn();
    if (!mounted) return;
    setState(() => _loggato = loggato);
    if (!loggato) return;

    _loadOrders();
    _timerRefresh = Timer.periodic(
      _intervalloRefresh,
      (_) => _loadOrders(silenzioso: true),
    );
  }

  @override
  void dispose() {
    _timerRefresh?.cancel();
    super.dispose();
  }

  /// Carica gli ordini attivi. In modalita' silenziosa (auto-refresh) non mostra
  /// lo spinner e non azzera la lista, cosi' l'aggiornamento non fa "sfarfallare"
  /// la schermata.
  Future<void> _loadOrders({bool silenzioso = false}) async {
    if (!silenzioso) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final orders = await _service.getActiveOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
      // Nessun ordine attivo: non ha senso continuare a interrogare il server.
      if (orders.isEmpty) {
        _timerRefresh?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      if (!silenzioso) {
        setState(() {
          _errorMessage = 'Errore nel caricamento degli ordini';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelOrder(LiveOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annulla ordine'),
        content: Text('Vuoi annullare l\'ordine #${order.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sì, annulla'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _service.cancelOrder(order.id);

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ordine annullato')));
        _loadOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'annullamento')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 56,
        leading: IconButton(
          icon: AppIcon(
'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
            width: 24,
            height: 24,
            color: AppColors.dark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ordini in corso',
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dark),
        actions: [
          IconButton(
            icon: AppIcon(
'assets/icons/icons8-aggiornamenti-disponibili-32.png',
              width: 22,
              height: 22,
              color: AppColors.dark,
            ),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadOrders, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loggato == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loggato == false) {
      return const GuestGate(
        titolo: 'I tuoi ordini',
        messaggio:
            'Con un account segui i tuoi ordini in tempo reale e ritrovi tutto lo storico.',
        icona: Icons.receipt_long_outlined,
        conAppBar: false,
      );
    }

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
              Icons.shopping_bag_outlined,
              size: 80,
              color: AppColors.gray.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun ordine in corso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.gray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gli ordini attivi appariranno qui',
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
    // Differenzia tra ordini PICKUP e DELIVERY
    if (order.pickupDelivery == 'pickup') {
      return _buildPickupOrderCard(order);
    } else {
      return _buildDeliveryOrderCard(order);
    }
  }

  // Card per ordini PICKUP
  Widget _buildPickupOrderCard(LiveOrder order) {
    final cardColor = _getPickupColor(); // Colore custom per pickup
    final isExpanded = _expandedOrders.contains(order.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
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
                color: cardColor.withValues(alpha: 0.25),
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
                            AppIcon(
'assets/icons/icons8-borsa-della-spesa-32.png',
                              color: cardColor,
                              width: 16,
                              height: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Ritiro #${order.id}',
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
                                color: cardColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                order.statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    // Colore della card, non bianco: su header chiaro la
                    // chevron bianca era quasi invisibile
                    color: cardColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          // Timeline sempre visibile: il colpo d'occhio sullo stato, che avanza
          // da solo con l'auto-refresh. Niente mappa ne' posizione del driver.
          _buildTimeline(order),

          // Contenuto espandibile
          if (isExpanded) ...[
            // Contenuto ordine
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ristorante con Data/Ora ritiro
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.restaurantImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: FotoRete(
                            order.restaurantImage!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 40,
                              height: 40,
                              color: AppColors.lightGray,
                              child: const Icon(Icons.restaurant, size: 20),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
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
                      const SizedBox(width: 12),
                      // Data e ora ritiro con glow
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: cardColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              DateFormat(
                                'dd/MM/yy',
                              ).format(DateTime.parse(order.dateOrder)),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cardColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (order.startTime != null && order.endTime != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: cardColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${order.startTime!.substring(0, 5)} - ${order.endTime!.substring(0, 5)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cardColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 20),

                  // Prodotti
                  Text(
                    'Prodotti',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cardColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            '${item.quantity}x',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.foodName ?? 'Prodotto',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (item.extras != null &&
                                    item.extras!.isNotEmpty)
                                  Text(
                                    item.extras!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
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

                  const Divider(height: 20),

                  // Riepilogo prezzi
                  _buildPriceRow('Subtotale', order.subtotal, cardColor),
                  if (order.orderFee != null && order.orderFee! > 0)
                    _buildPriceRow(
                      'Costo servizio',
                      order.orderFee!,
                      cardColor,
                    ),
                  if (order.discountAmount != null && order.discountAmount! > 0)
                    _buildPriceRow(
                      'Sconto',
                      -order.discountAmount!,
                      cardColor,
                      isDiscount: true,
                    ),
                  const Divider(height: 14),
                  _buildPriceRow(
                    'Totale',
                    order.total,
                    cardColor,
                    isBold: true,
                    fontSize: 16,
                  ),

                  const SizedBox(height: 6),

                  // Pagamento
                  Row(
                    children: [
                      AppIcon(
                        _getPaymentMethodIcon(order.paymentMethodSlug),
                        size: 16,
                        color: AppColors.gray,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.paymentMethod ?? 'N/D',
                        style: TextStyle(fontSize: 11, color: AppColors.gray),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _buildSupportRow(order),

            // Bottone annulla (solo se possibile) - PICKUP
            if (order.canCancel)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelOrder(order),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text(
                      'Annulla ordine',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Contatto WhatsApp AZIENDALE per problemi sull'ordine (niente numero
  /// del driver: il canale di assistenza e' quello di Lenny).
  Future<void> _contattaSupporto(LiveOrder order) async {
    final testo = Uri.encodeComponent(
      'Ciao! Ho bisogno di aiuto con l\'ordine #${order.id}',
    );
    final uri = Uri.parse('https://wa.me/393346841489?text=$testo');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Riga assistenza mostrata nelle card espanse
  Widget _buildSupportRow(LiveOrder order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _contattaSupporto(order),
          icon: const Icon(Icons.support_agent, size: 16),
          label: const Text(
            'Serve aiuto? Scrivici su WhatsApp',
            style: TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  // Card per ordini DELIVERY (quella esistente)
  Widget _buildDeliveryOrderCard(LiveOrder order) {
    final cardColor = _getStatusColor(order.statusId);
    final statusMessage = _getStatusMessage(order);
    final isExpanded = _expandedOrders.contains(order.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
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
                color: cardColor.withValues(alpha: 0.25),
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
                                color: cardColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                order.statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    // Colore della card, non bianco: su header chiaro la
                    // chevron bianca era quasi invisibile
                    color: cardColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          // Timeline sempre visibile: il colpo d'occhio sullo stato, che avanza
          // da solo con l'auto-refresh. Niente mappa ne' posizione del driver.
          _buildTimeline(order),

          // Contenuto espandibile
          if (isExpanded) ...[
            // Messaggio status personalizzato
            if (statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: cardColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cardColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Contenuto ordine
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ristorante
                  Row(
                    children: [
                      if (order.restaurantImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: FotoRete(
                            order.restaurantImage!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 40,
                              height: 40,
                              color: AppColors.lightGray,
                              child: const Icon(Icons.restaurant, size: 20),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
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

                  const Divider(height: 20),

                  // Prodotti
                  Text(
                    'Prodotti',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cardColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            '${item.quantity}x',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.foodName ?? 'Prodotto',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (item.extras != null &&
                                    item.extras!.isNotEmpty)
                                  Text(
                                    item.extras!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
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

                  const Divider(height: 20),

                  // Indirizzo consegna
                  if (order.deliveryAddressText != null) ...[
                    // Titolo Consegna + Data
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Consegna',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cardColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: cardColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            DateFormat(
                              'dd/MM/yy',
                            ).format(DateTime.parse(order.dateOrder)),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cardColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Indirizzo + Fascia oraria
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.gray,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.deliveryAddressText!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.gray,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (order.startTime != null && order.endTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: cardColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              '${order.startTime!.substring(0, 5)} - ${order.endTime!.substring(0, 5)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cardColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                  ],

                  // Riepilogo prezzi
                  _buildPriceRow('Subtotale', order.subtotal, cardColor),
                  if (order.deliveryFee > 0)
                    _buildPriceRow('Consegna', order.deliveryFee, cardColor),
                  if (order.orderFee != null && order.orderFee! > 0)
                    _buildPriceRow(
                      'Costo servizio',
                      order.orderFee!,
                      cardColor,
                    ),
                  if (order.discountAmount != null && order.discountAmount! > 0)
                    _buildPriceRow(
                      'Sconto',
                      -order.discountAmount!,
                      cardColor,
                      isDiscount: true,
                    ),
                  const Divider(height: 14),
                  _buildPriceRow(
                    'Totale',
                    order.total,
                    cardColor,
                    isBold: true,
                    fontSize: 16,
                  ),

                  const SizedBox(height: 6),

                  // Pagamento
                  Row(
                    children: [
                      AppIcon(
                        _getPaymentMethodIcon(order.paymentMethodSlug),
                        size: 16,
                        color: AppColors.gray,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.paymentMethod ?? 'N/D',
                        style: TextStyle(fontSize: 11, color: AppColors.gray),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottone annulla (solo se possibile)
            _buildSupportRow(order),

            if (order.canCancel)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelOrder(order),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text(
                      'Annulla ordine',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount,
    Color cardColor, {
    bool isBold = false,
    bool isDiscount = false,
    double fontSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              color: isBold ? null : AppColors.gray,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}€${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: isDiscount ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int statusId) {
    switch (statusId) {
      case 1: // pending
        return const Color(0xFF007BFF); // Blue
      case 2: // assigned
        return const Color(0xFF17A2B8); // Teal
      case 3: // picking_up
        return AppColors.accent; // Yellow
      case 4: // in_delivery
        return AppColors.warning; // Orange
      default:
        return AppColors.gray;
    }
  }

  // Colore specifico per ordini PICKUP (viola/fucsia)
  Color _getPickupColor() {
    return const Color(0xFF9C27B0); // Purple/Magenta
  }

  // Restituisce l'icona corretta in base allo slug del metodo di pagamento
  String _getPaymentMethodIcon(String? slug) {
    switch (slug) {
      case 'stripe':
      case 'nexi':
      case 'pos':
      case 'smac':
        return 'assets/icons/icons8-card-32.png';
      case 'cash':
        return 'assets/icons/icons8-soldi-32.png';
      default:
        return 'assets/icons/icons8-card-32.png';
    }
  }

  String? _getStatusMessage(LiveOrder order) {
    switch (order.statusId) {
      case 1: // pending
        return 'Il ristorante sta preparando il tuo ordine';
      case 2: // assigned
        if (order.driverFullName.isNotEmpty) {
          return '${order.driverFullName} ha preso in carico il tuo ordine';
        }
        return 'Un driver è stato assegnato al tuo ordine';
      case 3: // picking_up
        if (order.driverFullName.isNotEmpty) {
          return '${order.driverFullName} sta ritirando il tuo ordine';
        }
        return 'Il driver sta ritirando il tuo ordine dal ristorante';
      case 4: // in_delivery
        if (order.driverFullName.isNotEmpty) {
          return '${order.driverFullName} sta consegnando il tuo ordine';
        }
        return 'Il tuo ordine è in consegna';
      default:
        return null;
    }
  }

  /// Timeline dei quattro stati dell'ordine, sempre visibile sulla card.
  /// Da' al cliente il colpo d'occhio su dove si trova l'ordine e, con
  /// l'auto-refresh, avanza da sola. Niente mappa ne' posizione del driver.
  Widget _buildTimeline(LiveOrder order) {
    const tappe = [
      (icona: Icons.receipt_long, label: 'Confermato'),
      (icona: Icons.storefront, label: 'In ritiro'),
      (icona: Icons.local_shipping, label: 'In consegna'),
      (icona: Icons.check_circle, label: 'Consegnato'),
    ];

    // Indice della tappa corrente in base allo stato dell'ordine.
    int corrente;
    switch (order.statusId) {
      case 1:
      case 2:
        corrente = 0;
        break;
      case 3:
        corrente = 1;
        break;
      case 4:
        corrente = 2;
        break;
      case 5:
        corrente = 3;
        break;
      default:
        corrente = 0;
    }

    final righe = <Widget>[];
    for (var i = 0; i < tappe.length; i++) {
      final raggiunta = i <= corrente;
      final colore = raggiunta ? AppColors.primary : Colors.grey[300]!;

      // Pallino con icona
      righe.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: raggiunta ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: colore, width: 2),
              ),
              child: Icon(
                tappe[i].icona,
                size: 17,
                color: raggiunta ? Colors.white : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 62,
              child: Text(
                tappe[i].label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: i == corrente ? FontWeight.w700 : FontWeight.w500,
                  color: raggiunta ? AppColors.dark : Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      );

      // Linea di collegamento tra i pallini (non dopo l'ultimo)
      if (i < tappe.length - 1) {
        righe.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 26),
              color: i < corrente ? AppColors.primary : Colors.grey[300],
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: righe),
    );
  }
}
