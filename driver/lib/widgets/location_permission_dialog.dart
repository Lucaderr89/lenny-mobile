import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Dialog per richiedere permesso GPS al primo avvio turno
class LocationPermissionDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const LocationPermissionDialog({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Abilita GPS e notifiche',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
            'Per lavorare ci servono due permessi. La posizione solo mentre hai '
            'una consegna in corso, le notifiche per avvisarti dei nuovi ordini:',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 20),
          _buildBenefit(
            Icons.notifications_active_rounded,
            'Avvisarti subito quando ti viene assegnata una consegna',
            AppColors.primary,
          ),
          const SizedBox(height: 14),
          _buildBenefit(
            Icons.sync_rounded,
            'Aggiornare da solo lo stato dell\'ordine quando arrivi al ritiro e quando consegni',
            AppColors.primary,
          ),
          const SizedBox(height: 14),
          _buildBenefit(
            Icons.local_shipping_rounded,
            'Tenere aggiornato il cliente sull\'avanzamento della consegna',
            AppColors.success,
          ),
          const SizedBox(height: 14),
          _buildBenefit(
            Icons.lock_outline,
            'Si attiva solo con un ordine attivo e si spegne a consegna conclusa',
            AppColors.accent,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mai tracciato quando sei libero o fuori servizio',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: onDecline,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'Non ora',
            style: TextStyle(color: AppColors.gray, fontSize: 15),
          ),
        ),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Abilita',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefit(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.3)),
        ),
      ],
    );
  }
}
