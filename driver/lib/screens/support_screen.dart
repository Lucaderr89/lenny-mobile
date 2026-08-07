import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';

/// SupportScreen - Contatta supporto e guide operative
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    const email = 'supporto@lenny.com';
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Richiesta Supporto Driver',
    );

    try {
      if (!await launchUrl(emailUri)) {
        throw Exception('Impossibile aprire app email');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _launchPhone(BuildContext context) async {
    const phone = '+390541123456';
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);

    try {
      if (!await launchUrl(phoneUri)) {
        throw Exception('Impossibile avviare chiamata');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const phone = '393291234567';
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$phone?text=Ciao, ho bisogno di supporto',
    );

    try {
      if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
        throw Exception('Impossibile aprire WhatsApp');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cSfondo,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Supporto',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sezione Contatta Supporto
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cCard,
                border: context.cBordoCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.support_agent,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Contatta Supporto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.cTesto,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hai bisogno di aiuto? Contattaci attraverso uno dei seguenti canali:',
                    style: TextStyle(fontSize: 14, color: context.cTestoSec),
                  ),
                  const SizedBox(height: 20),

                  // Email
                  _buildContactButton(
                    context,
                    icon: Icons.email,
                    title: 'Email',
                    subtitle: 'supporto@lenny.com',
                    color: AppColors.primary,
                    onTap: () => _launchEmail(context),
                  ),
                  const SizedBox(height: 12),

                  // Telefono
                  _buildContactButton(
                    context,
                    icon: Icons.phone,
                    title: 'Telefono',
                    subtitle: '+39 0541 123456',
                    color: AppColors.success,
                    onTap: () => _launchPhone(context),
                  ),
                  const SizedBox(height: 12),

                  // WhatsApp
                  _buildContactButton(
                    context,
                    icon: Icons.chat,
                    title: 'WhatsApp',
                    subtitle: 'Chat con il supporto',
                    color: const Color(0xFF25D366),
                    onTap: () => _launchWhatsApp(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sezione Guide Operative
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cCard,
                border: context.cBordoCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: AppColors.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Guide Operative',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.cTesto,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lista guide
                  _buildGuideItem(
                    context,
                    icon: Icons.play_circle_outline,
                    title: 'Come iniziare un turno',
                    description: 'Guida passo-passo per andare online',
                    onTap: () => _showGuideDialog(
                      context,
                      'Come iniziare un turno',
                      '1. Clicca sul bottone "Vai Online" nella home\n\n'
                          '2. Autorizza i permessi GPS quando richiesto\n\n'
                          '3. Attendi che il sistema ti registri come disponibile\n\n'
                          '4. Inizierai a ricevere ordini nella tua zona',
                    ),
                  ),
                  const Divider(height: 24),
                  _buildGuideItem(
                    context,
                    icon: Icons.shopping_bag_outlined,
                    title: 'Gestione ordini',
                    description: 'Come accettare e completare consegne',
                    onTap: () => _showGuideDialog(
                      context,
                      'Gestione ordini',
                      '1. Ricevi notifica di nuovo ordine\n\n'
                          '2. Accetta l\'ordine entro il tempo limite\n\n'
                          '3. Ritira l\'ordine dal ristorante\n\n'
                          '4. Consegna al cliente e completa l\'ordine',
                    ),
                  ),
                  const Divider(height: 24),
                  _buildGuideItem(
                    context,
                    icon: Icons.calendar_today,
                    title: 'Disponibilità settimanali',
                    description: 'Come comunicare i tuoi turni',
                    onTap: () => _showGuideDialog(
                      context,
                      'Disponibilità settimanali',
                      '1. Vai in Profilo > Turni/Disponibilità\n\n'
                          '2. Seleziona la settimana desiderata\n\n'
                          '3. Clicca sulle celle per selezionare fasce orarie\n\n'
                          '4. Salva le tue disponibilità entro il martedì',
                    ),
                  ),
                  const Divider(height: 24),
                  _buildGuideItem(
                    context,
                    icon: Icons.account_balance_wallet,
                    title: 'Pagamenti e guadagni',
                    description: 'Come funzionano i pagamenti',
                    onTap: () => _showGuideDialog(
                      context,
                      'Pagamenti e guadagni',
                      '• I pagamenti vengono effettuati settimanalmente\n\n'
                          '• Puoi vedere il riepilogo in Storico Consegne\n\n'
                          '• Le mance vanno direttamente a te\n\n'
                          '• Verifica che l\'IBAN sia corretto nel profilo',
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

  Widget _buildContactButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.cTesto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.cTestoSec,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.cTesto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: context.cTestoSec),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.cTestoSec),
          ],
        ),
      ),
    );
  }

  void _showGuideDialog(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cTestoSec.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.cTesto,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: context.cTesto,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
