import 'package:flutter/material.dart';
import '../../widgets/app_icon.dart';
import '../../config/app_colors.dart';

/// Tab "Per te" - Sezione personalizzata con funzionalità coming soon
class PerTeTab extends StatefulWidget {
  final ScrollController scrollController;

  const PerTeTab({super.key, required this.scrollController});

  @override
  State<PerTeTab> createState() => _PerTeTabState();
}

class _PerTeTabState extends State<PerTeTab>
    with AutomaticKeepAliveClientMixin {
  // Colori
  static const Color lightColor = Color(0xFFFFFFFF);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // richiesto da AutomaticKeepAliveClientMixin
    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        // Padding top
        const SliverToBoxAdapter(child: SizedBox(height: 15)),

        // 1. Lenny Prime
        SliverToBoxAdapter(child: _buildPrimeBanner()),

        // 2. Challenges
        SliverToBoxAdapter(child: _buildChallenges()),

        // 3. Gift Card
        SliverToBoxAdapter(child: _buildGiftCard()),

        // Padding finale
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }

  Widget _buildPrimeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, Color(0xFFFFB300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  'assets/icons_svg/icons8-premium-32.svg',
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Lenny Prime',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Teaser: niente cifre inventate, solo la promessa del servizio.
          const Text(
            'L\'abbonamento che azzera i costi di consegna',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Benefici
          _buildPrimeBenefit('Consegna gratuita'),
          const SizedBox(height: 5),
          _buildPrimeBenefit('Nessun costo extra'),
          const SizedBox(height: 5),
          _buildPrimeBenefit('Offerte esclusive'),

          const SizedBox(height: 16),

          // Coming Soon Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Text(
                'COMING SOON',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimeBenefit(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
      ],
    );
  }

  Widget _buildChallenges() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const AppIcon(
                  'assets/icons_svg/icons8-coppa-32.svg',
                  color: lightColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Challenges',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: lightColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Descrizione
          const Text(
            'Completa sfide giornaliere e settimanali per guadagnare punti extra e sbloccare premi esclusivi',
            style: TextStyle(
              fontSize: 15,
              color: lightColor,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),

          // Esempi challenge
          _buildChallengeExample(
            'Ordina da 3 ristoranti diversi',
            '+500 punti',
            'assets/icons_svg/icons8-ristorante-32.svg',
          ),
          const SizedBox(height: 10),
          _buildChallengeExample(
            'Raggiungi una spesa di €50',
            'Badge esclusivo',
            'assets/icons_svg/icons8-stella-32.svg',
          ),
          const SizedBox(height: 10),
          _buildChallengeExample(
            'Prova una nuova categoria',
            '+300 punti',
            'assets/icons_svg/icons8-mappa-32.svg',
          ),

          const SizedBox(height: 20),

          // Coming Soon Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Text(
                'COMING SOON',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: lightColor,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeExample(String title, String reward, String icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AppIcon(icon, color: lightColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: lightColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                reward,
                style: TextStyle(
                  fontSize: 12,
                  color: lightColor.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGiftCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const AppIcon(
                  'assets/icons_svg/icons8-regalo-32.svg',
                  color: lightColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Gift Card',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: lightColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Descrizione
          const Text(
            'Regala buon cibo a chi ami. Acquista gift card digitali da utilizzare su tutti i ristoranti della piattaforma',
            style: TextStyle(
              fontSize: 15,
              color: lightColor,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),

          // Features
          _buildGiftCardFeature('Tagli da €10, €25, €50 e €100', 'assets/icons_svg/icons8-euro-32.svg'),
          const SizedBox(height: 10),
          _buildGiftCardFeature(
            'Valide su tutti i ristoranti',
            'assets/icons_svg/icons8-ristorante-32.svg',
          ),
          const SizedBox(height: 10),
          _buildGiftCardFeature('Invio immediato via email o SMS', 'assets/icons_svg/icons8-email-32.svg'),
          const SizedBox(height: 10),
          _buildGiftCardFeature('Nessuna scadenza', 'assets/icons_svg/icons8-orologio-32.svg'),

          const SizedBox(height: 20),

          // Coming Soon Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Text(
                'COMING SOON',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: lightColor,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCardFeature(String text, String icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AppIcon(icon, color: lightColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: lightColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
