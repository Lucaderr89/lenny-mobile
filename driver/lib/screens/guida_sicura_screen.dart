import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Pagina informativa "Guida sicura": spiega al driver come attivare la
/// LETTURA NOTIFICHE del proprio telefono (funzione di sistema), cosi'
/// con le cuffie o il casco connesso anche WhatsApp viene letto a voce
/// senza toccare il telefono. L'app non c'entra: e' il sistema a leggere.
class GuidaSicuraScreen extends StatelessWidget {
  const GuidaSicuraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final temaScuro = Theme.of(context).brightness == Brightness.dark;

    Widget sezione(String titolo, List<String> passi) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: temaScuro ? AppColors.nightSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: temaScuro ? Border.all(color: AppColors.nightBorder) : null,
          boxShadow: temaScuro ? null : const [AppColors.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titolo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...passi.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(fontSize: 14, height: 1.4),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Guida sicura')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                'Il telefono in mano mentre guidi costa caro, in tutti i '
                'sensi. L\'app gia\' ti annuncia a voce ordini e tappe: '
                'con la lettura notifiche del TUO telefono puoi farti '
                'leggere anche WhatsApp e il resto, con cuffie o casco '
                'connessi. Si attiva una volta sola.',
                style: TextStyle(fontSize: 14, height: 1.45),
              ),
            ),
            sezione('Android (Assistente Google)', const [
              'Collega cuffie o casco Bluetooth',
              'Tieni premuto il tasto home o di\' "Hey Google"',
              'Di\' "Attiva la lettura delle notifiche"',
              'In alternativa: Impostazioni Google > Assistente > '
                  'Annuncia le notifiche',
              'Da quel momento, a cuffie connesse, i messaggi vengono '
                  'letti a voce e puoi rispondere dettando',
            ]),
            sezione('iPhone (Siri)', const [
              'Collega AirPods o cuffie Beats compatibili',
              'Vai in Impostazioni > Notifiche > Annuncia notifiche',
              'Attiva e scegli le app da farti leggere (es. WhatsApp)',
              'Siri legge i messaggi in cuffia e puoi rispondere a voce',
            ]),
            sezione('Consigli', const [
              'Monta il telefono su un supporto: mai in mano',
              'Gli annunci vocali di Lenny si regolano da '
                  'Impostazioni > Guida',
              'Se devi scrivere, fermati: nessuna consegna vale una multa '
                  'o un incidente',
            ]),
          ],
        ),
      ),
    );
  }
}
