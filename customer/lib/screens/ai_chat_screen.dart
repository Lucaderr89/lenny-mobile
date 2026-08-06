import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import '../services/restaurant_service.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../models/menu_item.dart';
import '../config/app_colors.dart';
import '../widgets/cart_conflict_dialog.dart';
import 'product_detail_modal.dart';
import 'restaurant_menu_screen.dart';

/// Schermata chat con assistente AI (Google Gemini)
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final GeminiService _geminiService = GeminiService();
  final RestaurantService _restaurantService = RestaurantService();
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Cronologia multi-turn (max 10 messaggi)
  final List<Map<String, String>> _conversationHistory = [];

  bool _isTyping = false;
  String? _queueMessage;
  Timer? _queueCheckTimer;
  String? _currentRequestId;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _queueCheckTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text:
              'Ciao, sono Lenny.\n\nConosco i menu di tutti i locali qui intorno: dimmi che fame hai, quanto vuoi spendere o quanto tempo hai, e ti trovo qualcosa di buono.\n\nPosso anche dirti chi è aperto, quanto dista un locale e quando ti arriverebbe l\'ordine.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    _onSendMessage(text.trim());
  }

  Future<void> _onSendMessage(String text) async {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
      _queueMessage = null;
    });
    _scrollToBottom();

    // Cronologia multi-turn
    _conversationHistory.add({'role': 'user', 'text': text});
    // Rimuovi in coppia (user+model) per mantenere sempre 'user' come primo elemento
    while (_conversationHistory.length > 10) {
      _conversationHistory.removeAt(0); // rimuove user
      if (_conversationHistory.isNotEmpty) {
        _conversationHistory.removeAt(0); // rimuove model
      }
    }

    // Posizione GPS
    final locProvider = context.read<LocationProvider>();
    final lat = locProvider.activeLatitude ?? 0.0;
    final lng = locProvider.activeLongitude ?? 0.0;

    // Escludi l'ultimo entry (messaggio corrente) dalla history inviata
    final history = _conversationHistory.length > 1
        ? _conversationHistory.sublist(0, _conversationHistory.length - 1)
        : <Map<String, String>>[];

    final response = await _geminiService.sendMessage(
      text,
      lat: lat,
      lng: lng,
      conversationHistory: history,
      cart: _riepilogoCarrello(),
    );

    if (response.status == 'queued') {
      setState(() {
        _queueMessage = _attesaLeggibile(response.estimatedWait ?? 30);
        _currentRequestId = response.requestId;
      });
      _startQueuePolling();
    } else if (response.status == 'ready') {
      setState(() => _queueMessage = null);
      _addAIResponse(response);
    } else {
      setState(() => _isTyping = false);
      _addFallbackError(response.message);
    }
  }

  /// Riepilogo del carrello da mandare a Lenny.
  ///
  /// Solo il minimo che serve a ragionarci: cosa c'è dentro, da quale locale e
  /// quanto fa. Nessun dato personale, e niente se il carrello è vuoto.
  Map<String, dynamic>? _riepilogoCarrello() {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return null;

    return {
      'restaurant_id': cart.restaurantId,
      'restaurant_name': cart.restaurantName,
      'total': cart.total,
      'items': cart.items
          .take(15)
          .map((i) => {'name': i.menuItem.name, 'quantity': i.quantity})
          .toList(),
    };
  }

  /// Attesa in parole invece che in secondi.
  ///
  /// Quando la quota giornaliera di tutti i modelli e' esaurita l'attesa puo'
  /// essere di ore: scriverla in secondi non direbbe nulla a chi legge.
  String _attesaLeggibile(int secondi) {
    if (secondi >= 3600) {
      final ore = (secondi / 3600).round();
      return 'Sono molto richiesto in questo momento. Riprova fra circa $ore ${ore == 1 ? 'ora' : 'ore'}.';
    }
    if (secondi >= 90) {
      final minuti = (secondi / 60).round();
      return 'Un attimo di pazienza, ci vogliono circa $minuti minuti...';
    }
    return 'Sto pensando...';
  }

  void _startQueuePolling() {
    _queueCheckTimer?.cancel();

    // Rete di sicurezza: senza un tetto, una richiesta che resta in attesa
    // terrebbe il timer acceso a interrogare il server ogni 3 secondi per
    // sempre, consumando batteria e dati anche a schermo chiuso.
    var tentativi = 0;
    const maxTentativi = 40; // due minuti

    _queueCheckTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (_currentRequestId == null) {
        timer.cancel();
        return;
      }

      if (++tentativi > maxTentativi) {
        timer.cancel();
        setState(() {
          _isTyping = false;
          _queueMessage = null;
          _currentRequestId = null;
        });
        _addFallbackError('Ci sto mettendo troppo. Riprova fra poco!');
        return;
      }

      final status = await _geminiService.checkQueueStatus(_currentRequestId!);

      if (status.status == 'ready') {
        timer.cancel();
        setState(() {
          _queueMessage = null;
          _currentRequestId = null;
        });
        _addAIResponse(status);
      } else if (status.status == 'error') {
        timer.cancel();
        setState(() {
          _isTyping = false;
          _queueMessage = null;
          _currentRequestId = null;
        });
        _addFallbackError(status.message);
      } else if (status.estimatedWait != null) {
        // L'attesa puo' allungarsi mentre si aspetta (quota esaurita nel
        // frattempo): il messaggio a schermo deve seguirla.
        setState(() => _queueMessage = _attesaLeggibile(status.estimatedWait!));
      }
    });
  }

  void _addAIResponse(AIResponse response) {
    setState(() {
      _isTyping = false;
      if (response.message.isNotEmpty) {
        _messages.add(
          ChatMessage(
            text: response.message,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
      if (response.action == 'show_dishes' && response.dishes.isNotEmpty) {
        _messages.add(ChatMessage.withDishes(response.dishes));
      }
      if (response.action == 'show_restaurants' &&
          response.restaurants.isNotEmpty) {
        _messages.add(ChatMessage.withRestaurants(response.restaurants));
      }
    });
    _scrollToBottom();

    if (response.message.isNotEmpty) {
      _conversationHistory.add({'role': 'model', 'text': response.message});
      // Rimuovi in coppia se si supera il limite (il trim principale è in _onSendMessage)
      while (_conversationHistory.length > 10) {
        _conversationHistory.removeAt(0);
        if (_conversationHistory.isNotEmpty) _conversationHistory.removeAt(0);
      }
    }
  }

  /// Mostra l'errore in chat.
  ///
  /// Il server manda spesso un messaggio che spiega davvero cosa succede
  /// ("sono molto richiesto", "crea un account per continuare"): quello vale
  /// piu' di un generico "si e' verificato un errore", che lascia l'utente
  /// senza sapere se riprovare ha senso.
  void _addFallbackError([String? messaggioDalServer]) {
    final testo = (messaggioDalServer != null && messaggioDalServer.trim().isNotEmpty)
        ? messaggioDalServer
        : 'Non riesco a risponderti in questo momento. Riprova tra poco!';

    setState(() {
      _isTyping = false;
      _messages.add(
        ChatMessage(
          text: testo,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _onQuickActionTap(String label) {
    switch (label) {
      case 'Ispirami':
        _onSendMessage('Cosa mi consigli da mangiare adesso?');
        break;
      case 'Aperti ora':
        _onSendMessage('Quali locali sono aperti adesso qui vicino?');
        break;
      // "Novità" chiedeva dei ristoranti nuovi in zona, un dato che non
      // esiste da nessuna parte: la risposta era per forza vaga. La
      // popolarità recente invece è un dato vero e serve davvero a scegliere.
      case 'Va forte':
        _onSendMessage('Cosa stanno ordinando tutti in questi giorni?');
        break;
    }
  }

  // ─── Carrello ────────────────────────────────────────────────────────────────

  Future<void> _handleAddDish(AIDish aiDish) async {
    if (aiDish.hasRequiredExtras) {
      setState(() => _isTyping = true);
      final menuItem = await _geminiService.getDishDetail(aiDish.id);
      setState(() => _isTyping = false);

      if (!mounted) return;

      if (menuItem == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile caricare i dettagli del piatto'),
          ),
        );
        return;
      }

      final cartProvider = context.read<CartProvider>();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProductDetailModal(
          menuItem: menuItem,
          restaurantId: aiDish.restaurantId,
          restaurantName: aiDish.restaurantName,
          onAddToCart: (item, qty, customizations, priceModifier) {
            try {
              cartProvider.addItem(
                menuItem: item,
                restaurantId: aiDish.restaurantId,
                restaurantName: aiDish.restaurantName,
                quantity: qty,
                selectedExtras: _extractExtras(customizations),
              );
              _addFallbackText('${item.name} aggiunto al carrello.');
            } catch (e) {
              _showCartConflictDialog(aiDish);
            }
          },
        ),
      );
    } else {
      final cartProvider = context.read<CartProvider>();
      final menuItem = MenuItem(
        id: aiDish.id,
        name: aiDish.name,
        description: '',
        price: aiDish.price,
        category: '',
        badges: const [],
        customizations: const [],
        allergens: const [],
        dietaryOptions: const [],
      );

      try {
        cartProvider.addItem(
          menuItem: menuItem,
          restaurantId: aiDish.restaurantId,
          restaurantName: aiDish.restaurantName,
          quantity: 1,
        );
        _addFallbackText(
          '${aiDish.name} aggiunto al carrello.\nVai al carrello quando vuoi completare l\'ordine.',
        );
      } catch (e) {
        _showCartConflictDialog(aiDish);
      }
    }
  }

  List<Map<String, dynamic>> _extractExtras(
    Map<String, dynamic> customizations,
  ) {
    final extras = <Map<String, dynamic>>[];
    customizations.forEach((_, value) {
      if (value is List) {
        for (final opt in value) {
          if (opt is Map<String, dynamic>) {
            extras.add({
              'id': opt['id'],
              'name': opt['label'] ?? opt['name'] ?? '',
              'price': (opt['price_modifier'] as num?)?.toDouble() ?? 0.0,
            });
          }
        }
      } else if (value is Map<String, dynamic>) {
        extras.add({
          'id': value['id'],
          'name': value['label'] ?? value['name'] ?? '',
          'price': (value['price_modifier'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });
    return extras;
  }

  void _showCartConflictDialog(AIDish dish) {
    // Dialog brandizzato UNICO per il conflitto carrello, lo stesso di
    // home e menu (prima la chat aveva un AlertDialog tutto suo).
    final cartProvider = context.read<CartProvider>();
    showCartConflictDialog(
      context: context,
      currentRestaurantName:
          cartProvider.restaurantName ?? 'un altro ristorante',
      onClearCart: () {
        cartProvider.clearCart();
        _handleAddDish(dish);
      },
    );
  }

  Future<void> _handleOpenRestaurant(AIRestaurant aiRest) async {
    setState(() => _isTyping = true);
    try {
      final restaurant = await _restaurantService.getRestaurantDetail(
        aiRest.id,
      );
      if (!mounted) return;
      setState(() => _isTyping = false);
      if (restaurant != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantMenuScreen(restaurant: restaurant),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il ristorante')),
        );
      }
    } catch (_) {
      setState(() => _isTyping = false);
    }
  }

  void _addFallbackText(String text) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: false, timestamp: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.surface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: AppColors.surface,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lenny AI',
                  style: TextStyle(
                    color: AppColors.surface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isTyping ? 'Sta scrivendo...' : 'Online',
                  style: TextStyle(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Quick actions chips (nascosto quando tastiera aperta per evitare overflow)
          if (_messages.length == 1 &&
              MediaQuery.of(context).viewInsets.bottom == 0)
            _buildQuickActions(),

          // Queue message (se presente)
          if (_queueMessage != null) _buildQueueMessage(),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Typing indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypingDot(0),
                        const SizedBox(width: 4),
                        _buildTypingDot(1),
                        const SizedBox(width: 4),
                        _buildTypingDot(2),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input field
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // Dispatching per tipo
    if (message.dishes != null) return _buildDishesBlock(message.dishes!);
    if (message.restaurants != null) {
      return _buildRestaurantsBlock(message.restaurants!);
    }

    // Bolla testo standard
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text ?? '',
                style: TextStyle(
                  color: isUser ? AppColors.surface : AppColors.dark,
                  fontSize: 13,
                  height: 1.38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card piatti ─────────────────────────────────────────────────────────────

  Widget _buildDishesBlock(List<AIDish> dishes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ecco cosa ho trovato per te',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.dark.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            // Più alta di prima: la copertina del piatto è passata da una
            // fascia colorata di 44 a una foto di 64.
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: dishes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _buildDishCard(dishes[i]),
            ),
          ),
        ],
      ),
    );
  }

  /// Segnaposto per i piatti che non hanno ancora una foto.
  Widget _segnapostoPiatto() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          size: 22,
          color: AppColors.primary.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _buildDishCard(AIDish dish) {
    return Container(
      width: 165,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto vera se il piatto ce l'ha, altrimenti un segnaposto sobrio.
          // Le immagini si stanno caricando a mano un po' alla volta: la scheda
          // migliora da sola man mano che arrivano, senza toccare il codice.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: (dish.imageUrl != null && dish.imageUrl!.isNotEmpty)
                  ? Image.network(
                      dish.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _segnapostoPiatto(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : _segnapostoPiatto(),
                    )
                  : _segnapostoPiatto(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  dish.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.gray),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '€${dish.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _handleAddDish(dish),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: dish.hasRequiredExtras
                              ? Colors.amber.shade700
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dish.hasRequiredExtras ? 'Personalizza' : 'Aggiungi',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card ristoranti ─────────────────────────────────────────────────────────

  Widget _buildRestaurantsBlock(List<AIRestaurant> restaurants) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ristoranti trovati',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.dark.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          ...restaurants.map((r) => _buildRestaurantCard(r)),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(AIRestaurant rest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.storefront_outlined,
            size: 20,
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                rest.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Un locale chiuso resta proponibile (si ordina su fascia), ma
            // dev'essere evidente prima di aprirne il menu.
            if (!rest.isOpen) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gray.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'chiuso ora',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          rest.distanceKm > 0
              ? '${rest.city}  •  ${rest.distanceKm.toStringAsFixed(1)} km'
              : rest.city,
          style: TextStyle(fontSize: 12, color: AppColors.gray),
        ),
        trailing: GestureDetector(
          onTap: () => _handleOpenRestaurant(rest),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Menu',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 150)),
      builder: (_, value, _) => Opacity(
        opacity: value,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.gray,
            shape: BoxShape.circle,
          ),
        ),
      ),
      onEnd: () {
        if (mounted && _isTyping) setState(() {});
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 96),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Scrivi un messaggio...',
                    hintStyle: TextStyle(fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 38,
              height: 38,
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _sendMessage(_textController.text),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.auto_awesome_outlined, 'label': 'Ispirami'},
      {'icon': Icons.schedule_outlined, 'label': 'Aperti ora'},
      {'icon': Icons.local_fire_department_outlined, 'label': 'Va forte'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        children: actions.map((action) {
          return Expanded(
            child: GestureDetector(
              onTap: () => _onQuickActionTap(action['label']! as String),
              child: Container(
                margin: EdgeInsets.only(right: action == actions.last ? 0 : 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(
                      action['icon']! as IconData,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        action['label']! as String,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQueueMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.orange.shade700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _queueMessage!,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modello messaggi chat — supporta testo, card piatti, card ristoranti
class ChatMessage {
  final String? text;
  final bool isUser;
  final DateTime timestamp;
  final List<AIDish>? dishes;
  final List<AIRestaurant>? restaurants;

  ChatMessage({
    required String text,
    required this.isUser,
    required this.timestamp,
  }) : text = text,
       dishes = null,
       restaurants = null;

  ChatMessage.withDishes(this.dishes)
    : text = null,
      isUser = false,
      restaurants = null,
      timestamp = DateTime.now();

  ChatMessage.withRestaurants(this.restaurants)
    : text = null,
      isUser = false,
      dishes = null,
      timestamp = DateTime.now();
}
