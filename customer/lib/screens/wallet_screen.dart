import 'package:flutter/material.dart';
import '../models/saved_card.dart';
import '../services/wallet_service.dart';
import '../config/app_colors.dart';

/// Screen Wallet - Gestione carte salvate e crediti Lenny
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _service = WalletService();

  List<SavedCard> _cards = [];
  double _totalCredits = 0.0;
  List<WalletCredit> _credits = [];

  bool _isLoadingCards = false;
  bool _isLoadingCredits = false;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    await Future.wait([_loadCards(), _loadCredits()]);
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoadingCards = true;
    });

    try {
      final cards = await _service.getSavedCards();
      setState(() {
        _cards = cards;
        _isLoadingCards = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCards = false;
      });
    }
  }

  Future<void> _loadCredits() async {
    setState(() {
      _isLoadingCredits = true;
    });

    try {
      final data = await _service.getWalletCredits();
      setState(() {
        _totalCredits = data['total_credits'] as double;
        _credits = data['credits'] as List<WalletCredit>;
        _isLoadingCredits = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCredits = false;
      });
    }
  }

  Future<void> _setDefaultCard(SavedCard card) async {
    final success = await _service.setDefaultCard(card.cardAlias);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carta predefinita aggiornata')),
      );
      _loadCards();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore aggiornamento carta')),
      );
    }
  }

  Future<void> _removeCard(SavedCard card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovi carta'),
        content: Text('Vuoi rimuovere la carta ${card.maskedNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _service.removeSavedCard();
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Carta rimossa')));
        _loadCards();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Errore rimozione carta')));
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
          icon: Image.asset(
            'assets/icons/icons8-freccia-lunga-a-sinistra-32.png',
            width: 24,
            height: 24,
            color: AppColors.dark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Wallet',
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
            icon: Image.asset(
              'assets/icons/icons8-aggiornamenti-disponibili-32.png',
              width: 22,
              height: 22,
              color: AppColors.dark,
            ),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWalletData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sezione Crediti Lenny
                _buildCreditsSection(),

                const SizedBox(height: 24),

                // Sezione Carte Salvate
                _buildCardsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreditsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/icons/icons8-ottieni-denaro-32.png',
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Crediti Lenny',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (_isLoadingCredits)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Credit Card con totale
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Saldo disponibile',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '€${_totalCredits.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Lista crediti
        if (_credits.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._credits.map((credit) => _buildCreditItem(credit)),
        ],
      ],
    );
  }

  Widget _buildCreditItem(WalletCredit credit) {
    return InkWell(
      onTap: () => _showCreditDetails(credit),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(8),
          border: credit.isExpiringSoon
              ? Border.all(color: Colors.orange, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Image.asset(credit.sourceIcon, width: 20, height: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        credit.sourceLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      if (credit.isExpiringSoon) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'In scadenza',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    credit.description,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (credit.isPartiallyUsed) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Utilizzato €${credit.used.toStringAsFixed(2)} di €${credit.originalAmount.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 10, color: AppColors.gray),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€${credit.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00C853),
                  ),
                ),
                if (credit.isPartiallyUsed)
                  Text(
                    'disponibili',
                    style: TextStyle(fontSize: 9, color: AppColors.gray),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreditDetails(WalletCredit credit) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con icona e tipo
              Row(
                children: [
                  Image.asset(credit.sourceIcon, width: 28, height: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          credit.sourceLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '€${credit.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00C853),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Descrizione completa
              _detailRow('Descrizione', credit.description),
              const SizedBox(height: 10),

              // Importo originale
              _detailRow(
                'Importo originale',
                '€${credit.originalAmount.toStringAsFixed(2)}',
              ),

              // Se parzialmente usato
              if (credit.isPartiallyUsed) ...[
                const SizedBox(height: 10),
                _detailRow(
                  'Già utilizzato',
                  '€${credit.used.toStringAsFixed(2)}',
                  valueColor: Colors.orange,
                ),
              ],

              const SizedBox(height: 10),

              // Data creazione
              _detailRow('Ricevuto il', _formatDate(credit.createdAt)),

              // Data scadenza
              if (credit.expiresAt != null) ...[
                const SizedBox(height: 10),
                _detailRow(
                  'Scade il',
                  _formatDate(credit.expiresAt!),
                  valueColor: credit.isExpiringSoon
                      ? Colors.orange
                      : Colors.grey[700],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildCardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/icons/icons8-portafoglio-32.png',
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Carte Salvate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (_isLoadingCards)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_cards.isEmpty && !_isLoadingCards)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.credit_card_off, size: 48, color: AppColors.gray),
                  const SizedBox(height: 12),
                  Text(
                    'Nessuna carta salvata',
                    style: TextStyle(fontSize: 14, color: AppColors.gray),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aggiungi una carta al primo pagamento',
                    style: TextStyle(fontSize: 12, color: AppColors.gray),
                  ),
                ],
              ),
            ),
          ),

        if (_cards.isNotEmpty) ..._cards.map((card) => _buildCardItem(card)),
      ],
    );
  }

  Widget _buildCardItem(SavedCard card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.isDefault ? const Color(0xFFFF6B35) : AppColors.lightGray,
          width: card.isDefault ? 2 : 1,
        ),
        boxShadow: [
          if (card.isDefault)
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/icons/icons8-card-32.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.brand,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.maskedNumber,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (card.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Predefinita',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (card.expiry != null) ...[
              const SizedBox(height: 8),
              Text(
                'Scadenza: ${card.expiry}',
                style: TextStyle(fontSize: 12, color: AppColors.gray),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!card.isDefault)
                  TextButton.icon(
                    onPressed: () => _setDefaultCard(card),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Imposta predefinita'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B35),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _removeCard(card),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Rimuovi'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
