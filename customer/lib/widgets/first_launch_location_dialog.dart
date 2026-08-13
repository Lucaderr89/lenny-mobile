import 'package:flutter/material.dart';
import 'app_icon.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';

/// Dialog mostrato al primo avvio per richiedere permesso geolocalizzazione.
///
/// Qui si chiede SOLO la posizione. Le notifiche NO: l'app e' guest-first e
/// questo dialog lo vede anche chi sta solo sbirciando. iOS mostra il prompt
/// delle notifiche una volta sola per installazione: un "Non ora" dato da
/// guest resterebbe definitivo anche dopo la registrazione, e quell'utente
/// non riceverebbe mai gli aggiornamenti sull'ordine. Il permesso si chiede
/// quindi dopo il login/registrazione (vedi FcmService.onUserLoggedIn).
class FirstLaunchLocationDialog extends StatelessWidget {
  const FirstLaunchLocationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          AppIcon(
            'assets/icons_svg/icons8-location-32.svg',
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Attiva la posizione',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Per offrirti la migliore esperienza, abbiamo bisogno della tua posizione per:',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
          _buildBenefit(
            'icons8-ristorante-32',
            'Trovare i ristoranti più vicini',
          ),
          const SizedBox(height: 12),
          _buildBenefit(
            'lenny-consegna',
            'Calcolare i costi di consegna precisi',
          ),
          const SizedBox(height: 12),
          _buildBenefit(
            'icons8-orologio-32',
            'Stimare i tempi di consegna accurati',
          ),
          const SizedBox(height: 16),
          Text(
            'Potrai sempre modificare questa impostazione in seguito.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Segna che il permesso è stato richiesto (anche se rifiutato)
            context.read<LocationProvider>().markPermissionRequested();
            Navigator.of(context).pop(false);
          },
          child: const Text('Non ora'),
        ),
        ElevatedButton(
          onPressed: () async {
            final locationProvider = context.read<LocationProvider>();

            // Chiudi dialog immediatamente
            Navigator.of(context).pop(true);

            // Richiedi posizione (il provider gestisce già il loading)
            final success = await locationProvider.requestCurrentPosition();
            await locationProvider.markPermissionRequested();

            // Mostra risultato solo se errore
            if (!success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          locationProvider.locationError ??
                              'Impossibile rilevare la posizione. Controlla le impostazioni GPS.',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange[700],
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Attiva posizione'),
        ),
      ],
    );
  }

  Widget _buildBenefit(String icona, String text) {
    return Row(
      children: [
        AppIcon(
          'assets/icons_svg/$icona.svg',
          size: 20,
          color: Colors.green[700],
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}

/// Mostra il dialog se è primo avvio e il permesso non è stato mai richiesto
Future<void> showFirstLaunchLocationDialogIfNeeded(BuildContext context) async {
  final locationProvider = context.read<LocationProvider>();

  // Attendi un frame per assicurarsi che il provider sia inizializzato
  await Future.delayed(const Duration(milliseconds: 100));

  if (context.mounted &&
      locationProvider.isFirstLaunch &&
      !locationProvider.hasRequestedPermission) {
    debugPrint('🎯 [FIRST LAUNCH] Mostrando dialog permesso GPS...');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const FirstLaunchLocationDialog(),
    );
  } else {
    debugPrint('🎯 [FIRST LAUNCH] Dialog non necessario (già mostrato)');

    // Se non è primo avvio ma non abbiamo posizione, richiedi silenziosamente
    if (locationProvider.currentLatitude == null) {
      debugPrint('🎯 [FIRST LAUNCH] Richiedo posizione in background...');
      locationProvider.requestCurrentPosition(showLoading: false);
    }
  }
}
