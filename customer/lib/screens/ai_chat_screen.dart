import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_icon.dart';
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
import '../widgets/foto_rete.dart';

/// Schermata chat con assistente AI (Google Gemini)
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final GeminiService _geminiService = GeminiService();

  /// Sfumatura che identifica la voce dell'assistente.
  ///
  /// Un solo accento, usato ovunque parli l'IA: firma, cursore, bordo del
  /// campo di scrittura. E' quello che distingue una schermata "intelligente"
  /// da una chat qualunque, senza aggiungere un solo elemento in piu'.
  static const LinearGradient _sfumaturaLenny = LinearGradient(
    colors: [Color(0xFF0F4E8C), Color(0xFF5B8FD6), Color(0xFF9B6BD6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
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

    if (response.cartActions.isNotEmpty) {
      _eseguiAggiunteAlCarrello(response.cartActions);
    }

    if (response.message.isNotEmpty) {
      _conversationHistory.add({'role': 'model', 'text': response.message});
      // Rimuovi in coppia se si supera il limite (il trim principale è in _onSendMessage)
      while (_conversationHistory.length > 10) {
        _conversationHistory.removeAt(0);
        if (_conversationHistory.isNotEmpty) _conversationHistory.removeAt(0);
      }
    }
  }

  /// Applica al carrello le aggiunte decise dall'assistente.
  ///
  /// Il server ha gia' verificato che il piatto esista, che sia dello stesso
  /// locale e che le scelte obbligatorie siano complete: qui si esegue. Il
  /// piatto lo si rilegge comunque dal server, cosi' prezzo base e struttura
  /// sono quelli veri e non una ricostruzione dai campi dell'azione.
  Future<void> _eseguiAggiunteAlCarrello(List<AICartAction> azioni) async {
    final cart = context.read<CartProvider>();
    final aggiunti = <String>[];

    for (final azione in azioni) {
      final piatto = await _geminiService.getDishDetail(azione.dishId);
      if (piatto == null || !mounted) continue;

      try {
        cart.addItem(
          menuItem: piatto,
          restaurantId: azione.restaurantId,
          restaurantName: azione.restaurantName,
          quantity: azione.quantity,
          selectedExtras: azione.options
              .map(
                (o) => <String, dynamic>{
                  'id': o.id,
                  'name': o.descrizione,
                  'price': o.price,
                },
              )
              .toList(),
          notes: azione.notes,
        );
        aggiunti.add(
          azione.quantity > 1
              ? '${azione.quantity}x ${azione.name}'
              : azione.name,
        );
      } catch (e) {
        // Praticamente solo il caso "ristorante diverso", che il server
        // dovrebbe aver gia' intercettato: se arriva fin qui il carrello e'
        // cambiato mentre l'assistente rispondeva.
        if (!mounted) return;
        _messages.add(
          ChatMessage(
            text:
                'Non sono riuscito ad aggiungere ${azione.name}: nel carrello '
                'ci sono piatti di un altro locale.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        setState(() {});
      }
    }

    if (aggiunti.isEmpty || !mounted) return;

    // Un colpetto: l'aggiunta e' successa altrove, fuori dalla vista, e senza
    // un segnale fisico l'utente non se ne accorge finche' non apre il carrello.
    HapticFeedback.mediumImpact();

    setState(() {
      _messages.add(ChatMessage.carrello(aggiunti));
    });
    _scrollToBottom();
  }

  /// Mostra l'errore in chat.
  ///
  /// Il server manda spesso un messaggio che spiega davvero cosa succede
  /// ("sono molto richiesto", "crea un account per continuare"): quello vale
  /// piu' di un generico "si e' verificato un errore", che lascia l'utente
  /// senza sapere se riprovare ha senso.
  void _addFallbackError([String? messaggioDalServer]) {
    final testo =
        (messaggioDalServer != null && messaggioDalServer.trim().isNotEmpty)
        ? messaggioDalServer
        : 'Non riesco a risponderti in questo momento. Riprova tra poco!';

    setState(() {
      _isTyping = false;
      _messages.add(
        ChatMessage(text: testo, isUser: false, timestamp: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  // NB: le vecchie scorciatoie a etichetta ("Ispirami", "Va forte") sono
  // diventate proposte scritte per esteso in _buildQuickActions: la frase
  // inviata e' la stessa che il cliente legge, cosi' impara come si parla
  // all'assistente invece di premere un bottone e sperare.

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
              child: const AppIcon(
                'assets/icons_svg/lenny-robot.svg',
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
            // Toccare la conversazione chiude la tastiera. Senza, una volta
            // aperta restava li' e mangiava meta' schermo: non c'era nessun
            // modo di richiuderla se non inviando un messaggio.
            // onPanDown e non onTap: cosi' si chiude anche appena si comincia
            // a scorrere, che e' il gesto istintivo per tornare a leggere.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              onPanDown: (_) => FocusScope.of(context).unfocus(),
              child: ListView.builder(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                reverse: false,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
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
                    child: const AppIcon(
                      'assets/icons_svg/lenny-robot.svg',
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

  /// Conferma di cio' che e' finito nel carrello.
  ///
  /// Sta fuori dalla bolla di testo di proposito: quello che l'assistente
  /// dice e' generato, questo e' il resoconto di un fatto. Tenerli distinti
  /// evita che una frase sbagliata faccia credere a un'aggiunta mai avvenuta,
  /// o il contrario.
  Widget _buildConfermaCarrello(List<String> piatti) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIcon(
              'assets/icons_svg/icons8-cart-32.svg',
              size: 20,
              color: AppColors.success,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    piatti.length == 1
                        ? 'Aggiunto al carrello'
                        : 'Aggiunti al carrello',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    piatti.join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.dark,
                      height: 1.35,
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

  Widget _buildMessageBubble(ChatMessage message) {
    // Dispatching per tipo
    if (message.dishes != null) return _buildDishesBlock(message.dishes!);
    if (message.restaurants != null) {
      return _buildRestaurantsBlock(message.restaurants!);
    }
    if (message.aggiuntiAlCarrello != null) {
      return _buildConfermaCarrello(message.aggiuntiAlCarrello!);
    }

    // Le due voci si distinguono per POSIZIONE e RITMO, non per due bolle
    // contrapposte. La risposta dell'assistente e' il contenuto della pagina:
    // scorre a tutta larghezza, senza cornice e senza avatar che la rimpicciolisca.
    // La domanda del cliente e' un inciso: breve, rientrata, in un guscio tenue.
    // E' l'impostazione di Gemini, e serve a far leggere: incolonnare risposte
    // lunghe dentro una bolla stretta le rende faticose.
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18, left: 48),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Text(
              message.text ?? '',
              style: const TextStyle(
                color: AppColors.dark,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Firma discreta: dice di chi e' la voce senza rubare spazio al testo.
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => _sfumaturaLenny.createShader(r),
                child: const AppIcon(
                  'assets/icons_svg/lenny-robot.svg',
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              ShaderMask(
                shaderCallback: (r) => _sfumaturaLenny.createShader(r),
                child: const Text(
                  'Lenny',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SelectableText(
            message.text ?? '',
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 15.5,
              height: 1.52,
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
                  child: const AppIcon(
                    'assets/icons_svg/lenny-robot.svg',
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
        child: AppIcon(
          'assets/icons_svg/icons8-ristorante-32.svg',
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
                  ? FotoRete(
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
                  child: const AppIcon(
                    'assets/icons_svg/lenny-robot.svg',
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
          child: AppIcon(
            'assets/icons_svg/icons8-negozio-32.svg',
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
            // Il campo e' racchiuso da un filo sfumato: e' lo stesso accento
            // della firma di Lenny, e dice "qui parli con l'assistente" senza
            // bisogno di scriverlo. Il bordo si ottiene con un contenitore
            // sfumato e uno bianco dentro, perche' Border non accetta gradienti.
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 110),
                padding: const EdgeInsets.all(1.4),
                decoration: BoxDecoration(
                  gradient: _sfumaturaLenny,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: TextField(
                    controller: _textController,
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: 'Chiedi a Lenny…',
                      hintStyle: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.gray.withValues(alpha: 0.75),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14.5, height: 1.35),
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _sfumaturaLenny,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _sendMessage(_textController.text);
                  },
                  child: const AppIcon(
                    'assets/icons_svg/icons8-arrow-WHITE-32.svg',
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Schermata d'apertura: saluto e proposte concrete.
  ///
  /// Le vecchie scorciatoie erano tre etichette da due parole ("Ispirami",
  /// "Va forte"): dicevano cosa succedeva DOPO averle toccate, non cosa
  /// l'assistente sapesse fare. Chi apre la chat per la prima volta non ha
  /// idea di cosa chiedere, e resta a guardare il campo vuoto.
  /// Qui invece ogni proposta e' una frase intera, cioe' un esempio di
  /// domanda: mostra il livello di confidenza che si puo' usare e allo stesso
  /// tempo insegna che si puo' ordinare parlando.
  Widget _buildQuickActions() {
    final proposte = <Map<String, String>>[
      {
        'icona': 'icons8-cappello-dello-chef-32',
        'titolo': 'Consigliami tu',
        'frase': 'Ho fame ma non so cosa voglio, consigliami tu',
      },
      {
        'icona': 'icons8-orologio-32',
        'titolo': 'Chi è aperto adesso',
        'frase': 'Quali locali sono aperti adesso qui vicino?',
      },
      {
        'icona': 'icons8-cart-32',
        'titolo': 'Ordina parlando',
        'frase': 'Mettimi nel carrello una pizza margherita senza mozzarella',
      },
      {
        'icona': 'icons8-piu_amati-32',
        'titolo': 'Cosa va forte',
        'frase': 'Cosa stanno ordinando tutti in questi giorni?',
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (r) => _sfumaturaLenny.createShader(r),
            child: const Text(
              'Ciao, sono Lenny',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Conosco i menu di tutti i locali. Chiedimi un consiglio, oppure dimmi cosa vuoi e te lo metto nel carrello.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.gray.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 16),
          ...proposte.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _propostaApertura(p['icona']!, p['titolo']!, p['frase']!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _propostaApertura(String icona, String titolo, String frase) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _onSendMessage(frase);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    const Color(0xFF9B6BD6).withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: AppIcon(
                  'assets/icons_svg/$icona.svg',
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"$frase"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.gray,
                      fontStyle: FontStyle.italic,
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

  /// Conferma visiva di cio' che l'assistente ha messo nel carrello.
  /// Non e' una frase del modello: e' il resoconto di quello che e'
  /// realmente successo, quindi si disegna a parte e non si puo' sbagliare.
  final List<String>? aggiuntiAlCarrello;

  ChatMessage({
    required String text,
    required this.isUser,
    required this.timestamp,
  }) : text = text,
       dishes = null,
       restaurants = null,
       aggiuntiAlCarrello = null;

  ChatMessage.withDishes(this.dishes)
    : text = null,
      isUser = false,
      restaurants = null,
      aggiuntiAlCarrello = null,
      timestamp = DateTime.now();

  ChatMessage.carrello(this.aggiuntiAlCarrello)
    : text = null,
      isUser = false,
      dishes = null,
      restaurants = null,
      timestamp = DateTime.now();

  ChatMessage.withRestaurants(this.restaurants)
    : text = null,
      isUser = false,
      dishes = null,
      aggiuntiAlCarrello = null,
      timestamp = DateTime.now();
}
