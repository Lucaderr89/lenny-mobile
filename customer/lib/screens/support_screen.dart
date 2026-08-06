import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';

/// Support Screen - Contatti e informazioni per assistenza clienti
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const String supportPhone = '3346841489';

  /// wa.me accetta SOLO numeri in formato internazionale senza '+':
  /// senza prefisso il link si apre ma WhatsApp non trova il contatto.
  static const String supportPhoneIntl = '39$supportPhone';
  static const String companyName = 'Lenny SRL';
  static const String companyAddress =
      'Via Ca\' dei Lunghi, 8\n47893 Cailungo - San Marino';

  Future<void> _makePhoneCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: supportPhone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openWhatsApp() async {
    final Uri whatsappUri = Uri.parse('https://wa.me/$supportPhoneIntl');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
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
          'Supporto',
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.light,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icona
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/icons8-supporto-32.png',
                    width: 40,
                    height: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Titolo principale
            const Center(
              child: Text(
                'Come possiamo aiutarti?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),

            // Descrizione
            const Center(
              child: Text(
                'Il nostro team è a tua disposizione per qualsiasi necessità',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.gray,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),

            // Card contatti
            _buildContactCard(context),
            const SizedBox(height: 20),

            // Card sede
            _buildLocationCard(),
            const SizedBox(height: 20),

            // Card orari
            _buildScheduleCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icons/icons8-telephone-32.png',
                width: 24,
                height: 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Text(
                'Contattaci',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Per problemi, reclami o informazioni puoi contattare il nostro servizio clienti:',
            style: TextStyle(fontSize: 13, color: AppColors.gray, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Numero telefono (non cliccabile, solo display)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/icons8-telephone-32.png',
                  width: 20,
                  height: 20,
                  color: AppColors.dark,
                ),
                const SizedBox(width: 10),
                Text(
                  supportPhone,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottoni Chiama e WhatsApp
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _makePhoneCall,
                  icon: Image.asset(
                    'assets/icons/icons8-telephone-32.png',
                    width: 20,
                    height: 20,
                    color: AppColors.light,
                  ),
                  label: const Text(
                    'Chiama',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.light,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openWhatsApp,
                  icon: const Icon(Icons.chat, size: 20),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: AppColors.light,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icons/icons8-indirizzo-32.png',
                width: 24,
                height: 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Text(
                'La nostra sede',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            companyName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            companyAddress,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.gray,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icons/icons8-orologio-32.png',
                width: 24,
                height: 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Text(
                'Orari di apertura',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildScheduleRow('Lunedì - Venerdì', '8:30 - 23:00'),
          const SizedBox(height: 10),
          _buildScheduleRow('Sabato', '10:00 - 23:00'),
          const SizedBox(height: 10),
          _buildScheduleRow('Domenica', '11:00 - 23:00'),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String day, String hours) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(day, style: const TextStyle(fontSize: 13, color: AppColors.gray)),
        Text(
          hours,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.dark,
          ),
        ),
      ],
    );
  }
}
