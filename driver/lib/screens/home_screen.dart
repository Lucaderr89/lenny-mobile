import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../models/driver_shift_info.dart';
import '../models/order.dart';
import '../services/driver_session_service.dart';
import '../services/driver_service.dart';
import '../services/driver_location_service.dart';
import '../services/geofence_tracking_service.dart';
import '../services/shift_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_store.dart';
import '../widgets/location_permission_dialog.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'notifications_screen.dart';
import 'delivery_history_screen.dart';
import 'panel_screen.dart';
import 'dart:async';

/// Home Screen per driver - Interfaccia principale turno
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DriverSessionService _sessionService = DriverSessionService();
  final DriverService _driverService = DriverService();
  final ShiftService _shiftService = ShiftService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _driverName = '';
  bool _isLoading = true;
  DriverShiftInfo? _shiftInfo;
  List<Order> _orders = [];
  Timer? _ordersRefreshTimer;
  final Map<int, String> _previousOrderStatuses = {};

  // Sistema reminder per ordini non confermati
  final Map<int, Timer?> _confirmationReminderTimers = {};
  final Set<int> _processedNewOrders = {}; // Per evitare suono duplicato
  final AudioPlayer _reminderPlayer = AudioPlayer();
  StreamSubscription? _fcmSubscription;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();

    // Permesso GPS richiesto UNA SOLA VOLTA (al primo login). Dopo, il tracking
    // controlla in silenzio se è già concesso: nessun popup ad ogni avvio.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureLocationPermissionOnce();
    });

    // Carica notifiche salvate e ascolta il badge
    NotificationStore().load().then((_) {
      if (mounted) {
        setState(() {
          _unreadNotifications = NotificationStore().unreadCount.value;
        });
      }
    });
    NotificationStore().unreadCount.addListener(_onUnreadChanged);

    // Ascolta push FCM in foreground per aggiornare ordini in tempo reale
    _fcmSubscription = FcmService().onForegroundMessage.listen((message) async {
      final event = message.data['event'] ?? '';
      if (event == 'new_assignment') {
        await _playOrderAssignedSound();
        await _loadOrders();
      } else if (event == 'assignment_cancelled') {
        await _loadOrders();
      }
    });
  }

  void _onUnreadChanged() {
    if (mounted) {
      setState(
        () => _unreadNotifications = NotificationStore().unreadCount.value,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationStore().unreadCount.removeListener(_onUnreadChanged);
    _ordersRefreshTimer?.cancel();
    _fcmSubscription?.cancel();
    // Cancella tutti i timer di reminder
    for (final timer in _confirmationReminderTimers.values) {
      timer?.cancel();
    }
    _confirmationReminderTimers.clear();
    _audioPlayer.dispose();
    _reminderPlayer.dispose();
    _sessionService.dispose();
    // Ferma il tracking GPS quando si lascia la home (es. logout).
    GeofenceTrackingService().shutdown();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ricarica dati quando l'app torna in primo piano
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  /// Chiede il permesso di localizzazione UNA SOLA VOLTA (al primo login).
  /// Una volta concesso a livello di sistema, non viene più richiesto — esattamente
  /// come Google Maps. Il tracking vero parte poi solo quando c'è un ordine attivo.
  Future<void> _ensureLocationPermissionOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AppConstants.keyLocationPermissionAsked) ?? false) {
      return; // già chiesto in passato
    }

    final locService = DriverLocationService();

    // Se è già concesso (es. reinstallazione con permesso residuo), segna e basta.
    final current = await locService.checkPermission();
    if (current == LocationPermission.always ||
        current == LocationPermission.whileInUse) {
      await prefs.setBool(AppConstants.keyLocationPermissionAsked, true);
      return;
    }

    if (!mounted) return;

    // Dialog esplicativo (una tantum), poi richiesta permesso di sistema.
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LocationPermissionDialog(
        onAccept: () => Navigator.of(ctx).pop(true),
        onDecline: () => Navigator.of(ctx).pop(false),
      ),
    );

    if (accept == true) {
      await locService.requestPermission();
    }

    // In ogni caso non riproporre il dialog ad ogni avvio: l'OS gestisce il resto.
    await prefs.setBool(AppConstants.keyLocationPermissionAsked, true);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Carica nome driver
      final prefs = await SharedPreferences.getInstance();
      _driverName = prefs.getString(AppConstants.keyDriverName) ?? 'Driver';

      // Carica info turno + stato availability dal server
      _shiftInfo = await _shiftService.getShiftToday();

      // Carica ordini assegnati (sempre, indipendentemente dallo stato)
      await _loadOrders();

      // Avvia refresh automatico ogni 30 secondi
      _startOrdersRefresh();
    } catch (e) {
      print('❌ Errore caricamento dati: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _driverService.getAssignedOrders();
      if (mounted) {
        // Controlla se ci sono ordini passati a picking_up
        for (final order in orders) {
          final previousStatus = _previousOrderStatuses[order.id];
          final currentStatus = order.status;

          // Se l'ordine è passato da assigned a picking_up, mostra il reminder
          if (previousStatus != null &&
              previousStatus != 'picking_up' &&
              currentStatus == 'picking_up') {
            _showPickupReminder(order);
          }

          // NUOVO: Rileva nuovi ordini assigned non confermati (food: 'assigned', partner: 'ready_for_pickup')
          if ((currentStatus == 'assigned' ||
                  currentStatus == 'ready_for_pickup') &&
              order.confirmedAt == null &&
              !_processedNewOrders.contains(order.id)) {
            // Suono iniziale per nuovo ordine
            _playOrderAssignedSound();
            // Avvia timer reminder
            _startConfirmationReminder(order.id);
            // Marca come processato
            _processedNewOrders.add(order.id);
          }

          // Ferma reminder se ordine confermato o non più in stato nuovo
          if (order.confirmedAt != null ||
              (currentStatus != 'assigned' &&
                  currentStatus != 'ready_for_pickup')) {
            _stopConfirmationReminder(order.id);
          }

          // Aggiorna lo stato precedente
          _previousOrderStatuses[order.id] = currentStatus;
        }

        setState(() => _orders = orders);

        // Tracking GPS legato alla presenza di ordini attivi (food o partner):
        // la lista contiene SOLO ordini attivi, quindi isNotEmpty = "ha un ordine".
        // Parte all'assegnazione, si ferma quando l'ultimo è consegnato.
        GeofenceTrackingService().sync(hasActiveOrders: orders.isNotEmpty);
      }
    } catch (e) {
      print('❌ Errore caricamento ordini: $e');
    }
  }

  void _startOrdersRefresh() {
    _ordersRefreshTimer?.cancel();
    _ordersRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) async {
      await _loadOrders();
      // Aggiorna anche lo stato availability (online/offline/busy)
      final updatedShift = await _shiftService.getShiftToday();
      if (mounted) {
        setState(() => _shiftInfo = updatedShift);
      }
    });
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card turno di oggi
            _buildShiftCard(),
            const SizedBox(height: 4),

            // Card ordini attivi (CUORE DELL'APP - Focus 100% sugli ordini)
            _buildActiveOrdersCard(),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.dashboard_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'Pannello',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PanelScreen()),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _handleLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text(
              'Esci',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante il logout')),
        );
      }
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: Row(
        children: [
          Image.asset('assets/images/logo_lenny.png', height: 28),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Ciao, $_driverName',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusBadge(),
        ],
      ),
      actions: [
        // Campanella notifiche con badge
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                // Aggiorna badge dopo essere tornati
                if (mounted) {
                  setState(
                    () => _unreadNotifications =
                        NotificationStore().unreadCount.value,
                  );
                }
              },
            ),
            if (_unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifications > 99
                          ? '99+'
                          : '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
          onPressed: () => _showProfileMenu(),
        ),
      ],
    );
  }

  /// Badge colorato ONLINE / OFFLINE / OCCUPATO nell'AppBar
  Widget _buildStatusBadge() {
    final status = _shiftInfo?.availabilityStatus ?? 'offline';
    Color bgColor;
    String label;
    switch (status) {
      case 'online':
        bgColor = const Color(0xFF10B981);
        label = 'ONLINE';
        break;
      case 'busy':
        bgColor = AppColors.warning;
        label = 'OCCUPATO';
        break;
      default:
        bgColor = Colors.white.withValues(alpha: 0.25);
        label = 'OFFLINE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Card turno di oggi con orari e stato
  Widget _buildShiftCard() {
    final info = _shiftInfo;

    // Nessun turno oggi e nessun turno futuro
    if (info == null) {
      return _buildInfoTile(
        icon: Icons.schedule_outlined,
        color: AppColors.gray,
        title: 'Nessun turno programmato',
        subtitle: 'Contatta il tuo responsabile per info.',
      );
    }

    final current = info.currentShift;
    if (current != null) {
      // Sei in turno adesso
      return _buildInfoTile(
        icon: Icons.check_circle_outline,
        color: const Color(0xFF10B981),
        title: 'Sei in turno fino alle ${current.oraFine}',
        subtitle: info.isActive
            ? 'Stai ricevendo ordini'
            : 'In attesa di sincronizzazione...',
      );
    }

    final upcoming = info.upcomingShiftToday;
    if (upcoming != null) {
      return _buildInfoTile(
        icon: Icons.access_time_rounded,
        color: AppColors.primary,
        title: 'Il tuo turno inizia alle ${upcoming.oraInizio}',
        subtitle: 'Diventerai online automaticamente',
      );
    }

    // Turni di oggi finiti, mostra eventuale prossimo turno futuro
    if (info.hasShiftToday) {
      final last = info.todayShifts.last;
      return _buildInfoTile(
        icon: Icons.done_all,
        color: AppColors.gray,
        title: 'Turno terminato alle ${last.oraFine}',
        subtitle: info.nextShift != null
            ? 'Prossimo turno: ${info.nextShift!.giorno} alle ${info.nextShift!.oraInizio}'
            : 'Nessun altro turno programmato',
      );
    }

    // Nessun turno oggi ma c'è un prossimo turno
    if (info.nextShift != null) {
      final ns = info.nextShift!;
      return _buildInfoTile(
        icon: Icons.calendar_today_outlined,
        color: AppColors.primary,
        title: 'Nessun turno oggi',
        subtitle: 'Prossimo turno: ${ns.giorno} alle ${ns.oraInizio}',
      );
    }

    return _buildInfoTile(
      icon: Icons.schedule_outlined,
      color: AppColors.gray,
      title: 'Nessun turno programmato',
      subtitle: 'Contatta il tuo responsabile per info.',
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.gray.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // Icona storico consegne — sempre visibile
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeliveryHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded),
            color: AppColors.gray,
            iconSize: 24,
            tooltip: 'Storico consegne',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersCard() {
    final isActive = _shiftInfo?.isActive ?? false;

    // Se non è in turno attivo e non ha ordini, mostra messaggio appropriato
    if (!isActive && _orders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Nessun ordine assegnato',
        subtitle: 'Gli ordini appariranno qui quando sarai in turno',
      );
    }

    // Se online ma nessun ordine
    if (_orders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Nessun ordine assegnato',
        subtitle: 'Gli ordini appariranno qui automaticamente',
      );
    }

    // Mostra lista ordini
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con conteggio
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_orders.length} ${_orders.length == 1 ? 'Ordine' : 'Ordini'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: _loadOrders,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Lista ordini/batch
        ..._buildOrdersOrBatches(),
      ],
    );
  }

  /// Un giro multi-ristorante = ordini che condividono lo stesso route_plan con
  /// almeno 2 punti di ritiro distinti (i ritiri/consegne si alternano tra ristoranti
  /// diversi). I batch dallo STESSO ristorante restano gestiti da _buildBatchCard.
  bool _isMultiRestaurantRoute(List<RouteStop> steps) {
    final pickups = steps
        .where((s) => s.isPickup)
        .map((s) => '${s.lat.toStringAsFixed(5)},${s.lng.toStringAsFixed(5)}')
        .toSet();
    return pickups.length >= 2;
  }

  List<Widget> _buildOrdersOrBatches() {
    final widgets = <Widget>[];
    final processedOrderIds = <int>{};

    // ── 1) GIRI multi-ristorante (route_plan condiviso, ≥2 ritiri) ──────────────
    final giroGroups = <String, List<Order>>{};
    for (final o in _orders) {
      if (o.routePlanRaw != null && _isMultiRestaurantRoute(o.routeSteps)) {
        giroGroups.putIfAbsent(o.routePlanRaw!, () => []).add(o);
      }
    }
    for (final giroOrders in giroGroups.values) {
      // Ordina nell'ordine del giro (sequenza di consegna)
      giroOrders.sort(
        (a, b) =>
            (a.deliverySequence ?? 9999).compareTo(b.deliverySequence ?? 9999),
      );
      final allConfirmed = giroOrders.every((o) => o.confirmedAt != null);
      if (allConfirmed) {
        // FASE 2: card unica del giro ottimizzato
        widgets.add(_buildGiroCard(giroOrders));
      } else {
        // FASE 1: il driver conferma ancora la ricezione di ogni ordine →
        // card singole, nell'ordine del giro
        for (final o in giroOrders) {
          widgets.add(_buildOrderCard(o));
        }
      }
      for (final o in giroOrders) {
        processedOrderIds.add(o.id);
      }
    }

    // ── 2) Resto: batch stesso ristorante e ordini singoli (come prima) ─────────
    final processedBatches = <String>{};
    for (final order in _orders) {
      if (processedOrderIds.contains(order.id)) continue;
      if (processedBatches.contains(order.batchId)) continue;

      // Trova tutti gli ordini della stessa batch, ordinati nearest-first dal ristorante
      final batchOrders =
          _orders
              .where(
                (o) =>
                    o.batchId == order.batchId &&
                    !processedOrderIds.contains(o.id),
              )
              .toList()
            ..sort((a, b) {
              final restLat = a.restaurantLat;
              final restLng = a.restaurantLng;
              final dA =
                  (a.deliveryLat - restLat) * (a.deliveryLat - restLat) +
                  (a.deliveryLng - restLng) * (a.deliveryLng - restLng);
              final dB =
                  (b.deliveryLat - restLat) * (b.deliveryLat - restLat) +
                  (b.deliveryLng - restLng) * (b.deliveryLng - restLng);
              return dA.compareTo(dB);
            });

      if (batchOrders.length > 1) {
        // BATCH: mostra card unica con più consegne
        widgets.add(_buildBatchCard(batchOrders));
      } else {
        // Ordine singolo
        widgets.add(_buildOrderCard(order));
      }

      processedBatches.add(order.batchId);
    }

    return widgets;
  }

  /// FASE 2 — Card del giro ottimizzato (multi-ritiro da ristoranti diversi).
  /// Mostra le tappe ritiro/consegna nell'ordine suggerito dal backend; lo stato di
  /// ogni tappa è DEDOTTO dallo stato (geofencing) del relativo ordine, senza una
  /// macchina a stati propria. Tap su una tappa → dettaglio ordine (prodotti). La
  /// conferma consegna avviene qui, un ordine alla volta (quello in consegna).
  Widget _buildGiroCard(List<Order> giroOrders) {
    final steps = giroOrders.first.routeSteps;
    final orderById = {for (final o in giroOrders) o.id: o};
    final slot = giroOrders.first.timeSlot;
    final total = giroOrders.fold<double>(0, (s, o) => s + o.total);

    bool stepDone(RouteStop st) {
      final o = orderById[st.orderId];
      if (o == null) return true; // ordine non più tra gli attivi → consegnato
      if (st.isPickup) {
        return o.pickedUpAt != null || o.isInDelivery || o.status == 'delivered';
      }
      return o.status == 'delivered';
    }

    bool stepInProgress(RouteStop st) {
      final o = orderById[st.orderId];
      if (o == null) return false;
      return st.isPickup ? o.isPickingUp : o.isInDelivery;
    }

    final doneCount = steps.where(stepDone).length;

    // Prossimo ordine da consegnare ORA (in consegna) → pulsante CONFERMA CONSEGNA
    Order? deliverable;
    for (final st in steps) {
      if (st.isDelivery && !stepDone(st)) {
        final o = orderById[st.orderId];
        if (o != null && o.isInDelivery) {
          deliverable = o;
          break;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: SLOT in evidenza + progresso tappe + totale
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  slot,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$doneCount/${steps.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '€${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
          ),

          // Tappe del giro
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                ...steps.asMap().entries.map((entry) {
                  final i = entry.key;
                  final st = entry.value;
                  return _buildGiroStepRow(
                    i,
                    st,
                    orderById[st.orderId],
                    stepDone(st),
                    stepInProgress(st),
                  );
                }),
                if (deliverable != null) ...[
                  const SizedBox(height: 6),
                  _buildGiroDeliverButton(deliverable),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Una riga-tappa della card giro.
  Widget _buildGiroStepRow(
    int i,
    RouteStop st,
    Order? o,
    bool done,
    bool inProg,
  ) {
    final isPickup = st.isPickup;
    final String title = isPickup
        ? (o?.restaurantName ?? 'Ritiro #${st.orderId}')
        : (o?.customerName ?? 'Consegna #${st.orderId}');
    final String subtitle = isPickup
        ? (o?.restaurantAddress ?? '')
        : (o?.deliveryAddress ?? '');

    // Indicatore di stato: cerchio numerato (verde+spunta se fatto, pieno se in corso)
    final Widget indicator = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: done
            ? AppColors.success
            : (inProg
                  ? AppColors.primary
                  : AppColors.lightGray.withValues(alpha: 0.5)),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: inProg ? Colors.white : AppColors.gray,
                ),
              ),
      ),
    );

    return InkWell(
      onTap: o != null ? () => _showOrderDetailsModal(o) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: inProg
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            indicator,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        isPickup ? Icons.restaurant : Icons.location_on,
                        size: 13,
                        color: isPickup ? AppColors.primary : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPickup ? 'RITIRO' : 'CONSEGNA',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gray,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#${st.orderId}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray,
                        ),
                      ),
                      if (inProg) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPickup ? 'IN RITIRO' : 'IN CONSEGNA',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: done ? AppColors.gray : AppColors.dark,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.gray.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (o != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isPickup || o.restaurantPhone != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.phone,
                        size: 19,
                        color: isPickup
                            ? AppColors.primary
                            : AppColors.success,
                      ),
                      onPressed: () => _makePhoneCall(
                        isPickup ? o.restaurantPhone! : o.customerPhone,
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.navigation,
                      size: 19,
                      color: isPickup ? AppColors.primary : AppColors.success,
                    ),
                    onPressed: () => _openMaps(
                      isPickup ? o.restaurantLat : o.deliveryLat,
                      isPickup ? o.restaurantLng : o.deliveryLng,
                      title,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Pulsante CONFERMA CONSEGNA per l'ordine attualmente in consegna nel giro
  /// (riusa il flusso esistente con scelta metodo di pagamento).
  Widget _buildGiroDeliverButton(Order order) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _confirmOrderDelivered(order),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all, size: 20),
            const SizedBox(width: 8),
            Text(
              'CONFERMA CONSEGNA #${order.id}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, AppColors.lightGray.withValues(alpha: 0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.lightGray.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.gray.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    if (order.isPartnerOrder) return _buildPartnerOrderCard(order);
    return InkWell(
      onTap: () => _showOrderDetailsModal(order),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: order.confirmedAt == null
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.primary.withValues(alpha: 0.3),
            width: order.confirmedAt == null ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con badge stato e time slot
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: order.confirmedAt == null
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  if (order.confirmedAt == null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '🔔 NUOVO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (order.status == 'assigned' &&
                      order.confirmedAt != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '✓ ASSEGNATO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (order.isPickingUp) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '📦 IN RITIRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (order.isInDelivery) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '🚚 IN CONSEGNA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // ID Ordine
                  Text(
                    '#${order.id}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: order.confirmedAt == null
                        ? AppColors.warning
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.timeSlot,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: order.confirmedAt == null
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                  const Spacer(),
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
            ),

            // Body con dettagli
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ristorante
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RITIRO DA',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.restaurantName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                            ),
                            Text(
                              order.restaurantAddress,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (order.restaurantPhone != null)
                            IconButton(
                              icon: const Icon(
                                Icons.phone,
                                color: AppColors.primary,
                              ),
                              onPressed: () =>
                                  _makePhoneCall(order.restaurantPhone!),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.navigation,
                              color: AppColors.primary,
                            ),
                            onPressed: () => _openMaps(
                              order.restaurantLat,
                              order.restaurantLng,
                              order.restaurantName,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 14),

                  // Cliente
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.success,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONSEGNA A',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.customerName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                            ),
                            Text(
                              order.deliveryAddress,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.phone,
                              color: AppColors.success,
                            ),
                            onPressed: () =>
                                _makePhoneCall(order.customerPhone),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.navigation,
                              color: AppColors.success,
                            ),
                            onPressed: () => _openMaps(
                              order.deliveryLat,
                              order.deliveryLng,
                              order.customerName,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (order.deliveryNotes != null &&
                      order.deliveryNotes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.note,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.deliveryNotes!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.dark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Azioni
                  if (order.confirmedAt == null)
                    // Non ancora confermato → mostra pulsante CONFERMA RICEZIONE
                    _buildConfirmButton(order)
                  else if (order.isInDelivery)
                    // In delivery → mostra pulsante CONFERMA CONSEGNA
                    _buildDeliverButton(order),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card differenziata per ordini partner (supermercato, negozio, ecc.)
  Widget _buildPartnerOrderCard(Order order) {
    // Palette colore in base al tipo partner
    final Color accentColor = order.isSupermarket
        ? const Color(0xFF16A34A) // verde supermercato
        : order.isShop
        ? AppColors
              .secondary // teal negozio
        : AppColors.warning; // arancio altri partner

    final String badgeLabel = order.isSupermarket
        ? '🛒 SPESA'
        : order.isShop
        ? '🏪 NEGOZIO'
        : '📦 PARTNER';

    final String pickupLabel = order.isSupermarket
        ? 'RITIRO DALLA SPESA'
        : 'RITIRO DAL NEGOZIO';

    final IconData pickupIcon = order.isSupermarket
        ? Icons.shopping_cart
        : Icons.storefront;

    final Color headerBg = order.confirmedAt == null
        ? AppColors.warning.withValues(alpha: 0.08)
        : accentColor.withValues(alpha: 0.06);

    final Color borderColor = order.confirmedAt == null
        ? AppColors.warning.withValues(alpha: 0.55)
        : accentColor.withValues(alpha: 0.4);

    return InkWell(
      onTap: () => _showOrderDetailsModal(order),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: order.confirmedAt == null ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  // Badge tipo partner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Badge stato ordine (NUOVO / PRONTO / IN RITIRO / ecc.)
                  if (order.confirmedAt == null && !order.isReadyForPickup) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '🔔 NUOVO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (order.isReadyForPickup) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '✅ PRONTO AL RITIRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (order.isPickingUp) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '📦 IN RITIRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (order.isInDelivery) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '🚚 IN CONSEGNA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '✓ ASSEGNATO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  Text(
                    '#${order.id}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray,
                    ),
                  ),
                  const Spacer(),
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
            ),

            // ── Slot orario in evidenza ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.09),
                border: Border(left: BorderSide(color: accentColor, width: 4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'Slot consegna: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    order.timeSlot,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Punto di ritiro
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(pickupIcon, color: accentColor, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickupLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.gray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.restaurantName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                            ),
                            Text(
                              order.restaurantAddress,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (order.restaurantPhone != null)
                            IconButton(
                              icon: Icon(Icons.phone, color: accentColor),
                              onPressed: () =>
                                  _makePhoneCall(order.restaurantPhone!),
                            ),
                          IconButton(
                            icon: Icon(Icons.navigation, color: accentColor),
                            onPressed: () => _openMaps(
                              order.restaurantLat,
                              order.restaurantLng,
                              order.restaurantName,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 14),

                  // Cliente
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.success,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONSEGNA A',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.customerName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                            ),
                            Text(
                              order.deliveryAddress,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.phone,
                              color: AppColors.success,
                            ),
                            onPressed: () =>
                                _makePhoneCall(order.customerPhone),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.navigation,
                              color: AppColors.success,
                            ),
                            onPressed: () => _openMaps(
                              order.deliveryLat,
                              order.deliveryLng,
                              order.customerName,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (order.deliveryNotes != null &&
                      order.deliveryNotes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.note,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.deliveryNotes!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.dark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Azioni — identico al food:
                  //   !confirmed      → CONFERMA RICEZIONE (flag ufficio)
                  //   GPS ≤50m        → auto picking_up  (geofencing backend)
                  //   GPS >50m 120s   → auto in_delivery (geofencing backend)
                  //   in_delivery     → CONFERMA CONSEGNA
                  if (order.isInDelivery)
                    _buildDeliverButton(order)
                  else if (order.confirmedAt == null)
                    _buildConfirmButton(order),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(List<Order> batchOrders) {
    final firstOrder = batchOrders.first;
    final allConfirmed = batchOrders.every((o) => o.confirmedAt != null);
    final anyInDelivery = batchOrders.any((o) => o.isInDelivery);
    final anyPickingUp = batchOrders.any((o) => o.isPickingUp);
    final totalAmount = batchOrders.fold<double>(0, (sum, o) => sum + o.total);
    final orderIds = batchOrders.map((o) => '#${o.id}').join(', ');

    return InkWell(
      onTap: () => _showBatchDetailsModal(batchOrders),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !allConfirmed
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.primary.withValues(alpha: 0.3),
            width: !allConfirmed ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !allConfirmed
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  if (!allConfirmed) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '🔔 NUOVO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (anyPickingUp) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '📦 IN RITIRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (anyInDelivery) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '🚚 IN CONSEGNA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '✓ ASSEGNATO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // IDs Ordini
                  Flexible(
                    child: Text(
                      orderIds,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gray,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: !allConfirmed
                        ? AppColors.warning
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    firstOrder.timeSlot,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: !allConfirmed
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '€${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ristorante
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RITIRO DA',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              firstOrder.restaurantName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                            ),
                            Text(
                              firstOrder.restaurantAddress,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gray.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (firstOrder.restaurantPhone != null)
                            IconButton(
                              icon: const Icon(
                                Icons.phone,
                                color: AppColors.primary,
                              ),
                              onPressed: () =>
                                  _makePhoneCall(firstOrder.restaurantPhone!),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.navigation,
                              color: AppColors.primary,
                            ),
                            onPressed: () => _openMaps(
                              firstOrder.restaurantLat,
                              firstOrder.restaurantLng,
                              firstOrder.restaurantName,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 14),

                  // Consegne multiple
                  const Text(
                    'CONSEGNA A',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.gray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...batchOrders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final order = entry.value;
                    return Container(
                      margin: EdgeInsets.only(
                        bottom: index < batchOrders.length - 1 ? 8 : 0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}°',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.dark,
                                  ),
                                ),
                                Text(
                                  order.deliveryAddress,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gray.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.phone,
                                  color: AppColors.success,
                                ),
                                onPressed: () =>
                                    _makePhoneCall(order.customerPhone),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.navigation,
                                  color: AppColors.success,
                                ),
                                onPressed: () => _openMaps(
                                  order.deliveryLat,
                                  order.deliveryLng,
                                  order.customerName,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Azioni
                  if (!allConfirmed) _buildConfirmButton(firstOrder),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(Order order) {
    // Controlla se c'è un timer attivo per questo ordine (significa che sta aspettando conferma)
    final hasActiveReminder = _confirmationReminderTimers.containsKey(order.id);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: hasActiveReminder ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        // Scala pulsante (effetto pulsante)
        final scale = hasActiveReminder ? 1.0 + (value * 0.05) : 1.0;
        // Opacità glow
        final glowOpacity = hasActiveReminder ? (value * 0.4) : 0.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: hasActiveReminder
                  ? [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: glowOpacity),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ]
                  : null,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmOrderReceived(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: hasActiveReminder ? 4 : 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: hasActiveReminder
                          ? Colors.white.withValues(alpha: 0.9 + (value * 0.1))
                          : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CONFERMA RICEZIONE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: hasActiveReminder
                            ? Colors.white.withValues(
                                alpha: 0.9 + (value * 0.1),
                              )
                            : Colors.white,
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

  Widget _buildDeliverButton(Order order) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _confirmOrderDelivered(order),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.done_all, size: 20),
            SizedBox(width: 8),
            Text(
              'CONFERMA CONSEGNA',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetailsModal(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
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
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header con ID e costo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ordine #${order.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '€${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Consegna prevista
              _buildDeliveryTimeSection(order),
              const SizedBox(height: 12),

              // Ristorante e Cliente a due colonne
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ristorante
                  Expanded(
                    child: _buildCompactLocationCard(
                      order.restaurantName,
                      order.restaurantAddress,
                      Icons.restaurant,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cliente
                  Expanded(
                    child: _buildCompactLocationCard(
                      order.customerName,
                      '${order.deliveryAddress}\nTel: ${order.customerPhone}',
                      Icons.location_on,
                      AppColors.success,
                    ),
                  ),
                ],
              ),

              // Note
              if (order.deliveryNotes != null &&
                  order.deliveryNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.note, color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'NOTE CONSEGNA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.deliveryNotes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Metodo di pagamento
              if (order.paymentMethodDescription != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getPaymentIcon(order.paymentMethod),
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PAGAMENTO: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        order.paymentMethodDescription!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Prodotti ordinati
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.shopping_basket,
                          color: AppColors.dark,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'PRODOTTI ORDINATI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (order.products.isEmpty)
                      const Text(
                        'Nessun prodotto in quest\'ordine',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.gray,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      ...order.products.map(
                        (product) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${product.quantity}x',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.dark,
                                  ),
                                ),
                              ),
                              Text(
                                '€${product.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.dark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String? paymentMethod) {
    if (paymentMethod == null) return Icons.payment;
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
      case 'contanti':
        return Icons.money;
      case 'card':
      case 'carta':
        return Icons.credit_card;
      case 'online':
      case 'paypal':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  Widget _buildDeliveryTimeSection(Order order) {
    String deliveryDate = '';
    try {
      final dt = DateTime.parse(order.dateOrder);
      deliveryDate = '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      deliveryDate = order.dateOrder;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$deliveryDate - ${order.timeSlot}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLocationCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.gray.withValues(alpha: 0.8),
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showBatchDetailsModal(List<Order> batchOrders) {
    final firstOrder = batchOrders.first;
    final totalAmount = batchOrders.fold<double>(0, (sum, o) => sum + o.total);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Text(
                'Batch: ${batchOrders.length} ordini',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Slot: ${firstOrder.timeSlot} • Totale: €${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.gray.withValues(alpha: 0.8),
                ),
              ),
              const Divider(height: 32),

              // Ristorante
              _buildModalSection(
                'RITIRO DA',
                firstOrder.restaurantName,
                firstOrder.restaurantAddress,
                Icons.restaurant,
                AppColors.primary,
                () => _openMaps(
                  firstOrder.restaurantLat,
                  firstOrder.restaurantLng,
                  firstOrder.restaurantName,
                ),
              ),
              const SizedBox(height: 20),

              // Consegne
              const Text(
                'CONSEGNE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              ...batchOrders.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index < batchOrders.length - 1 ? 12 : 0,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}°',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.dark,
                                  ),
                                ),
                                Text(
                                  order.customerPhone,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.gray.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.navigation,
                              color: AppColors.success,
                            ),
                            onPressed: () => _openMaps(
                              order.deliveryLat,
                              order.deliveryLng,
                              order.customerName,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.deliveryAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.gray.withValues(alpha: 0.8),
                        ),
                      ),
                      if (order.deliveryNotes != null &&
                          order.deliveryNotes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.note,
                                color: AppColors.warning,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.deliveryNotes!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '€${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalSection(
    String label,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onNavigate,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.navigation),
                iconSize: 20,
                color: color,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onNavigate,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.gray.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmOrderReceived(Order order) async {
    try {
      // Ferma il timer di reminder
      _stopConfirmationReminder(order.id);

      await _driverService.confirmOrderReceived(
        order.id,
        orderSource: order.orderSource,
      );
      _showToast('Ordine confermato! ✅', isError: false);
      await _loadOrders();
    } catch (e) {
      _showToast('Errore: $e', isError: true);
    }
  }

  Future<void> _confirmOrderDelivered(Order order) async {
    // Se il pagamento è offline (contanti, pos, smac), mostra dialog conferma
    if (order.paymentMethodId >= 1 && order.paymentMethodId <= 3) {
      await _showPaymentConfirmationDialog(order);
    } else {
      // Pagamento online (stripe), conferma direttamente
      await _confirmOrderDeliveredWithPayment(order, null);
    }
  }

  Future<void> _confirmOrderDeliveredWithPayment(
    Order order,
    int? paymentMethodId,
  ) async {
    try {
      await _driverService.confirmOrderDelivered(
        order.id,
        paymentMethodId: paymentMethodId,
        orderSource: order.orderSource,
      );
      _showToast('Consegna confermata! 🎉', isError: false);
      await _loadOrders();
    } catch (e) {
      _showToast('Errore: $e', isError: true);
    }
  }

  Future<void> _openMaps(double lat, double lng, String label) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('Impossibile aprire Google Maps', isError: true);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showToast('Impossibile effettuare la chiamata', isError: true);
    }
  }

  /// Riproduce un suono forte di alert quando compare il reminder di pickup
  Future<void> _playAlertSound() async {
    try {
      // Imposta volume al massimo per questo suono
      await _audioPlayer.setVolume(1.0);

      // Usa il suono custom dal file locale
      await _audioPlayer.play(
        AssetSource('sounds/pickup_alert.mp3'),
        volume: 1.0,
      );

      print('🔊 Suono alert riprodotto');
    } catch (e) {
      print('❌ Errore riproduzione suono: $e');
      // Non bloccare il dialog se il suono fallisce
    }
  }

  /// Riproduce suono quando un nuovo ordine viene assegnato
  Future<void> _playOrderAssignedSound() async {
    try {
      await _reminderPlayer.stop(); // Ferma eventuali suoni precedenti
      await _reminderPlayer.setVolume(1.0);
      await _reminderPlayer.play(
        AssetSource('sounds/order_assigned.mp3'),
        volume: 1.0,
      );
      print('🔔 Suono nuovo ordine assegnato riprodotto');
    } catch (e) {
      print('❌ Errore riproduzione suono order_assigned: $e');
    }
  }

  /// Riproduce suono di reminder se ordine non confermato
  Future<void> _playConfirmReminderSound() async {
    try {
      await _reminderPlayer.stop();
      await _reminderPlayer.setVolume(1.0);
      await _reminderPlayer.play(
        AssetSource('sounds/confirm_reminder.mp3'),
        volume: 1.0,
      );
      print('⏰ Suono reminder conferma riprodotto');
    } catch (e) {
      print('❌ Errore riproduzione suono confirm_reminder: $e');
    }
  }

  /// Avvia timer per reminder ogni 30 secondi
  void _startConfirmationReminder(int orderId) {
    // Cancella timer esistente se presente
    _stopConfirmationReminder(orderId);

    // Crea nuovo timer che suona ogni 30 secondi
    _confirmationReminderTimers[orderId] = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        // Verifica se l'ordine esiste ancora e non è confermato
        final order = _orders.firstWhere(
          (o) => o.id == orderId,
          orElse: () => Order(
            id: -1,
            dateOrder: '',
            timeSlotId: 0,
            restaurantId: 0,
            restaurantName: '',
            restaurantAddress: '',
            restaurantLat: 0.0,
            restaurantLng: 0.0,
            customerName: '',
            customerPhone: '',
            deliveryAddress: '',
            deliveryLat: 0.0,
            deliveryLng: 0.0,
            total: 0.0,
            status: '',
            assignedAt: '',
            timeSlot: '',
            batchId: '',
            paymentMethodId: 1,
            products: [],
          ),
        );

        if (order.id != -1 && order.confirmedAt == null) {
          _playConfirmReminderSound();
          if (mounted) setState(() {}); // Trigger rebuild per animazione
        } else {
          // Ordine non esiste più o confermato, ferma timer
          _stopConfirmationReminder(orderId);
        }
      },
    );

    print('⏰ Timer reminder avviato per ordine #$orderId');
  }

  /// Ferma il timer di reminder per un ordine
  void _stopConfirmationReminder(int orderId) {
    _confirmationReminderTimers[orderId]?.cancel();
    _confirmationReminderTimers.remove(orderId);
    _processedNewOrders.remove(orderId);
    print('🛑 Timer reminder fermato per ordine #$orderId');
  }

  void _showPickupReminder(Order order) async {
    // RIPRODUCE SUONO DI ALERT
    await _playAlertSound();

    // Verifica se ci sono bevande nell'ordine
    final hasBeverages = order.products.any((product) {
      final name = product.name.toLowerCase();
      return name.contains('acqua') ||
          name.contains('bevanda') ||
          name.contains('coca') ||
          name.contains('birra') ||
          name.contains('vino') ||
          name.contains('succo') ||
          name.contains('the') ||
          name.contains('caffè') ||
          name.contains('drink');
    });

    showDialog(
      context: context,
      barrierDismissible: false, // Non può essere chiuso toccando fuori
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'RICORDA!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Controlla di aver ritirato tutto:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 12),
            if (hasBeverages) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_drink,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'NON DIMENTICARE LE BEVANDE!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              '✓ Controlla tutti i prodotti\n✓ Verifica le quantità\n✓ Controlla accessori e posate',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'OK, CONTROLLO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentConfirmationDialog(Order order) async {
    int selectedPaymentMethod = order.paymentMethodId;

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.payment,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Come ha pagato?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conferma il metodo di pagamento utilizzato dal cliente:',
                style: TextStyle(fontSize: 14, color: AppColors.gray),
              ),
              const SizedBox(height: 16),
              _buildPaymentMethodOption(
                context,
                1,
                'Contanti',
                Icons.money,
                selectedPaymentMethod == 1,
                () => setState(() => selectedPaymentMethod = 1),
              ),
              const SizedBox(height: 8),
              _buildPaymentMethodOption(
                context,
                2,
                'Bancomat/POS',
                Icons.credit_card,
                selectedPaymentMethod == 2,
                () => setState(() => selectedPaymentMethod = 2),
              ),
              const SizedBox(height: 8),
              _buildPaymentMethodOption(
                context,
                3,
                'SMAC',
                Icons.mobile_friendly,
                selectedPaymentMethod == 3,
                () => setState(() => selectedPaymentMethod = 3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'ANNULLA',
                style: TextStyle(color: AppColors.gray),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedPaymentMethod),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'CONFERMA CONSEGNA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _confirmOrderDeliveredWithPayment(order, result);
    }
  }

  Widget _buildPaymentMethodOption(
    BuildContext context,
    int methodId,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.lightGray.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.gray.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.gray,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.dark,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
