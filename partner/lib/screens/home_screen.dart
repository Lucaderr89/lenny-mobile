import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../services/printer_service.dart';
import '../services/fcm_service.dart';
import 'package:audioplayers/audioplayers.dart';

/// Home Screen per partner - Visualizzazione ordini
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  final PrinterService _printerService = PrinterService();

  String _restaurantName = '';
  bool _isLoading = true;
  List<Order> _orders = [];

  /// Ordini annullati arrivati dal server. Non compaiono nelle liste: servono
  /// per l'avviso bloccante quando l'annullamento arriva dopo la stampa.
  List<Order> _annullati = [];

  /// Ordini gia' stampati, persistiti su disco. Tenerli solo in memoria
  /// significava che dopo un riavvio del tablet gli ordini arrivati ad app
  /// spenta venivano marcati come "gia' visti" e non si stampavano mai.
  final Set<int> _stampati = {};
  static const String _chiaveStampati = 'partner_ordini_stampati';
  static const String _chiavePrimoAvvio = 'partner_primo_avvio_fatto';
  static const int _maxStampatiMemorizzati = 300;
  bool _memoriaCaricata = false;

  bool _autoPrintEnabled = true; // Stampa automatica abilitata
  bool _stampaInCorso = false; // Evita stampe sovrapposte sulla stessa stampante

  /// Ordini che non si sono riusciti a stampare, con il motivo: restano in
  /// evidenza finche' non vengono ristampati.
  final Map<int, String> _stampeFallite = {};

  /// Ordini annullati per cui il ristorante ha gia' confermato la lettura
  /// dell'avviso: non vanno riproposti a ogni aggiornamento.
  final Set<int> _annullatiConfermati = {};
  static const String _chiaveAnnullati = 'partner_annullati_confermati';

  /// Impronta del pagamento (stato + metodo) al momento della stampa, per
  /// ordine: se al giro dopo e' diversa, il ristorante ha in mano una comanda
  /// che dice il falso e va avvisato.
  final Map<int, String> _pagamentiStampati = {};
  static const String _chiavePagamenti = 'partner_pagamenti_stampati';

  /// Evita di sovrapporre piu' avvisi bloccanti.
  bool _avvisoInCorso = false;
  Timer? _ordersRefreshTimer;
  StreamSubscription? _fcmSubscription;
  late TabController _tabController;
  late AnimationController _pulseController;

  // Filtri per le liste
  List<Order> get _deliveryOrders =>
      _orders.where((o) => o.isDelivery).toList();
  List<Order> get _pickupOrders => _orders.where((o) => o.isPickup).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startOrdersRefresh();
    // Ascolta push FCM in foreground per aggiornare ordini in tempo reale
    _fcmSubscription = FcmService().onForegroundMessage.listen((message) async {
      final event = message.data['event'] ?? '';
      if (event == 'new_order') {
        await _loadOrders();
      } else if (event == 'order_cancelled_by_customer' ||
          event == 'order_cancelled') {
        await _loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ordersRefreshTimer?.cancel();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quando l'app viene riportata in foreground, aggiorna solo gli ordini
      // la memoria delle stampe e' su disco, quindi non si ristampa nulla
      _loadOrders();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _restaurantName =
          prefs.getString(AppConstants.keyRestaurantName) ?? 'Ristorante';

      await _loadOrders();
    } catch (e) {
      debugPrint('Errore caricamento dati: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Carica da disco gli ordini gia' stampati, le conferme di lettura degli
  /// annullati e le impronte pagamento.
  /// Alla primissima apertura dell'app la memoria e' vuota: in quel caso si
  /// registrano gli ordini presenti senza stamparli (altrimenti il ristorante
  /// si troverebbe a stampare tutto lo storico) e gli annullati gia' presenti
  /// si danno per letti (sono di prima dell'installazione).
  Future<void> _caricaMemoriaStampe(List<Order> ordiniCorrenti) async {
    if (_memoriaCaricata) return;

    final prefs = await SharedPreferences.getInstance();
    final primoAvvioFatto = prefs.getBool(_chiavePrimoAvvio) ?? false;

    if (!primoAvvioFatto) {
      for (final o in ordiniCorrenti) {
        if (o.isCancelled) {
          _annullatiConfermati.add(o.id);
        } else {
          _stampati.add(o.id);
          _pagamentiStampati[o.id] = o.paymentFingerprint;
        }
      }
      await prefs.setBool(_chiavePrimoAvvio, true);
      await _salvaMemoriaStampe();
    } else {
      final salvati = prefs.getStringList(_chiaveStampati) ?? const [];
      _stampati.addAll(salvati.map(int.tryParse).whereType<int>());

      final confermati = prefs.getStringList(_chiaveAnnullati) ?? const [];
      _annullatiConfermati.addAll(
        confermati.map(int.tryParse).whereType<int>(),
      );

      final impronte = prefs.getString(_chiavePagamenti);
      if (impronte != null && impronte.isNotEmpty) {
        try {
          final mappa = jsonDecode(impronte) as Map<String, dynamic>;
          mappa.forEach((chiave, valore) {
            final id = int.tryParse(chiave);
            if (id != null) _pagamentiStampati[id] = valore.toString();
          });
        } catch (e) {
          debugPrint('Impronte pagamento non leggibili: $e');
        }
      }
    }

    _memoriaCaricata = true;
  }

  /// Taglia un elenco ordinato di id tenendo solo i piu' recenti.
  List<int> _idPiuRecenti(Set<int> ids) {
    final lista = ids.toList()..sort();
    return lista.length > _maxStampatiMemorizzati
        ? lista.sublist(lista.length - _maxStampatiMemorizzati)
        : lista;
  }

  Future<void> _salvaMemoriaStampe() async {
    final prefs = await SharedPreferences.getInstance();
    // Si tengono solo gli id piu' recenti: le liste non devono crescere
    // all'infinito.
    final daSalvare = _idPiuRecenti(_stampati);
    _stampati
      ..clear()
      ..addAll(daSalvare);
    await prefs.setStringList(
      _chiaveStampati,
      daSalvare.map((e) => e.toString()).toList(),
    );

    final confermatiDaSalvare = _idPiuRecenti(_annullatiConfermati);
    _annullatiConfermati
      ..clear()
      ..addAll(confermatiDaSalvare);
    await prefs.setStringList(
      _chiaveAnnullati,
      confermatiDaSalvare.map((e) => e.toString()).toList(),
    );

    // Le impronte pagamento hanno senso solo per ordini ancora in memoria.
    _pagamentiStampati.removeWhere((id, _) => !_stampati.contains(id));
    await prefs.setString(
      _chiavePagamenti,
      jsonEncode(
        _pagamentiStampati.map((id, fp) => MapEntry(id.toString(), fp)),
      ),
    );
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _orderService.getOrders();
      if (!mounted) return;

      await _caricaMemoriaStampe(orders);
      if (!mounted) return;

      final attivi = orders.where((o) => !o.isCancelled).toList();
      final annullati = orders.where((o) => o.isCancelled).toList();

      // Un ordine annullato non va piu' stampato: se era tra i falliti, il
      // banner rosso deve sparire (l'avviso di annullamento fa il resto).
      for (final o in annullati) {
        _stampeFallite.remove(o.id);
      }

      // Da stampare: mai stampato prima, in qualunque stato attivo. Prima
      // uscivano solo pending/assigned: un ordine gia' preso in carico dal
      // pannello prima che l'app lo vedesse non veniva mai stampato.
      final daStampare = attivi
          .where((o) => !_stampati.contains(o.id))
          .toList();

      // Ordini stampati prima che esistesse l'impronta pagamento: si registra
      // quella attuale senza avvisare, da qui in poi i cambi si vedono.
      var improntePagamentoAggiunte = false;
      for (final o in attivi) {
        if (_stampati.contains(o.id) &&
            !_pagamentiStampati.containsKey(o.id)) {
          _pagamentiStampati[o.id] = o.paymentFingerprint;
          improntePagamentoAggiunte = true;
        }
      }

      setState(() {
        _orders = attivi;
        _annullati = annullati;
      });

      if (improntePagamentoAggiunte) {
        await _salvaMemoriaStampe();
      }

      if (daStampare.isNotEmpty && _autoPrintEnabled) {
        for (final order in daStampare) {
          _showNewOrderNotification(order);
        }
        // Sequenziale: due comande in parallelo si sovrappongono sulla stessa
        // stampante e escono mescolate.
        await _stampaInSequenza(daStampare);
      }

      await _mostraAvvisiBloccanti();
    } catch (e) {
      debugPrint('Errore caricamento ordini: $e');
    }
  }

  /// Stampa gli ordini uno alla volta, segnando l'esito.
  Future<void> _stampaInSequenza(List<Order> ordini) async {
    if (_stampaInCorso) return;
    _stampaInCorso = true;
    try {
      for (final order in ordini) {
        final esito = await _printerService.printOrder(order, _restaurantName);
        if (esito.ok) {
          _stampati.add(order.id);
          // La comanda in mano al ristorante dice questo pagamento: e' il
          // riferimento per accorgersi di cambi successivi.
          _pagamentiStampati[order.id] = order.paymentFingerprint;
          _stampeFallite.remove(order.id);
        } else {
          // Non si segna come stampato: cosi' resta ristampabile.
          _stampeFallite[order.id] =
              esito.motivo ?? 'Errore durante la stampa';
        }
        if (mounted) setState(() {});
      }
      await _salvaMemoriaStampe();
    } finally {
      _stampaInCorso = false;
    }
  }

  /// Notifica visiva per nuovo ordine
  void _showNewOrderNotification(Order order) {
    // Riproduci suono di notifica
    _playNotificationSound();

    // Vibra il dispositivo
    HapticFeedback.vibrate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nuovo ordine #${order.id} - ${order.customerName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Riproduce suono di notifica
  Future<void> _playNotificationSound() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/new_order.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint('Impossibile riprodurre suono: $e');
    }
  }

  /// Stampa manuale di un ordine (dalla card o dopo un fallimento).
  Future<void> _ristampa(Order order) async {
    await _stampaInSequenza([order]);
    if (!mounted) return;
    final fallita = _stampeFallite[order.id];
    _showMessage(
      fallita ?? 'Comanda #${order.id} stampata',
      fallita == null,
    );
  }

  // ── Avvisi bloccanti ──────────────────────────────────────────────────────
  //
  // Due casi in cui la comanda in mano al ristorante dice il falso:
  // - ordine annullato dopo la stampa: la cucina va fermata;
  // - pagamento cambiato dopo la stampa: la cassa sbaglierebbe l'incasso.
  // In entrambi i casi: avviso a tutto schermo, impossibile da ignorare,
  // che si chiude solo con la conferma di lettura. Uno alla volta.

  Future<void> _mostraAvvisiBloccanti() async {
    if (_avvisoInCorso || !mounted) return;
    _avvisoInCorso = true;
    try {
      while (mounted) {
        final annullato = _annullati
            .where(
              (o) =>
                  _stampati.contains(o.id) &&
                  !_annullatiConfermati.contains(o.id),
            )
            .firstOrNull;
        if (annullato != null) {
          await _avvisoOrdineAnnullato(annullato);
          _annullatiConfermati.add(annullato.id);
          await _salvaMemoriaStampe();
          continue;
        }

        final cambiato = _orders
            .where(
              (o) =>
                  _stampati.contains(o.id) &&
                  _pagamentiStampati.containsKey(o.id) &&
                  _pagamentiStampati[o.id] != o.paymentFingerprint,
            )
            .firstOrNull;
        if (cambiato != null) {
          final ristampa = await _avvisoPagamentoCambiato(cambiato);
          // Confermato: da qui in poi vale il pagamento nuovo.
          _pagamentiStampati[cambiato.id] = cambiato.paymentFingerprint;
          await _salvaMemoriaStampe();
          if (ristampa == true) {
            await _stampaInSequenza([cambiato]);
          }
          continue;
        }

        break;
      }
    } finally {
      _avvisoInCorso = false;
    }
  }

  Future<void> _avvisoOrdineAnnullato(Order order) async {
    _playNotificationSound();
    HapticFeedback.vibrate();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog.fullscreen(
          backgroundColor: AppColors.danger,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cancel_outlined,
                      color: Colors.white, size: 88),
                  const SizedBox(height: 20),
                  const Text(
                    'ORDINE ANNULLATO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ordine #${order.id} - ${order.customerName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (order.timeSlot.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${order.formattedDate}  ${order.timeSlot}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'NON preparare questo ordine.\n'
                    'Se la comanda e\' gia\' in cucina, ritirala.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 64,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text(
                        'HO LETTO, AVVISO LA CUCINA',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Restituisce true se il ristorante ha scelto di ristampare la comanda.
  Future<bool?> _avvisoPagamentoCambiato(Order order) async {
    _playNotificationSound();
    HapticFeedback.vibrate();
    final prima = Order.descriviPagamento(_pagamentiStampati[order.id] ?? '');
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog.fullscreen(
          backgroundColor: AppColors.primaryDark,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.payments_outlined,
                      color: Colors.white, size: 88),
                  const SizedBox(height: 20),
                  const Text(
                    'PAGAMENTO CAMBIATO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ordine #${order.id} - ${order.customerName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'La comanda stampata dice:\n$prima',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ora l\'ordine risulta:\n${order.paymentDescription}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 64,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                      ),
                      child: const Text(
                        'HO LETTO, RISTAMPA LA COMANDA',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                      ),
                      child: const Text(
                        'HO LETTO, SENZA RISTAMPA',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startOrdersRefresh() {
    _ordersRefreshTimer?.cancel();
    _ordersRefreshTimer = Timer.periodic(
      const Duration(seconds: AppConstants.ordersRefreshInterval),
      (_) => _loadOrders(),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma logout'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Text(_restaurantName, style: const TextStyle(fontSize: 16)),
        actions: [
          // Pulsante test stampante
          IconButton(
            icon: const Icon(Icons.science, color: Colors.white),
            onPressed: _testPrinter,
            tooltip: 'Test Stampante',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
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
                  child: Text('Consegne (${_deliveryOrders.length})'),
                ),
                Tab(
                  height: 36,
                  child: Text('Asporto (${_pickupOrders.length})'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildAvvisoStampe(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab Consegne
                      RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: _deliveryOrders.isEmpty
                            ? _buildEmptyState('Nessuna consegna')
                            : _buildOrdersList(_deliveryOrders),
                      ),
                      // Tab Asporto
                      RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: _pickupOrders.isEmpty
                            ? _buildEmptyState('Nessun ordine asporto')
                            : _buildOrdersList(_pickupOrders),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Avviso permanente per le comande non stampate.
  /// Prima un fallimento di stampa finiva solo nei log: l'ordine risultava
  /// ricevuto ma la cucina non aveva nulla in mano.
  Widget _buildAvvisoStampe() {
    if (_stampeFallite.isEmpty) return const SizedBox.shrink();

    final idFalliti = _stampeFallite.keys.toList()..sort();
    final motivo = _stampeFallite[idFalliti.first]!;
    final ordine = _orders.where((o) => o.id == idFalliti.first).firstOrNull;

    return Container(
      width: double.infinity,
      color: AppColors.danger,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          const Icon(Icons.print_disabled, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idFalliti.length == 1
                      ? 'Comanda #${idFalliti.first} non stampata'
                      : '${idFalliti.length} comande non stampate',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  motivo,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          if (ordine != null)
            TextButton(
              onPressed: () => _ristampa(ordine),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.danger,
              ),
              child: const Text('Ristampa'),
            ),
        ],
      ),
    );
  }

  /// Costruisce il Drawer laterale
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header drawer
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _restaurantName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Stampa Automatica ──
          ListTile(
            leading: Icon(
              _autoPrintEnabled ? Icons.print : Icons.print_disabled,
              color: _autoPrintEnabled ? AppColors.primary : AppColors.gray,
            ),
            title: const Text('Stampa Automatica'),
            trailing: Switch(
              value: _autoPrintEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (value) {
                setState(() => _autoPrintEnabled = value);
                Navigator.pop(context); // chiudi drawer
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? 'Stampa automatica ATTIVA'
                          : 'Stampa automatica DISATTIVATA',
                    ),
                    backgroundColor: value
                        ? AppColors.success
                        : AppColors.warning,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            onTap: () {
              setState(() => _autoPrintEnabled = !_autoPrintEnabled);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _autoPrintEnabled
                        ? 'Stampa automatica ATTIVA'
                        : 'Stampa automatica DISATTIVATA',
                  ),
                  backgroundColor: _autoPrintEnabled
                      ? AppColors.success
                      : AppColors.warning,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          const Divider(height: 1),

          // ── Storico Ordini ──
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.info),
            title: const Text('Storico Ordini'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.pop(context); // chiudi drawer
              context.push('/history');
            },
          ),

          const Divider(height: 1),

          // ── Fatture ──
          ListTile(
            leading: const Icon(Icons.receipt_long, color: AppColors.accent),
            title: const Text('Fatture'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sezione Fatture in arrivo'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          const Spacer(),

          // ── Footer versione ──
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Lenny Partner v1.0.0',
              style: TextStyle(fontSize: 11, color: AppColors.gray),
            ),
          ),
        ],
      ),
    );
  }

  /// Test stampante
  Future<void> _testPrinter() async {
    final printerService = PrinterService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final available = await printerService.isPrinterAvailable();

      if (!available) {
        if (mounted) {
          Navigator.pop(context);
          _showMessage(
            'Stampante non disponibile. Verifica che sia un dispositivo Sunmi.',
            false,
          );
        }
        return;
      }

      final success = await printerService.printTest();

      if (mounted) {
        Navigator.pop(context);

        if (success) {
          _showMessage(
            'Stampante funzionante. Verifica lo scontrino stampato',
            true,
          );
        } else {
          _showMessage('Errore durante il test di stampa', false);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showMessage('Errore: ${e.toString()}', false);
      }
    }
  }

  void _showMessage(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEmptyState([String message = 'Nessun ordine']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: AppColors.gray.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.gray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gli ordini in arrivo appariranno qui',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.gray),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    // NB: qui c'era `order.timeSlot.substring(0, 5);`, una riga il cui
    // risultato veniva buttato via ma che poteva far crashare la schermata
    // con RangeError su un ordine senza fascia (il getter timeSlot in quel
    // caso restituisce stringa vuota). Zero benefici, un rischio: rimossa.

    // Verifica se l'ordine è nuovo (pending o assigned)
    final isNewOrder = order.status == 'pending' || order.status == 'assigned';

    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNewOrder
              ? AppColors
                    .danger // Bordo rosso per ordini nuovi
              : statusColor.withValues(alpha: 0.3),
          width: isNewOrder ? 3 : 1, // Bordo più spesso per ordini nuovi
        ),
        boxShadow: [
          BoxShadow(
            color: isNewOrder
                ? AppColors.danger.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isNewOrder ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header colorato con orario e stato
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Column(
              children: [
                // Prima riga: Badge stato, ID ordine, Totale
                Row(
                  children: [
                    // Badge stato
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.partnerBadgeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ID ordine - PIÙ IN EVIDENZA
                    Text(
                      '#${order.id}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    const Spacer(),
                    // Totale
                    Text(
                      '€${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Seconda riga: Data e Orario
                Row(
                  children: [
                    // Data
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.formattedDate,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Orario slot completo
                    Icon(Icons.access_time, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      order.timeSlot,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body con dettagli
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cliente, telefono e indirizzo (compatto)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome e indirizzo sulla stessa riga
                          Row(
                            children: [
                              Text(
                                order.customerName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                              const Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  order.deliveryAddress,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.dark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (order.customerPhone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                order.customerPhone,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.gray.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Prodotti (numero)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.warning,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${order.items.length} ${order.items.length == 1 ? 'prodotto' : 'prodotti'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark,
                      ),
                    ),
                    const Spacer(),
                    // Stampa manuale direttamente dalla card: prima l'unico
                    // punto di stampa era dentro la scheda di dettaglio.
                    _buildBottoneStampaCard(order),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.gray.withValues(alpha: 0.5),
                    ),
                  ],
                ),

                // Bottone "Conferma ritiro" per ordini in asporto
                if (order.isPickup) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmPickup(order),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text(
                        'Conferma ritiro',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Avvolgi in animazione pulsante solo se è un ordine nuovo
    if (isNewOrder) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale =
              1.0 + (_pulseController.value * 0.02); // Pulsazione leggera 0-2%
          return Transform.scale(
            scale: scale,
            child: InkWell(
              onTap: () => _showOrderDetails(order),
              borderRadius: BorderRadius.circular(12),
              child: cardContent,
            ),
          );
        },
      );
    } else {
      return InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    }
  }

  /// Bottone di stampa sulla card: rosso se l'ultima stampa e' fallita.
  Widget _buildBottoneStampaCard(Order order) {
    final fallita = _stampeFallite.containsKey(order.id);
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: () => _ristampa(order),
        icon: Icon(fallita ? Icons.print_disabled : Icons.print, size: 16),
        label: Text(
          fallita ? 'Ristampa' : 'Stampa',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: fallita ? Colors.white : AppColors.primary,
          backgroundColor: fallita ? AppColors.danger : null,
          side: BorderSide(
            color: fallita ? AppColors.danger : AppColors.primary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning; // Arancione per nuovo ordine
      case 'assigned':
        return AppColors.info; // Blu per ordine assegnato
      case 'picking_up':
        return const Color(0xFFFBC02D); // Giallo dorato per ritiro in corso
      case 'in_delivery':
        return const Color(0xFF673AB7); // Viola per in consegna
      case 'delivered':
        return AppColors.success; // Verde per consegnato
      case 'cancelled':
        return AppColors.danger; // Rosso per annullato
      default:
        return AppColors.gray;
    }
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(order: order),
    );
  }

  // ── Conferma ritiro asporto ────────────────────────────────────────────────
  Future<void> _confirmPickup(Order order) async {
    // Chiedi conferma
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma ritiro'),
        content: Text(
          'Confermi che il cliente ha ritirato l\'ordine #${order.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _orderService.confirmPickup(order.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ritiro confermato'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadOrders(); // Ricarica lista — l'ordine sparirà dai "attivi"
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore nella conferma del ritiro. Riprova.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

// NB: il dialog "Posticipa ordine" e' stato rimosso insieme al suo endpoint.
// Scriveva una colonna inesistente, quindi non produceva alcun effetto, e non
// esisteva una funzione corrispondente ne' nell'app cliente ne' nel pannello.

/// Bottom sheet con dettagli ordine
class _OrderDetailsSheet extends StatelessWidget {
  final Order order;

  const _OrderDetailsSheet({required this.order});

  /// Raggruppa gli extra per categoria
  List<Widget> _buildExtrasGrouped(List<OrderExtra> extras) {
    // Raggruppa per group_name
    final Map<String?, List<OrderExtra>> grouped = {};
    for (var extra in extras) {
      final groupName = extra.groupName ?? 'Extra';
      if (!grouped.containsKey(groupName)) {
        grouped[groupName] = [];
      }
      grouped[groupName]!.add(extra);
    }

    // Costruisci widget
    final List<Widget> widgets = [];
    grouped.forEach((groupName, groupExtras) {
      // Nome gruppo
      widgets.add(
        Text(
          groupName ?? 'Extra',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.gray.withValues(alpha: 0.7),
          ),
        ),
      );

      // Lista extra
      for (var extra in groupExtras) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 12,
                  color: AppColors.success.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    extra.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.dark.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                if (extra.price > 0)
                  Text(
                    '+€${extra.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      widgets.add(const SizedBox(height: 4));
    });

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
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

            // Titolo
            Row(
              children: [
                Text(
                  'Ordine #${order.id}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Items
            Text(
              'Articoli:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.quantity}x',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                Text(
                                  item.notes!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '€ ${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    // Extras se presenti
                    if (item.extras.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildExtrasGrouped(item.extras),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 32),

            // Totale
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
                  '€ ${order.total.toStringAsFixed(2)}',
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
                      size: 20,
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

            // Pulsante stampa
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _printOrder(context, order),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Stampa'),
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

  /// Stampa l'ordine
  Future<void> _printOrder(BuildContext context, Order order) async {
    final printerService = PrinterService();
    final restaurantName = await _getRestaurantName();
    if (!context.mounted) return;

    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final esito = await printerService.printOrder(order, restaurantName);

      if (context.mounted) {
        Navigator.pop(context); // Chiudi loading
        Navigator.pop(context); // Chiudi modal dettagli

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Sul fallimento si mostra il motivo, non un generico "errore":
            // il ristorante deve sapere se e' finita la carta.
            content: Text(
              esito.ok
                  ? 'Comanda #${order.id} stampata'
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
        Navigator.pop(context); // Chiudi loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Ottieni nome ristorante dalle preferences
  Future<String> _getRestaurantName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('restaurant_name') ?? 'Ristorante';
  }
}
