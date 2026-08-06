import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import '../models/restaurant.dart';
import '../models/cart_item.dart';
import '../models/delivery_data.dart';
import '../models/address_model.dart';
import '../services/order_service.dart';
import '../services/availability_service.dart';
import '../services/delivery_fee_service.dart';
import '../services/nominatim_service.dart';
import '../services/wallet_service.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/order_type_dialog.dart';
import '../widgets/address_selector_bottom_sheet.dart';
import 'nexi_build_payment_screen.dart';
import 'restaurant_menu_screen.dart';
import 'order_completed_screen.dart';
import '../widgets/app_icon.dart';

/// Checkout Screen - Basato sul prototipo 9-checkout.html
class CheckoutScreen extends StatefulWidget {
  final Restaurant restaurant;
  final List<CartItem> cartItems;
  final double subtotal;

  const CheckoutScreen({
    super.key,
    required this.restaurant,
    required this.cartItems,
    required this.subtotal,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Colori identici al prototipo
  static const Color primaryColor = AppColors.primary;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color successColor = AppColors.success;
  static const Color darkColor = AppColors.dark;
  static const Color grayColor = AppColors.gray;
  static const Color lightGrayColor = AppColors.lightGray;
  // Usato per le fasce non ordinabili (bloccate dal pannello o al completo)
  static const Color dangerColor = AppColors.danger;

  // Colori badge tipo ordine (stessi della home)
  static const Color badgeDeliveryColor = AppColors.primary; // Rosso consegna
  static const Color badgePickupColor = AppColors.accent; // Giallo ritiro

  // Dati caricati dall'API
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _availableSlots = [];
  // Toggle per mostrare/nascondere indirizzi
  bool _isLoading = true;
  int? _customerId;

  // Opzioni di consegna
  String _deliveryType = 'delivery'; // 'delivery' o 'pickup'

  // Delivery mode: 'current_position', 'saved_address', 'quick_save'
  String _deliveryMode = 'current_position';
  AddressModel? _selectedSavedAddress;
  final bool _shouldSaveAddress = false; // Quick save checkbox

  // Metodo di pagamento
  String? _selectedPaymentId;
  bool _hasSavedCard = false;
  List<Map<String, dynamic>> _savedCards = []; // Array di carte salvate
  String? _selectedCardAlias; // Carta selezionata per OneClick
  bool _useOneClick = false; // Flag per usare OneClick

  // Ordine pending da aggiornare (se pagamento fallisce)
  int? _pendingOrderId;

  // Data e ora selezionate
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedTimeSlotLabel; // Es: "14:00 - 14:15"

  // Coupon
  final TextEditingController _couponController = TextEditingController();
  bool _couponApplied = false;
  double _couponDiscount = 0.0;
  bool _couponLoading = false;

  // Coupon suggeriti dal server: solo quelli che QUESTO cliente puo' ancora
  // usare (i gia' usati/esauriti non arrivano proprio). Mai hardcodarli qui.
  List<Map<String, dynamic>> _suggestedCoupons = [];

  // Note ordine (uniche, finiscono nella stampa comanda)
  final TextEditingController _instructionsController = TextEditingController();

  // Guardia anti doppio-invio: true mentre un ordine e' in creazione.
  // Senza, un doppio tap su CONFERMA durante le verifiche crea ordini duplicati.
  bool _isPlacingOrder = false;

  // Crediti Lenny (sistema wallet)
  bool _useAppCredits = false;
  double _availableCredits = 0.0;

  // Punti fedelta': regola di accumulo dal server per mostrare
  // "con quest'ordine guadagni N punti" nel riepilogo. 0 = non caricata
  // (ospite o errore) e la riga non compare.
  double _pointsPerEuro = 0.0;
  double _pointsMultiplier = 1.0;

  // Costi - valori caricati dinamicamente dal backend
  double _serviceFeePercent = 3.5; // Default, verrà sovrascritto

  // 🆕 Delivery fee dinamico basato su delivery_zone_roles
  DeliveryFeeResult? _deliveryFeeResult;

  @override
  void initState() {
    super.initState();
    // Inizializza tipo ordine dal LocationProvider
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    _deliveryType = locationProvider.orderType; // 'delivery' o 'pickup'
    _loadCheckoutData();
  }

  Future<void> _loadCheckoutData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _customerId = prefs.getInt(AppConstants.keyUserId);

      if (_customerId == null) {
        _showToast('Errore: utente non autenticato');
        return;
      }

      final orderService = OrderService();

      // 🆕 CARICA CONFIGURAZIONI CHECKOUT DAL BACKEND
      await _loadCheckoutConfig();

      // Carica indirizzi salvati del cliente

      // Carica metodi di pagamento dall'API
      _paymentMethods = await orderService.getPaymentMethods();

      // NON selezionare ancora - aspetta _checkSavedCard
      // Se ha carte salvate → seleziona carta
      // Se NON ha carte salvate → seleziona contanti

      // 🆕 CONTROLLA SE IL CLIENTE HA UNA CARTA SALVATA (OneClick)
      await _checkSavedCard();

      // 🆕 CARICA CREDITI DISPONIBILI
      await _loadAvailableCredits();

      // Coupon suggeriti (personalizzati per cliente)
      await _loadSuggestedCoupons();

      // Regola punti fedelta' (non bloccante)
      await _loadLoyaltyEarnRate();

      // 🔑 DEFAULT: Se NON ha carte salvate, seleziona "contanti" (cash)
      if (!_hasSavedCard && _paymentMethods.isNotEmpty) {
        final cashMethod = _paymentMethods.firstWhere(
          (m) => m['slug'] == 'cash',
          orElse: () => _paymentMethods[0],
        );
        _selectedPaymentId = cashMethod['id'].toString();
        print(
          '💵 [CHECKOUT] Contanti selezionato di default (no carte salvate)',
        );
      }

      // Default: usa posizione corrente (no indirizzo salvato necessario)
      _deliveryMode = 'current_position';

      // 🆕 CARICA COSTO CONSEGNA DINAMICO (dopo aver caricato indirizzi)
      await _loadDeliveryFee();
    } catch (e) {
      print('Errore caricamento dati checkout: $e');
      _showToast('Errore nel caricamento dei dati');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Carica configurazioni checkout dal backend (service fee)
  Future<void> _loadCheckoutConfig() async {
    try {
      print('🔄 [CHECKOUT] Chiamata API config...');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/config/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Token': token ?? '',
        },
      );

      print('📡 [CHECKOUT] Response status: ${response.statusCode}');
      print('📡 [CHECKOUT] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final newValue = (data['data']['service_fee_percent'] ?? 3.5)
              .toDouble();
          print('✅ [CHECKOUT] Service fee ricevuto dal server: $newValue%');
          setState(() {
            _serviceFeePercent = newValue;
          });
          print('✅ [CHECKOUT] Service fee impostato a: $_serviceFeePercent%');
        } else {
          print('⚠️ [CHECKOUT] Risposta non valida: $data');
        }
      } else {
        print('⚠️ [CHECKOUT] Errore HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [CHECKOUT] Errore caricamento config: $e');
      // Usa valore di default in caso di errore
    }
  }

  /// Regola di accumulo punti fedelta' del cliente (per_euro e
  /// moltiplicatore tier): serve solo alla riga informativa nel riepilogo.
  /// Errore o ospite = riga assente, nessun blocco del checkout.
  Future<void> _loadLoyaltyEarnRate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/customer/loyalty'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) {
            setState(() {
              _pointsPerEuro =
                  (data['data']['points_per_euro'] as num?)?.toDouble() ?? 0.0;
              _pointsMultiplier =
                  (data['data']['points_multiplier'] as num?)?.toDouble() ??
                  1.0;
            });
          }
        }
      }
    } catch (e) {
      print('⚠️ [CHECKOUT] Regola punti non disponibile: $e');
    }
  }

  /// Punti che questo ordine fara' guadagnare (stessa formula del server:
  /// floor(subtotale * per_euro) * moltiplicatore tier)
  int get _earnedPoints {
    if (_pointsPerEuro <= 0) return 0;
    return ((_currentSubtotal * _pointsPerEuro).floor() * _pointsMultiplier)
        .toInt();
  }

  /// Carica dal server i coupon suggeribili a questo cliente.
  /// Errore di rete = lista vuota: la sezione suggeriti semplicemente
  /// non compare, il campo manuale resta comunque utilizzabile.
  Future<void> _loadSuggestedCoupons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/customer/coupons/suggested'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Token': token ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          if (mounted) {
            setState(() {
              _suggestedCoupons = (data['data'] as List)
                  .whereType<Map>()
                  .map((c) => Map<String, dynamic>.from(c))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      print('⚠️ [CHECKOUT] Coupon suggeriti non disponibili: $e');
    }
  }

  /// 🆕 Carica costo consegna dinamico basato su delivery_zone_roles
  Future<void> _loadDeliveryFee() async {
    if (_deliveryType != 'delivery') {
      print('🚫 [DELIVERY_FEE] Modalità ritiro - nessuna consegna necessaria');
      setState(() {
        _deliveryFeeResult = null;
      });
      return;
    }

    try {
      if (!mounted) return;

      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );

      // Determina postal_code e coordinate dalla modalità selezionata
      String? postalCode;
      double? latitude;
      double? longitude;

      if (_deliveryMode == 'saved_address' && _selectedSavedAddress != null) {
        // Usa indirizzo salvato
        postalCode = _selectedSavedAddress!.postalCode;
        latitude = _selectedSavedAddress!.latitude;
        longitude = _selectedSavedAddress!.longitude;
        print(
          '📍 [DELIVERY_FEE] Indirizzo salvato: CAP $postalCode, GPS ($latitude, $longitude)',
        );
      } else {
        // Usa posizione corrente dal LocationProvider
        postalCode = locationProvider.activePostalCode;
        latitude = locationProvider.activeLatitude;
        longitude = locationProvider.activeLongitude;

        // Se non abbiamo il CAP, attendi il reverse geocoding con retry
        if (postalCode == null && latitude != null && longitude != null) {
          print(
            '⏳ [DELIVERY_FEE] CAP non disponibile, eseguo reverse geocoding...',
          );

          try {
            final nominatimService = NominatimService();
            final addressData = await nominatimService.reverseGeocode(
              latitude,
              longitude,
            );

            if (addressData != null) {
              postalCode = addressData.postcode;
              print('✅ [DELIVERY_FEE] CAP ottenuto: $postalCode');
            } else {
              print('❌ [DELIVERY_FEE] Nominatim non ha restituito dati');
            }
          } catch (e) {
            print('❌ [DELIVERY_FEE] Errore reverse geocoding: $e');
          }
        }

        print(
          '📍 [DELIVERY_FEE] Posizione corrente: CAP $postalCode, GPS ($latitude, $longitude)',
        );
      }

      // Chiama API per calcolare il costo
      final deliveryFeeService = DeliveryFeeService();
      final result = await deliveryFeeService.calculateDeliveryFee(
        restaurantId: widget.restaurant.id,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
        subtotal: _currentSubtotal,
      );

      if (!mounted) return;

      setState(() {
        _deliveryFeeResult = result;
      });

      if (!result.isDeliverable) {
        print('❌ [DELIVERY_FEE] Zona NON servita: ${result.matchedRule}');
        if (mounted) _showZoneNotServicedDialog();
      } else {
        print('✅ [DELIVERY_FEE] Costo calcolato: €${result.finalDeliveryFee}');
        print('   - Base fee: €${result.deliveryFee}');
        print('   - Min order: €${result.minOrder}');
        print('   - Free over: €${result.freeOver}');
        print('   - Free delivery: ${result.freeDelivery}');
        print('   - Min order met: ${result.minOrderMet}');
      }
    } catch (e) {
      print('❌ [DELIVERY_FEE] Errore calcolo: $e');
      if (!mounted) return;
      setState(() {
        _deliveryFeeResult = null;
      });
      if (mounted) _showToast('Errore nel calcolo del costo di consegna');
    }
  }

  void _showZoneNotServicedDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icona
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off,
                  size: 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              // Titolo
              const Text(
                'Zona non servita',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Messaggio
              Text(
                'Siamo spiacenti, ma questo ristorante non effettua consegne nella tua zona.',
                style: TextStyle(
                  fontSize: 14,
                  color: grayColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (_deliveryFeeResult?.matchedRule != null) ...[
                const SizedBox(height: 8),
                Text(
                  _deliveryFeeResult!.matchedRule!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: grayColor,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              // Pulsante
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Ho capito',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMinOrderNotMetDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // 🔥 RICALCOLA VALORI IN TEMPO REALE (così si aggiornano se cambi quantità)
        final minOrder = _deliveryFeeResult?.minOrder ?? 0;
        final current = _currentSubtotal; // Usa getter che legge CartProvider
        final missing = (minOrder - current).clamp(0.0, double.infinity);

        // 🐛 DEBUG DIALOG
        print(
          '🔍 [DIALOG] minOrder: €$minOrder, current: €$current, missing: €$missing',
        );

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icona
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    size: 48,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 20),
                // Titolo
                const Text(
                  'Ordine minimo non raggiunto',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Messaggio
                Text(
                  'Per la consegna nella tua zona è richiesto un ordine minimo di:',
                  style: TextStyle(
                    fontSize: 14,
                    color: grayColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Box importi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lightGrayColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Minimo richiesto:',
                            style: TextStyle(
                              fontSize: 14,
                              color: darkColor,
                            ),
                          ),
                          Text(
                            '€${minOrder.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: darkColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Importo attuale:',
                            style: TextStyle(
                              fontSize: 14,
                              color: grayColor,
                            ),
                          ),
                          Text(
                            '€${current.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: grayColor,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mancano ancora:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            '€${missing.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Pulsante
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Aggiungi altri prodotti',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _couponController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  // Calcola subtotale dinamicamente dai cartItems
  double get _currentSubtotal {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    // item.totalPrice include gli extra e le scelte a pagamento: usarlo qui
    // allinea il subtotale del checkout a quello del carrello e a quello che
    // ricalcola il server.
    return cartProvider.items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get _totalBeforeDiscount {
    // Calcola il service fee come percentuale del subtotale
    double serviceFeeAmount = _currentSubtotal * (_serviceFeePercent / 100);

    double total = _currentSubtotal + serviceFeeAmount;
    if (_deliveryType == 'delivery') {
      // 🆕 Usa delivery fee dinamico
      double deliveryFee = _deliveryFeeResult?.finalDeliveryFee ?? 0.0;
      total += deliveryFee;
    }
    return total;
  }

  // Getter per il costo servizio calcolato
  double get _serviceFeeAmount {
    return _currentSubtotal * (_serviceFeePercent / 100);
  }

  // 🆕 Getter per il costo consegna (gestisce consegna gratuita)
  double get _deliveryFeeAmount {
    if (_deliveryType != 'delivery') return 0.0;
    return _deliveryFeeResult?.finalDeliveryFee ?? 0.0;
  }

  // 🆕 Verifica se la consegna è gratuita per ordine >= soglia
  bool get _isFreeDelivery {
    return _deliveryFeeResult?.freeDelivery ?? false;
  }

  /// Calcola i crediti che verranno effettivamente usati
  double get _calculatedCreditsToUse {
    if (!_useAppCredits || _availableCredits <= 0) return 0.0;

    // Calcola il totale prima dei crediti
    final totalBeforeCredits = _totalBeforeDiscount - _couponDiscount;

    // Usa il minimo tra crediti disponibili e totale ordine
    return totalBeforeCredits > _availableCredits
        ? _availableCredits
        : totalBeforeCredits;
  }

  double get _finalTotal {
    double total = _totalBeforeDiscount - _couponDiscount;

    // Applica crediti Lenny se attivi
    if (_useAppCredits) {
      total = (total - _calculatedCreditsToUse).clamp(0.0, double.infinity);
    }

    return total;
  }

  /// 🆕 CONTROLLA SE IL CLIENTE HA UNA CARTA SALVATA (OneClick)
  Future<void> _checkSavedCard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      print(
        '🔍 [ONECLICK] Token recuperato: ${token != null ? "SI (${token.substring(0, 10)}...)" : "NO"}',
      );

      if (token == null) {
        print('❌ [ONECLICK] Token non trovato, utente non autenticato');
        return;
      }

      print('🔍 [ONECLICK] Checking for saved card...');

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/nexi/check-saved-card'),
        headers: {'Content-Type': 'application/json', 'X-API-Token': token},
      );

      print('🔍 [ONECLICK] Response status: ${response.statusCode}');
      print('🔍 [ONECLICK] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data']['has_saved_card'] == true) {
          final cards = data['data']['cards'] as List<dynamic>? ?? [];
          setState(() {
            _hasSavedCard = cards.isNotEmpty;
            _savedCards = cards.cast<Map<String, dynamic>>();
            // 🔑 DEFAULT: Se ha carte salvate, seleziona la carta di default
            if (_savedCards.isNotEmpty) {
              final defaultCard = _savedCards.firstWhere(
                (c) => c['is_default'] == true,
                orElse: () => _savedCards[0],
              );
              _selectedCardAlias = defaultCard['numeroContratto'] as String?;
              _useOneClick = true; // ✅ Attiva OneClick di default
              _selectedPaymentId = null; // ✅ Deseleziona altri metodi
            }
          });
          print(
            '✅ [ONECLICK] ${_savedCards.length} carte trovate - Carta selezionata di default',
          );
        } else {
          print('⚠️ [ONECLICK] No saved card found');
        }
      }
    } catch (e) {
      print('⚠️ [ONECLICK] Errore controllo carta salvata: $e');
    }
  }

  /// Carica crediti disponibili dal wallet
  Future<void> _loadAvailableCredits() async {
    try {
      print('💰 [CREDITS] Caricamento crediti disponibili...');

      final walletService = WalletService();
      final data = await walletService.getWalletCredits();

      setState(() {
        _availableCredits = data['total_credits'] as double;
      });

      print(
        '✅ [CREDITS] Crediti disponibili: €${_availableCredits.toStringAsFixed(2)}',
      );
    } catch (e) {
      print('⚠️ [CREDITS] Errore caricamento crediti: $e');
      setState(() {
        _availableCredits = 0.0;
      });
    }
  }

  /// 🔄 Gestisce cambio tipo ordine dal checkout
  Future<void> _handleChangeOrderType() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Salva tipo ordine attuale
    final wasPickup = _deliveryType == 'pickup';
    debugPrint('🔄 [CHANGE ORDER TYPE] wasPickup: $wasPickup');

    // Mostra dialog selezione tipo ordine
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => OrderTypeDialog(),
      ),
    );

    // Dopo chiusura dialog, controlla se è cambiato
    final newIsPickup = locationProvider.isPickup;
    final didChangeType = wasPickup != newIsPickup;
    debugPrint(
      '🔄 [CHANGE ORDER TYPE] newIsPickup: $newIsPickup, didChangeType: $didChangeType',
    );

    if (didChangeType) {
      // Aggiorna delivery type locale
      setState(() {
        _deliveryType = newIsPickup ? 'pickup' : 'delivery';
      });

      // Se passa da RITIRO a CONSEGNA, valida che ristorante consegni
      if (!newIsPickup) {
        debugPrint('✅ [CHANGE ORDER TYPE] Passaggio a CONSEGNA - valido zona');
        await _validateRestaurantDelivery();
      } else {
        debugPrint(
          '✅ [CHANGE ORDER TYPE] Passaggio a RITIRO - pulisco delivery fee',
        );
        // Passaggio da CONSEGNA a RITIRO - pulisci delivery fee
        setState(() {
          _deliveryFeeResult = null;
        });
      }
    } else {
      debugPrint('⚠️ [CHANGE ORDER TYPE] Nessun cambio tipo ordine');
    }
  }

  /// \u2705 Valida che il ristorante consegni nella zona scelta
  Future<void> _validateRestaurantDelivery() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final postalCode = locationProvider.activePostalCode;
    final latitude = locationProvider.activeLatitude;
    final longitude = locationProvider.activeLongitude;

    debugPrint(
      '🔍 [VALIDATE DELIVERY] CAP: $postalCode, LAT: $latitude, LNG: $longitude',
    );

    if (postalCode == null && (latitude == null || longitude == null)) {
      debugPrint('⚠️ [VALIDATE DELIVERY] Nessuna posizione disponibile');
      _showToast('Seleziona un indirizzo di consegna');
      return;
    }

    try {
      final url =
          '${AppConstants.baseUrl}/api/restaurants/${widget.restaurant.id}/check-delivery-zone';
      debugPrint('📡 [VALIDATE DELIVERY] URL: $url');
      debugPrint(
        '📡 [VALIDATE DELIVERY] Body: postal_code=$postalCode, lat=$latitude, lng=$longitude, subtotal=$_currentSubtotal',
      );

      // Controlla se il ristorante consegna in questa zona
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'restaurant_id': widget.restaurant.id,
          'postal_code': postalCode,
          'latitude': latitude,
          'longitude': longitude,
          'subtotal': _currentSubtotal,
        }),
      );

      debugPrint('📡 [VALIDATE DELIVERY] Status: ${response.statusCode}');
      debugPrint('📡 [VALIDATE DELIVERY] Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isDeliverable = data['data']?['is_deliverable'] as bool? ?? false;

        debugPrint('📦 [VALIDATE DELIVERY] is_deliverable: $isDeliverable');

        if (!isDeliverable) {
          debugPrint(
            '❌ [VALIDATE DELIVERY] Ristorante NON consegna - mostro dialog',
          );
          // Ristorante NON consegna in questa zona
          _showRestaurantNotDeliverableDialog();
        } else {
          debugPrint(
            '✅ [VALIDATE DELIVERY] Ristorante consegna - ricarico fee',
          );
          // OK - ricarica delivery fee
          await _loadDeliveryFee();
        }
      }
    } catch (e) {
      debugPrint('❌ [VALIDATE DELIVERY] Errore: $e');
      print('❌ Errore validazione zona consegna: $e');
      _showToast('Errore verifica disponibilità consegna');
    }
  }

  /// \u26a0\ufe0f Dialog: ristorante non consegna nella zona
  void _showRestaurantNotDeliverableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icona grande centrata
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  size: 56,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),

              // Titolo
              const Text(
                'Zona non coperta',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Messaggio
              Text(
                '${widget.restaurant.name} non effettua consegne nella tua zona.',
                style: const TextStyle(
                  fontSize: 15,
                  color: grayColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Bottone primario: Ritiro di persona
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _switchBackToPickup();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store_rounded, size: 22),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ritira tu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Di persona al ristorante',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bottone secondario: Torna alla home
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Svuota il carrello
                    final cartProvider = Provider.of<CartProvider>(
                      context,
                      listen: false,
                    );
                    cartProvider.clearCart();

                    Navigator.pop(context); // Chiudi dialog
                    Navigator.pop(context); // Chiudi checkout
                    Navigator.pop(context); // Chiudi cart
                    // Il tipo ordine rimane CONSEGNA, quindi vedrà i ristoranti filtrati
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryDark,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    side: const BorderSide(color: primaryDark, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.home_rounded, size: 22),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Torna alla home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Scegli un altro ristorante',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: primaryDark.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// \ud83d\udd19 Torna a modalit\u00e0 RITIRO
  void _switchBackToPickup() {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    locationProvider.setOrderType('pickup');
    setState(() {
      _deliveryType = 'pickup';
      _deliveryFeeResult = null;
    });
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Aumenta la quantità di un prodotto nel carrello
  void _increaseItemQuantity(CartItem item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final index = cartProvider.items.indexOf(item);
    if (index >= 0) {
      cartProvider.updateQuantity(index, item.quantity + 1);
      setState(() {}); // Aggiorna UI
    }
  }

  /// Diminuisce la quantità di un prodotto nel carrello
  void _decreaseItemQuantity(CartItem item) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final index = cartProvider.items.indexOf(item);
    if (index >= 0) {
      if (item.quantity > 1) {
        cartProvider.updateQuantity(index, item.quantity - 1);
        setState(() {}); // Aggiorna UI
      } else {
        // Se quantità è 1, rimuovi completamente
        cartProvider.removeItem(index);
        // Se il carrello diventa vuoto, torna al menu del ristorante
        if (cartProvider.items.isEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RestaurantMenuScreen(restaurant: widget.restaurant),
            ),
          );
        } else {
          setState(() {}); // Aggiorna UI
        }
      }
    }
  }

  /// Selettore fascia in un PANNELLO UNICO: giorni in alto (chips),
  /// fasce sotto raggruppate per periodo. Sostituisce i 3 livelli di
  /// modale precedenti (calendario -> periodi -> fasce).
  /// NESSUNA preselezione: la scelta della fascia e' sempre esplicita
  /// (regola di prodotto). La chiusura a 30 minuti la applica il server.
  Future<void> _selectDateTime() async {
    final oggi = DateUtils.dateOnly(DateTime.now());
    DateTime giornoScelto = DateUtils.dateOnly(_selectedDate ?? oggi);
    if (giornoScelto.isBefore(oggi)) giornoScelto = oggi;

    bool caricamento = true;
    StateSetter? aggiornaSheet;

    Future<void> caricaGiorno(DateTime giorno) async {
      caricamento = true;
      aggiornaSheet?.call(() {});
      await _loadAvailableSlots(giorno);
      caricamento = false;
      aggiornaSheet?.call(() {});
    }

    // Primo caricamento avviato subito: il pannello si apre senza attese
    // e mostra lo spinner finche' le fasce non arrivano.
    caricaGiorno(giornoScelto);

    String etichettaGiorno(DateTime giorno) {
      final diff = giorno.difference(oggi).inDays;
      if (diff == 0) return 'Oggi';
      if (diff == 1) return 'Domani';
      return DateFormat('EEE d MMM', 'it_IT').format(giorno);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          aggiornaSheet = setSheetState;

          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _deliveryType == 'delivery'
                            ? 'Quando vuoi la consegna?'
                            : 'Quando passi a ritirare?',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: darkColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        color: grayColor,
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),

                // Chips dei giorni (7 giorni da oggi)
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final giorno = oggi.add(Duration(days: index));
                      final selezionato = DateUtils.isSameDay(
                        giorno,
                        giornoScelto,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(etichettaGiorno(giorno)),
                          selected: selezionato,
                          onSelected: (_) {
                            if (selezionato) return;
                            giornoScelto = giorno;
                            caricaGiorno(giorno);
                          },
                          selectedColor: primaryColor,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selezionato ? Colors.white : darkColor,
                          ),
                          side: BorderSide(
                            color: selezionato ? primaryColor : lightGrayColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // Fasce del giorno scelto, raggruppate per periodo
                Expanded(
                  child: caricamento
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        )
                      : _availableSlots.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.event_busy,
                                  size: 42,
                                  color: grayColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Nessuna fascia disponibile per '
                                  '${etichettaGiorno(giornoScelto).toLowerCase()}.\n'
                                  'Prova un altro giorno.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: grayColor,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            for (final entry in _availableSlots)
                              if (entry.containsKey('slots')) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    16,
                                    20,
                                    8,
                                  ),
                                  child: Text(
                                    (entry['label'] as String? ??
                                            entry['period'] as String? ??
                                            '')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: grayColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                for (
                                  int i = 0;
                                  i < (entry['slots'] as List).length;
                                  i++
                                )
                                  _buildTimeSlotOption(
                                    (entry['slots'] as List)[i]
                                        as Map<String, dynamic>,
                                    giornoScelto,
                                    period: entry['period'] as String?,
                                    slotIndex: i,
                                    totalSlots: (entry['slots'] as List).length,
                                  ),
                              ],
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );

    aggiornaSheet = null;
  }

  Future<void> _loadAvailableSlots(DateTime date) async {
    try {
      final orderService = OrderService();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // Indirizzo scelto: senza, il server non puo' applicare i blocchi per zona
      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );
      final usaIndirizzoSalvato =
          _deliveryType == 'delivery' &&
          _deliveryMode == 'saved_address' &&
          _selectedSavedAddress?.id != null;

      _availableSlots = await orderService.getAvailableSlots(
        restaurantId: widget.restaurant.id,
        date: dateStr,
        // Un blocco "solo consegna" non deve disabilitare le fasce del ritiro
        service: _deliveryType == 'delivery' ? 'delivery' : 'pickup',
        savedAddressId: usaIndirizzoSalvato ? _selectedSavedAddress!.id : null,
        latitude: usaIndirizzoSalvato ? null : locationProvider.activeLatitude,
        longitude: usaIndirizzoSalvato ? null : locationProvider.activeLongitude,
        postalCode: usaIndirizzoSalvato ? null : locationProvider.activePostalCode,
      );

      print('📅 Caricati ${_availableSlots.length} slot per $dateStr');
    } catch (e) {
      print('❌ Errore caricamento slot: $e');
      _showToast('Errore nel caricamento degli orari disponibili');
      _availableSlots = [];
    }
  }

  Widget _buildTimeSlotOption(
    Map<String, dynamic> slot,
    DateTime date, {
    String? period,
    int? slotIndex,
    int? totalSlots,
  }) {
    final startTime = slot['start_time'] as String;
    // final endTime = slot['end_time'] as String; // Non usato
    final label = slot['label'] as String; // es: "10:00 - 10:15"
    final availableSpots = (slot['available_spots'] as num?)?.toInt() ?? 0;

    // Fascia non ordinabile: il server la marca bloccata (blocco ordini attivo)
    // oppure non ha piu' posti. In entrambi i casi NON deve essere selezionabile:
    // altrimenti il cliente compila tutto il checkout per poi ricevere un rifiuto.
    final isBlocked = slot['is_blocked'] == true;
    final isFull = availableSpots <= 0;
    final isDisabled = isBlocked || isFull;
    final blockReason = slot['block_reason'] as String?;

    final isSelected =
        _selectedTime != null &&
        _selectedTime!.hour == int.parse(startTime.split(':')[0]) &&
        _selectedTime!.minute == int.parse(startTime.split(':')[1]);

    // Colori per il gradiente in base al periodo
    final Map<String, Color> periodColors = {
      'colazione': AppColors.accent,
      'pranzo': AppColors.danger,
      'merenda': AppColors.success,
      'cena': AppColors.primary,
    };

    Color slotColor = lightGrayColor;
    if (period != null &&
        slotIndex != null &&
        totalSlots != null &&
        totalSlots > 0) {
      final baseColor = periodColors[period] ?? primaryColor;
      // Calcola l'opacità in base all'indice (gradiente dal chiaro allo scuro)
      final opacity = 0.08 + (slotIndex / (totalSlots - 1)) * 0.25;
      slotColor = baseColor.withValues(alpha: opacity);
    }

    return GestureDetector(
      // Fascia bloccata o piena: nessuna selezione possibile.
      onTap: isDisabled
          ? () => _showToast(
              blockReason != null && blockReason.isNotEmpty
                  ? 'Fascia non disponibile: $blockReason'
                  : 'Questa fascia oraria non è più disponibile',
            )
          : () {
              setState(() {
                _selectedDate = date;
                _selectedTime = TimeOfDay(
                  hour: int.parse(startTime.split(':')[0]),
                  minute: int.parse(startTime.split(':')[1]),
                );
                _selectedTimeSlotLabel = label; // Salva il label completo
              });
              Navigator.pop(context);
            },
      child: Opacity(
        opacity: isDisabled ? 0.55 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDisabled
                ? const Color(0xFFF2F2F2)
                : (isSelected ? primaryLight : slotColor),
            border: Border.all(
              color: isSelected && !isDisabled
                  ? primaryColor
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isDisabled
                            ? grayColor
                            : (isSelected ? primaryDark : darkColor),
                        decoration: isDisabled
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    // Motivo del blocco deciso dal pannello, oppure fascia esaurita,
                    // oppure l'avviso "ultimi posti" gia' previsto.
                    if (isBlocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          blockReason != null && blockReason.isNotEmpty
                              ? blockReason
                              : 'Ordini sospesi in questa fascia',
                          style: const TextStyle(
                            fontSize: 11,
                            color: dangerColor,
                          ),
                        ),
                      )
                    else if (isFull)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Fascia al completo',
                          style: TextStyle(
                            fontSize: 11,
                            color: dangerColor,
                          ),
                        ),
                      )
                    else if (availableSpots <= 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          availableSpots == 1
                              ? 'Solo 1 posto disponibile'
                              : 'Solo $availableSpots posti disponibili',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isDisabled)
                const Icon(Icons.lock_outline, color: grayColor, size: 18)
              else if (isSelected)
                const Icon(Icons.check_circle, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Valida il coupon sul server e applica lo sconto che il server ha calcolato.
  /// Il client non decide piu' l'importo: chiede un preventivo e mostra quello.
  Future<void> _applyCoupon() async {
    final couponCode = _couponController.text.trim().toUpperCase();
    if (couponCode.isEmpty) {
      _showToast('Inserisci un codice coupon');
      return;
    }

    // Letto PRIMA di qualsiasi await: il context non va usato dopo un async gap.
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    setState(() => _couponLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyApiToken);

      final body = <String, dynamic>{
        'restaurant_id': widget.restaurant.id,
        'pickup_delivery': _deliveryType,
        'items': _buildItemsPayload(),
        'coupon_code': couponCode,
      };

      if (_deliveryType == 'delivery') {
        if (_deliveryMode == 'saved_address' && _selectedSavedAddress?.id != null) {
          body['delivery'] = {
            'source': 'saved_address',
            'saved_address_id': _selectedSavedAddress!.id,
          };
        } else {
          body['delivery'] = {
            'source': 'current_position',
            'latitude': locationProvider.activeLatitude,
            'longitude': locationProvider.activeLongitude,
            'postal_code': locationProvider.activePostalCode,
          };
        }
      }

      final response = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}/customer/order/quote'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Token': token ?? '',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;

      if (response.statusCode == 200 && data != null && data['coupon_valid'] == true) {
        setState(() {
          _couponApplied = true;
          _couponDiscount = (data['discount_amount'] as num).toDouble();
        });
        _showToast('Coupon applicato');
      } else {
        final message = data?['coupon_error'] as String? ??
            (decoded['error'] is Map ? decoded['error']['message'] as String? : null) ??
            'Codice coupon non valido';
        setState(() {
          _couponApplied = false;
          _couponDiscount = 0.0;
        });
        _showToast(message);
      }
    } catch (e) {
      setState(() {
        _couponApplied = false;
        _couponDiscount = 0.0;
      });
      _showToast('Impossibile verificare il coupon, riprova');
    } finally {
      if (mounted) setState(() => _couponLoading = false);
    }
  }

  /// Righe carrello nel formato atteso dalle API (preventivo e creazione ordine).
  List<Map<String, dynamic>> _buildItemsPayload() {
    return widget.cartItems.map((item) {
      final extras = <Map<String, dynamic>>[];
      final extrasData = item.customizationData['extras'];
      if (extrasData is List) {
        for (final extra in extrasData) {
          if (extra is Map) {
            final extraMap = Map<String, dynamic>.from(extra);
            extras.add({
              'extra_id': extraMap['id'] ?? 0,
              'price': (extraMap['price'] as num?)?.toDouble() ?? 0.0,
            });
          }
        }
      }

      return {
        'food_id': item.menuItem.id,
        'quantity': item.quantity,
        'price': item.menuItem.price,
        'discount_amount': 0.0,
        'extras': extras,
      };
    }).toList();
  }

  /// 🆕 Gestisce il pagamento tramite Nexi Build (UI Custom)
  Future<void> _handleNexiPayment(int orderId) async {
    // Determina se salvare carta (solo se non ha carte salvate)
    final saveCard = !_hasSavedCard;

    // Determina num_contratto da passare allo SDK
    String? numContratto;
    if (_useOneClick && _selectedCardAlias != null) {
      // Pagamento successivo: passa il contratto salvato
      // L'SDK mostrerà Payment Buttons invece del form carta
      numContratto = _selectedCardAlias;
    }

    // Apri XPay Build SDK (gestisce sia primo che successivi pagamenti).
    // A pagamento riuscito la schermata Nexi torna qui con 'success' e si
    // mostra la STESSA conferma dei pagamenti offline: un solo design.
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NexiBuildPaymentScreen(
          orderId: orderId,
          saveCard: saveCard,
          numContratto: numContratto, // Se != null, mostra Payment Buttons
        ),
      ),
    );

    if (result == 'success' && mounted) {
      _showOrderConfirmation(orderId);
    }
  }

  /// Invito ad accedere o registrarsi mostrato quando un ospite prova a
  /// completare l'ordine. Il carrello e' persistente: dopo l'accesso lo ritrova.
  void _mostraGateAccount() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grayLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.lock_open_outlined, size: 40, color: AppColors.primary),
            const SizedBox(height: 14),
            const Text(
              'Ci siamo quasi!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Accedi o crea un account per completare l\'ordine. Il tuo carrello resta salvato.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grayDark),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/register');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Crea un account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/login');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Ho già un account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _placeOrder() async {
    // Guardia anti doppio-invio: dal primo tap fino all'esito, ogni altro
    // tap viene ignorato (il bottone e' anche disabilitato via setState).
    if (_isPlacingOrder) return;
    setState(() => _isPlacingOrder = true);

    // true finche' il dialog di caricamento e' aperto: cosi' il catch sa
    // se deve chiuderlo, senza mai poppare la schermata per errore.
    bool loadingVisible = false;

    try {
      // Guest-first: navigare e riempire il carrello e' libero, ma per
      // completare l'ordine serve un account. Il carrello resta salvato,
      // cosi' dopo l'accesso l'utente ritrova tutto.
      final loggato = await AuthService().isLoggedIn();
      if (!mounted) return;
      if (!loggato) {
        _mostraGateAccount();
        return;
      }

      if (_selectedDate == null || _selectedTime == null) {
        _showToast('Seleziona data e orario di consegna');
        return;
      }

      if (_deliveryType == 'delivery' &&
          _deliveryMode != 'current_position' &&
          _deliveryMode != 'saved_address') {
        _showToast('Seleziona un indirizzo di consegna');
        return;
      }

      // Valida ordine minimo (se consegna a domicilio)
      if (_deliveryType == 'delivery' && _deliveryFeeResult != null) {
        final minOrder = _deliveryFeeResult!.minOrder;
        if (_currentSubtotal < minOrder) {
          _showMinOrderNotMetDialog();
          return;
        }
      }

      // Verifica zona servita
      if (_deliveryType == 'delivery' &&
          (_deliveryFeeResult == null || !_deliveryFeeResult!.isDeliverable)) {
        _showZoneNotServicedDialog();
        return;
      }

      // Metodo di pagamento (validazione sincrona, prima del loading)
      if (!_useOneClick &&
          (_selectedPaymentId == null || _selectedPaymentId!.isEmpty)) {
        _showToast('Seleziona un metodo di pagamento');
        return;
      }

      // Loading SUBITO, prima delle verifiche di rete: l'utente vede
      // una risposta immediata al tap e non puo' ritappare.
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: primaryColor)),
      );
      loadingVisible = true;

      // Verifica disponibilita' di tutti i piatti (in parallelo)
      final unavailableDishes = await _checkDishesAvailability();
      if (unavailableDishes.isNotEmpty) {
        if (mounted && loadingVisible) {
          Navigator.of(context).pop();
          loadingVisible = false;
        }
        _showUnavailableDishesDialog(unavailableDishes);
        return;
      }

      // Riverifica la fascia scelta: tra la selezione e la conferma puo'
      // essersi riempita o essere stata bloccata dal pannello.
      final slotAncoraValido = await _isSelectedSlotStillAvailable();
      if (!slotAncoraValido) {
        if (mounted && loadingVisible) {
          Navigator.of(context).pop();
          loadingVisible = false;
        }
        _showSlotNoLongerAvailableDialog();
        return;
      }
      // Prepara items per API (stesso formato usato dal preventivo)
      final items = _buildItemsPayload();

      // Calcola time_slot_id (es: 12:00 = slot 48 = 12 * 4) — LEGACY, indice a 15 min.
      // Mantenuto per retrocompatibilità col server, ma è impreciso per le fasce da 20 min.
      final timeSlotId =
          (_selectedTime!.hour * 4) + (_selectedTime!.minute ~/ 15);
      // Orario esatto scelto dal cliente: il server lo preferisce a time_slot_id.
      final slotStartTime =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime!.minute.toString().padLeft(2, '0')}:00';

      // Formatta data
      final dateOrder = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // Ottieni customer data
      final prefs = await SharedPreferences.getInstance();
      final customerPhone = prefs.getString('user_phone') ?? '';

      // Prepara DeliveryData in base alla modalità selezionata
      DeliveryData? deliveryData;
      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );

      if (_deliveryType == 'delivery') {
        if (_deliveryMode == 'current_position') {
          // Usa posizione corrente
          if (locationProvider.activeLatitude != null &&
              locationProvider.activeLongitude != null) {
            deliveryData = DeliveryData.fromCurrentPosition(
              latitude: locationProvider.activeLatitude!,
              longitude: locationProvider.activeLongitude!,
              address: locationProvider.displayAddress,
              // CAP e citta' vanno inviati: senza CAP il controllo di zona lato
              // server perde il riferimento principale, e l'ordine arriva al
              // dispatch senza il CAP di consegna.
              city: locationProvider.currentCity,
              postalCode: locationProvider.activePostalCode,
              notes: _instructionsController.text.isNotEmpty
                  ? _instructionsController.text
                  : null,
              saveAddress: _shouldSaveAddress,
            );
          } else {
            throw Exception('Posizione corrente non disponibile');
          }
        } else if (_deliveryMode == 'saved_address' &&
            _selectedSavedAddress != null) {
          // Usa indirizzo salvato
          final addressId = _selectedSavedAddress!.id;
          if (addressId == null) {
            throw Exception('ID indirizzo non valido');
          }
          deliveryData = DeliveryData.fromSavedAddress(
            savedAddressId: addressId,
          );
        } else {
          throw Exception('Seleziona un indirizzo di consegna');
        }
      }

      // 🆕 ONECLICK: Determina payment method ID
      int paymentMethodId;
      if (_useOneClick) {
        // OneClick: usa metodo Nexi (trovalo dinamicamente)
        final nexiMethod = _paymentMethods.firstWhere(
          (m) => m['slug'] == 'nexi',
          orElse: () => throw Exception('Metodo Nexi non trovato'),
        );
        paymentMethodId = int.tryParse(nexiMethod['id'].toString()) ?? 0;
      } else {
        paymentMethodId = int.tryParse(_selectedPaymentId!) ?? 0;
      }

      if (paymentMethodId == 0) {
        throw Exception('Metodo di pagamento non valido');
      }

      // Importi: gli STESSI mostrati nel riepilogo. Il server li ricalcola e
      // decide lui il valore definitivo (tariffa di zona, costo servizio,
      // coupon, crediti): qui si invia quello che il cliente ha visto.
      final deliveryFee = _deliveryFeeAmount;
      final serviceFee = _serviceFeeAmount;
      final total = _finalTotal;

      // Verifica se esiste un ordine pending da aggiornare
      int orderId;
      if (_pendingOrderId != null) {
        // Aggiorna ordine esistente con nuovo metodo di pagamento
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.keyApiToken);

        final updateUrl =
            '${AppConstants.baseUrl}/api/orders/$_pendingOrderId/payment-method';
        print('🔵 [UPDATE ORDER] URL: $updateUrl');
        print('🔵 [UPDATE ORDER] Payment Method ID: $paymentMethodId');
        print('🔵 [UPDATE ORDER] Token: ${token?.substring(0, 20)}...');

        final response = await http.put(
          Uri.parse(updateUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-API-Token': token ?? '',
          },
          body: json.encode({'payment_method_id': paymentMethodId}),
        );

        print('🔵 [UPDATE ORDER] Response status: ${response.statusCode}');
        print('🔵 [UPDATE ORDER] Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            orderId = _pendingOrderId!;
            _pendingOrderId = null; // Reset
          } else {
            throw Exception(data['error'] ?? 'Errore aggiornamento ordine');
          }
        } else {
          throw Exception('Errore server (${response.statusCode})');
        }
      } else {
        // Crea nuovo ordine
        print('📦 [ORDER] Creating NEW order...');
        print('📦 [ORDER] Payment Method ID: $paymentMethodId');
        print('📦 [ORDER] UseOneClick: $_useOneClick');
        print('📦 [ORDER] Selected Card: $_selectedCardAlias');

        final orderService = OrderService();
        final result = await orderService.createOrder(
          restaurantId: widget.restaurant.id,
          dateOrder: dateOrder,
          timeSlotId: timeSlotId,
          durationSlot: '15',
          slotStartTime: slotStartTime,
          pickupDelivery: _deliveryType,
          phone: customerPhone,
          items: items,
          paymentMethodId: paymentMethodId,
          subtotal: _currentSubtotal,
          deliveryFee: deliveryFee,
          orderFee: serviceFee,
          total: total,
          discountAmount: _couponDiscount,
          couponCode: _couponApplied ? _couponController.text.trim().toUpperCase() : null,
          appCreditsUsed: _useAppCredits ? _calculatedCreditsToUse : 0.0,
          note: _instructionsController.text.isNotEmpty
              ? _instructionsController.text
              : null,
          delivery: deliveryData, // Nuovo parametro con coordinate
        );

        orderId = result['data']['order_id'];
      }

      // Chiudi loading
      if (mounted && loadingVisible) {
        Navigator.of(context).pop();
        loadingVisible = false;
      }

      // 🆕 ONECLICK: Determina se usare Nexi (OneClick o Build)
      bool isNexiPayment = _useOneClick;
      if (!isNexiPayment && _selectedPaymentId != null) {
        final selectedMethod = _paymentMethods.firstWhere(
          (method) => method['id'].toString() == _selectedPaymentId,
          orElse: () => {},
        );
        isNexiPayment = selectedMethod['slug'] == 'nexi';
      }

      if (isNexiPayment) {
        // 🆕 Pagamento Nexi: OneClick o XPay Build
        await _handleNexiPayment(orderId);
      } else {
        // Pagamento offline (contanti, POS, ecc.) - mostra conferma diretta
        _showOrderConfirmation(orderId);
      }
    } catch (e) {
      // Chiudi loading (solo se e' davvero aperto: mai poppare la schermata)
      if (mounted && loadingVisible) {
        Navigator.of(context).pop();
        loadingVisible = false;
      }

      // Messaggio pulito, senza il prefisso tecnico "Exception:"
      final message = e.toString().replaceFirst('Exception: ', '');
      _showToast(message);
      print('❌ [CHECKOUT] Errore creazione ordine: $e');
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      } else {
        _isPlacingOrder = false;
      }
    }
  }

  /// Verifica la disponibilità di tutti i piatti nel carrello, in parallelo:
  /// con N piatti una sola attesa di rete invece di N in sequenza.
  /// Restituisce una lista di piatti non disponibili.
  Future<List<Map<String, dynamic>>> _checkDishesAvailability() async {
    try {
      final availabilityService = AvailabilityService();
      final dateStr = DateFormat(
        'yyyy-MM-dd',
      ).format(_selectedDate ?? DateTime.now());

      final results = await Future.wait(
        widget.cartItems.map((cartItem) async {
          final isAvailable = await availabilityService.isDishAvailable(
            date: dateStr,
            restaurantId: widget.restaurant.id,
            dishId: cartItem.menuItem.id,
            time: _selectedTime,
          );

          if (isAvailable) return null;

          final reason = await availabilityService.getDishUnavailabilityReason(
            date: dateStr,
            restaurantId: widget.restaurant.id,
            dishId: cartItem.menuItem.id,
          );

          return {
            'id': cartItem.menuItem.id,
            'name': cartItem.menuItem.name,
            'reason': reason ?? 'Non disponibile',
          };
        }),
      );

      return results.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      print('❌ Errore verifica disponibilità piatti: $e');
      // In caso di errore, permetti di procedere
      // (il backend gestirà eventuali errori di disponibilità)
      return [];
    }
  }

  /// Ricontrolla sul server che la fascia scelta sia ancora ordinabile.
  /// true anche in caso di errore di rete: l'ultima parola resta al server
  /// alla creazione dell'ordine, qui si intercetta solo il caso certo.
  Future<bool> _isSelectedSlotStillAvailable() async {
    if (_selectedDate == null || _selectedTime == null) return false;

    try {
      await _loadAvailableSlots(_selectedDate!);

      final target =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime!.minute.toString().padLeft(2, '0')}';

      for (final entry in _availableSlots) {
        // Nuovo formato: periodi con lista 'slots'; vecchio formato: slot diretti
        final slots = entry.containsKey('slots')
            ? (entry['slots'] as List)
            : [entry];
        for (final slot in slots) {
          final startTime = (slot['start_time'] as String?) ?? '';
          if (!startTime.startsWith(target)) continue;

          final availableSpots =
              (slot['available_spots'] as num?)?.toInt() ?? 0;
          final isBlocked = slot['is_blocked'] == true;
          return !isBlocked && availableSpots > 0;
        }
      }

      // Fascia sparita dalla lista: non piu' ordinabile
      return false;
    } catch (e) {
      print('⚠️ Riverifica fascia non riuscita, procedo: $e');
      return true;
    }
  }

  /// La fascia scelta si e' riempita (o e' stata bloccata) tra la selezione
  /// e la conferma: lo si dice chiaramente e si riapre subito il selettore.
  void _showSlotNoLongerAvailableDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.schedule, color: AppColors.warning),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fascia non più disponibile',
                style: TextStyle(
                  color: AppColors.dark,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          _selectedTimeSlotLabel != null
              ? 'La fascia $_selectedTimeSlotLabel si è appena esaurita. '
                    'Scegli un altro orario per completare l\'ordine.'
              : 'La fascia selezionata non è più disponibile. '
                    'Scegli un altro orario per completare l\'ordine.',
          style: const TextStyle(
            color: grayColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                _selectedTime = null;
                _selectedTimeSlotLabel = null;
              });
              // Riapre il pannello unico giorni+fasce
              _selectDateTime();
            },
            child: const Text(
              'Scegli un altro orario',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mostra dialog con lista di piatti non disponibili
  void _showUnavailableDishesDialog(List<Map<String, dynamic>> dishes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_outlined, color: AppColors.danger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Piatti non disponibili',
                style: TextStyle(
                  color: AppColors.dark,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'I seguenti piatti non sono disponibili per la data/orario selezionato:',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              ...dishes.map(
                (dish) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 6,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dish['name'] as String? ?? 'Piatto sconosciuto',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.dark,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dish['reason'] as String? ?? 'Non disponibile',
                              style: const TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Torna al carrello',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmation(int orderId) async {
    // Svuota il carrello dopo l'ordine confermato
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    await cartProvider.clearCart();

    // Naviga al nuovo screen spettacolare
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OrderCompletedScreen(
          orderId: orderId,
          deliveryType: _deliveryType,
          orarioConsegna: _riepilogoOrario(),
          totale: _finalTotal,
          indirizzo: _deliveryType == 'delivery'
              ? _selectedSavedAddress?.address
              : null,
        ),
      ),
    );
  }

  /// Stringa orario per la conferma: "Oggi, 13:30" o "Gio 07/08, 13:30".
  String? _riepilogoOrario() {
    if (_selectedTime == null) return null;
    final ora =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    if (_selectedDate == null) return ora;

    final oggi = DateTime.now();
    final d = _selectedDate!;
    final isOggi = d.year == oggi.year && d.month == oggi.month && d.day == oggi.day;
    final domani = oggi.add(const Duration(days: 1));
    final isDomani =
        d.year == domani.year && d.month == domani.month && d.day == domani.day;

    if (isOggi) return 'Oggi, $ora';
    if (isDomani) return 'Domani, $ora';

    final giorni = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    final g = giorni[d.weekday - 1];
    return '$g ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}, $ora';
  }

  @override
  Widget build(BuildContext context) {
    final isPickup = _deliveryType == 'pickup';
    final headerColor = isPickup ? badgePickupColor : badgeDeliveryColor;
    final orderTypeText = isPickup ? 'RITIRO' : 'CONSEGNA';
    final textColor = isPickup ? darkColor : Colors.white;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🆕 Header sottile con tipo ordine e colore dinamico
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: headerColor),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Freccia indietro a sinistra
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: textColor, size: 22),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  // Tipo ordine centrato
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPickup ? Icons.storefront : Icons.delivery_dining,
                        color: textColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        orderTypeText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🎯 SEZIONE TIPO ORDINE (RITIRO/CONSEGNA) + QUANDO
                    _buildOrderTypeHeader(),

                    const SizedBox(height: 4),

                    // 🍕 RIEPILOGO PRODOTTI
                    _buildProductsList(),

                    // Note per l'ordine (cucina + consegna, campo unico)
                    _buildNotesSection(),

                    // 💳 PAGAMENTO (include coupon)
                    _buildPaymentMethodSection(),

                    // 💰 SUMMARY FINALE
                    _buildFinalSummary(),
                  ],
                ),
              ),
            ),
            _buildOrderButton(),
          ],
        ),
      ),
    );
  }

  /// 🎯 SEZIONE TIPO ORDINE - Header principale con RITIRO/CONSEGNA
  Widget _buildOrderTypeHeader() {
    final isPickup = _deliveryType == 'pickup';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: lightGrayColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipo ordine con icona
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isPickup
                      ? const Icon(Icons.store, color: Colors.white, size: 20)
                      : AppIcon(
'assets/icons/icons8-in-transito-32.png',
                          width: 20,
                          height: 20,
                          color: Colors.white,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isPickup ? 'Ritira presso' : 'Consegna a',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Indirizzo (ristorante o consegna) con mappa
          if (isPickup) ...[
            // RITIRO: mostra indirizzo ristorante + mappa
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.restaurant.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: darkColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.restaurant.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: grayColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Mappa cliccabile
                InkWell(
                  onTap: () => _openMapForRestaurant(),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor, width: 1.5),
                    ),
                    child: const Icon(Icons.map, color: primaryColor, size: 28),
                  ),
                ),
              ],
            ),
          ] else ...[
            // CONSEGNA: mostra indirizzo consegna con freccia per cambio
            InkWell(
              onTap: _showAddressSelectionDialog,
              child: Row(
                children: [
                  Expanded(
                    child: Consumer<LocationProvider>(
                      builder: (context, locationProvider, child) {
                        return Text(
                          locationProvider.displayAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            color: darkColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIcon(
'assets/icons/icons8-piu-di-32.png',
                    width: 16,
                    height: 16,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // "Hai cambiato idea?"
          InkWell(
            onTap: _handleChangeOrderType,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
'assets/icons/icons8-ripeti-32.png',
                    width: 14,
                    height: 14,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hai cambiato idea? Clicca qui',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ⏰ QUANDO - su riga unica
          Row(
            children: [
              const Text(
                'Quando?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: darkColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectDateTime,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedDate != null
                            ? primaryColor
                            : primaryColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: _selectedDate != null
                              ? primaryColor
                              : grayColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedDate != null && _selectedTime != null
                                ? '${DateFormat('dd/MM/yyyy').format(_selectedDate!)} - ${_selectedTimeSlotLabel ?? _selectedTime!.format(context)}'
                                : 'Seleziona data e orario',
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedDate != null
                                  ? darkColor
                                  : grayColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: grayColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🗺️ Apre la mappa per mostrare l'indirizzo del ristorante
  void _openMapForRestaurant() {
    // TODO: Implementare apertura mappa con coordinate ristorante
    // Puoi usare url_launcher per aprire Google Maps o Apple Maps
    _showToast('Apertura mappa in sviluppo...');
  }

  /// 📍 Mostra modale per selezionare indirizzo di consegna
  Future<void> _showAddressSelectionDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: const AddressSelectorBottomSheet(),
      ),
    );

    // Dopo la chiusura del bottom sheet, ricalcola delivery fee
    // perché l'utente potrebbe aver cambiato indirizzo
    await _loadDeliveryFee();
  }

  /// Note per l'ordine: campo UNICO (cucina + consegna), finisce nella
  /// stampa comanda. Non aggiungere altri campi note separati.
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Note per l\'ordine',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _instructionsController,
            maxLines: 3,
            minLines: 2,
            maxLength: 250,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              fontSize: 14,
              color: darkColor,
            ),
            decoration: InputDecoration(
              hintText:
                  'Es. pizza ben cotta, senza cipolla, '
                  'citofono rotto: chiamami all\'arrivo...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: grayColor,
              ),
              counterText: '',
              filled: true,
              fillColor: lightGrayColor.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🍕 SEZIONE PRODOTTI - Riepilogo carrello
  Widget _buildProductsList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome ristorante con freccia
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.restaurant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: darkColor,
                    ),
                  ),
                ),
                AppIcon(
'assets/icons/icons8-piu-di-32.png',
                  width: 16,
                  height: 16,
                  color: primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lista prodotti (usa Consumer per aggiornamento dinamico)
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return Column(
                children: cart.items
                    .map((item) => _buildProductItem(item))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 12),

          // Badge dinamico: minimo ordine O consegna gratuita (mai entrambi)
          if (_deliveryType == 'delivery' && _deliveryFeeResult != null) ...[
            // Caso 1: Minimo ordine NON ancora raggiunto
            if (_currentSubtotal < (_deliveryFeeResult!.minOrder))
              _buildMinOrderBadge()
            // Caso 2: Minimo ordine raggiunto, mostra badge consegna gratuita (se disponibile)
            else if ((_deliveryFeeResult!.freeOver ?? 0) > 0)
              _buildFreeDeliveryBadge(),
          ],

          const SizedBox(height: 8),

          // Pulsante "Hai dimenticato qualcosa?"
          InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      RestaurantMenuScreen(restaurant: widget.restaurant),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 14,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hai dimenticato qualcosa?',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Item singolo prodotto
  Widget _buildProductItem(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Immagine piccola del prodotto
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                item.menuItem.imageUrl != null &&
                    item.menuItem.imageUrl!.isNotEmpty
                ? Image.network(
                    item.menuItem.imageUrl!,
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 45,
                      height: 45,
                      color: lightGrayColor,
                      child: const Icon(
                        Icons.restaurant,
                        color: grayColor,
                        size: 22,
                      ),
                    ),
                  )
                : Container(
                    width: 45,
                    height: 45,
                    color: lightGrayColor,
                    child: const Icon(
                      Icons.restaurant,
                      color: grayColor,
                      size: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Nome, extras e prezzo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkColor,
                  ),
                ),
                // Mostra customizations (extra e note)
                if (item.customizations.isNotEmpty)
                  ...item.customizations.map((customization) {
                    // Salta le note (mostrate separatamente)
                    if (customization.startsWith('Note:')) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+ $customization',
                        style: const TextStyle(
                          fontSize: 11,
                          color: grayColor,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Selettori +/-
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: lightGrayColor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsante -
                InkWell(
                  onTap: () => _decreaseItemQuantity(item),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.remove, size: 16, color: darkColor),
                  ),
                ),
                // Quantità
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                    ),
                  ),
                ),
                // Pulsante +
                InkWell(
                  onTap: () => _increaseItemQuantity(item),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.add, size: 16, color: darkColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 💳 SEZIONE METODO PAGAMENTO
  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pagamento',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 14),

          // Lista metodi di pagamento senza contenitori
          ..._buildPaymentOptions(),

          const SizedBox(height: 20),

          // 💰 Sezione Crediti Lenny - COMPATTA
          if (_availableCredits > 0) ...[
            Row(
              children: [
                AppIcon(
'assets/icons/icons8-ottieni-denaro-32.png',
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Crediti Lenny',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            InkWell(
              onTap: () {
                setState(() {
                  _useAppCredits = !_useAppCredits;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _useAppCredits
                      ? primaryColor.withValues(alpha: 0.1)
                      : lightGrayColor,
                  border: Border.all(
                    color: _useAppCredits ? primaryColor : lightGrayColor,
                    width: _useAppCredits ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disponibili: €${_availableCredits.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _useAppCredits ? primaryColor : darkColor,
                            ),
                          ),
                          if (_useAppCredits &&
                              _calculatedCreditsToUse > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Usati: €${_calculatedCreditsToUse.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Switch(
                      value: _useAppCredits,
                      onChanged: (value) {
                        setState(() {
                          _useAppCredits = value;
                        });
                      },
                      activeThumbColor: primaryColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Sezione coupon integrata
          const Text(
            'Coupon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: darkColor,
            ),
          ),
          const SizedBox(height: 10),

          if (!_couponApplied) ...[
            // Campo inserimento manuale coupon
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      hintText: 'Inserisci codice coupon',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: grayColor,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: lightGrayColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: lightGrayColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  // Disabilitato durante la verifica sul server: evita doppi invii
                  onPressed: _couponLoading ? null : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(70, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _couponLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Applica',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),

            // Suggeriti dal server: solo coupon che questo cliente puo'
            // ancora usare. Sezione assente se non ce ne sono.
            if (_suggestedCoupons.isNotEmpty) ...[
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                // 2.4 (non 2.8): con la descrizione su due righe le celle
                // piu' basse sforavano di ~14px sui display stretti
                childAspectRatio: 2.4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: _suggestedCoupons.map((coupon) {
                  final label = coupon['discount_label'] as String? ?? '';
                  final name = coupon['name'] as String? ?? '';
                  final description =
                      (coupon['description'] as String?)?.isNotEmpty == true
                      ? coupon['description'] as String
                      : (label.isNotEmpty ? '$label $name' : name);
                  return _buildSimpleCouponRow(
                    code: coupon['code'] as String? ?? '',
                    description: description,
                  );
                }).toList(),
              ),
            ],
          ] else ...[
            // Coupon applicato
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: successColor, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: successColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _couponController.text.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: successColor,
                          ),
                        ),
                        const Text(
                          'Coupon applicato!',
                          style: TextStyle(
                            fontSize: 11,
                            color: grayColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _couponApplied = false;
                        _couponDiscount = 0.0;
                        _couponController.clear();
                      });
                    },
                    icon: const Icon(Icons.close, size: 16, color: grayColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Riga coupon semplice senza contenitore
  Widget _buildSimpleCouponRow({
    required String code,
    required String description,
  }) {
    return InkWell(
      onTap: () {
        _couponController.text = code;
        _applyCoupon();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: lightGrayColor, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
'assets/icons/icons8-copia-32.png',
                  width: 14,
                  height: 14,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Flexible: la cella della griglia ha altezza fissa, il testo
            // si adatta invece di sfondare
            Flexible(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: grayColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 💰 SUMMARY FINALE
  Widget _buildFinalSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riepilogo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 14),

          // Il programma fedelta' entra nel momento della decisione:
          // prima era visibile solo aprendo il profilo.
          if (_earnedPoints > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 16, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Con quest\'ordine guadagni $_earnedPoints '
                      '${_earnedPoints == 1 ? 'punto' : 'punti'} fedeltà',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          _buildSummaryRow('Subtotale', _currentSubtotal),

          _buildSummaryRow('Costo servizio', _serviceFeeAmount),

          if (_deliveryType == 'delivery') _buildDeliveryFeeRow(),

          if (_deliveryType == 'delivery' &&
              _deliveryFeeResult != null &&
              !_isFreeDelivery &&
              _deliveryFeeResult!.freeOver != null &&
              _currentSubtotal < _deliveryFeeResult!.freeOver!)
            _buildFreeDeliveryIncentive(),

          if (_couponDiscount > 0)
            _buildSummaryRow(
              'Sconto coupon',
              -_couponDiscount,
              isDiscount: true,
            ),

          if (_useAppCredits && _calculatedCreditsToUse > 0)
            _buildSummaryRow(
              'Crediti Lenny',
              -_calculatedCreditsToUse,
              isDiscount: true,
            ),

          const Divider(height: 24, thickness: 1.5, color: lightGrayColor),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTALE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkColor,
                ),
              ),
              Text(
                '€${_finalTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Metodi di supporto per il riepilogo
  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: grayColor,
            ),
          ),
          Text(
            '€${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              color: isDiscount ? successColor : darkColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge avviso minimo ordine (sempre visibile se non raggiunto)
  Widget _buildMinOrderBadge() {
    final minOrder = _deliveryFeeResult?.minOrder ?? 0;
    final missing = minOrder - _currentSubtotal;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 11,
                  color: darkColor,
                ),
                children: [
                  const TextSpan(text: 'Ti mancano '),
                  TextSpan(
                    text: '€${missing.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const TextSpan(text: ' per l\'ordine minimo'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Badge consegna gratuita (incentivo opzionale)
  Widget _buildFreeDeliveryBadge() {
    final freeOver = _deliveryFeeResult?.freeOver ?? 0;
    final freeDelivery = _currentSubtotal >= freeOver;

    if (freeDelivery) {
      // Consegna gratuita raggiunta
      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: successColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: successColor, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: successColor, size: 16),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Consegna gratuita raggiunta!',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: successColor,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Ancora da raggiungere
      final missing = freeOver - _currentSubtotal;
      return Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: successColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: successColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              color: successColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 11,
                    color: darkColor,
                  ),
                  children: [
                    const TextSpan(text: 'Ti mancano '),
                    TextSpan(
                      text: '€${missing.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: successColor,
                      ),
                    ),
                    const TextSpan(text: ' per la consegna gratuita!'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFreeDeliveryIncentive() {
    final freeOver = _deliveryFeeResult?.freeOver ?? 0;
    final missing = freeOver - _currentSubtotal;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: successColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: successColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: darkColor,
                ),
                children: [
                  const TextSpan(text: 'Ti mancano '),
                  TextSpan(
                    text: '€${missing.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: successColor,
                    ),
                  ),
                  const TextSpan(text: ' per la consegna gratuita!'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryFeeRow() {
    final baseFee = _deliveryFeeResult?.deliveryFee ?? 0.0;
    final finalFee = _deliveryFeeAmount;
    final isFree = _isFreeDelivery;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Costo consegna',
            style: TextStyle(
              fontSize: 13,
              color: grayColor,
            ),
          ),
          if (isFree)
            Row(
              children: [
                Text(
                  '€${baseFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: grayColor,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: successColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'GRATIS',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              '€${finalFee.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                color: darkColor,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPaymentOptions() {
    if (_isLoading) {
      return [const Center(child: CircularProgressIndicator())];
    }

    if (_paymentMethods.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightGrayColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Nessun metodo di pagamento disponibile',
            style: TextStyle(color: grayColor),
          ),
        ),
      ];
    }

    List<Widget> widgets = [];

    // OneClick: Mostra carta salvata se disponibile
    final nexiMethod = _paymentMethods.firstWhere(
      (m) => m['slug'] == 'nexi',
      orElse: () => {},
    );
    final hasNexiMethod = nexiMethod.isNotEmpty;

    if (_hasSavedCard && hasNexiMethod) {
      widgets.add(_buildOneClickCard());
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        const Row(
          children: [
            Expanded(child: Divider(color: grayColor)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Altri metodi',
                style: TextStyle(color: grayColor, fontSize: 11),
              ),
            ),
            Expanded(child: Divider(color: grayColor)),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    // Metodi di pagamento standard - GRIGLIA 2 COLONNE
    final gridChildren = <Widget>[];

    for (final method in _paymentMethods) {
      String icon;
      switch (method['slug']) {
        case 'stripe':
        case 'nexi':
        case 'pos':
        case 'smac':
          icon = 'assets/icons/icons8-card-32.png';
          break;
        case 'cash':
          icon = 'assets/icons/icons8-soldi-32.png';
          break;
        default:
          icon = 'assets/icons/icons8-card-32.png';
      }

      gridChildren.add(
        _buildPaymentOption(
          icon: icon,
          name: method['description'] ?? 'Pagamento',
          value: method['id'].toString(),
        ),
      );
    }

    widgets.add(
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: gridChildren,
      ),
    );

    return widgets;
  }

  Widget _buildPaymentOption({
    required String icon,
    required String name,
    required String value,
  }) {
    final isSelected = _selectedPaymentId == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentId = value;
          _useOneClick = false;
          _selectedCardAlias = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.1) : lightGrayColor,
          border: Border.all(
            color: isSelected ? primaryColor : lightGrayColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              icon,
              size: 18,
              color: isSelected ? primaryColor : grayColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? primaryColor : darkColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOneClickCard() {
    if (_savedCards.isEmpty) return const SizedBox.shrink();

    if (_savedCards.length == 1) {
      return _buildSingleCardCheckbox(_savedCards[0]);
    }

    return _buildMultipleCardsRadio();
  }

  Widget _buildSingleCardCheckbox(Map<String, dynamic> card) {
    final brand = card['brand'] as String? ?? 'CARD';
    final last4 = card['last4'] as String? ?? '****';
    final expiry = card['expiry'] as String?;
    final cardInfo = '$brand •••• $last4${expiry != null ? ' ($expiry)' : ''}';
    final isSelected = _useOneClick;

    return InkWell(
      onTap: () {
        setState(() {
          _useOneClick = !_useOneClick;
          if (_useOneClick) {
            _selectedPaymentId = null;
            _selectedCardAlias = card['numeroContratto'] as String?;
          } else {
            _selectedCardAlias = null;
            if (_paymentMethods.isNotEmpty) {
              _selectedPaymentId = _paymentMethods[0]['id'].toString();
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            AppIcon(
'assets/icons/icons8-card-32.png',
              width: 20,
              height: 20,
              color: isSelected ? primaryColor : grayColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cardInfo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? primaryColor : darkColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'OneClick',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: successColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleCardsRadio() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _savedCards.length,
      itemBuilder: (context, index) {
        final card = _savedCards[index];
        final brand = card['brand'] as String? ?? 'CARD';
        final last4 = card['last4'] as String? ?? '****';
        final cardInfo = '$brand •••• $last4';
        final cardAlias = card['numeroContratto'] as String?;
        final isSelected = _useOneClick && _selectedCardAlias == cardAlias;
        final isDefault = card['is_default'] == true;

        return GestureDetector(
          onTap: () {
            setState(() {
              _useOneClick = true;
              _selectedCardAlias = cardAlias;
              _selectedPaymentId = null;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? primaryColor : lightGrayColor,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIcon(
'assets/icons/icons8-card-32.png',
                      width: 16,
                      height: 16,
                      color: isSelected ? primaryColor : grayColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cardInfo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? primaryColor : darkColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isDefault)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: successColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: successColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          // Disabilitato durante l'invio: doppia protezione insieme alla
          // guardia _isPlacingOrder dentro _placeOrder.
          onPressed: _isPlacingOrder ? null : _placeOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            minimumSize: const Size(double.infinity, 54),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPlacingOrder) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                _isPlacingOrder ? 'INVIO IN CORSO...' : 'CONFERMA ORDINE',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '€${_finalTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
