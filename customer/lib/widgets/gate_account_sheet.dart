import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';

/// Invito ad accedere o registrarsi, mostrato all'ospite quando tocca qualcosa
/// che senza account non puo' funzionare.
///
/// L'app e' guest-first: navigare, sfogliare i menu e riempire il carrello
/// restano liberi. Il blocco scatta solo al passaggio successivo, e soprattutto
/// arriva PRIMA di aprire la schermata: cosi' l'ospite vede questo invito
/// invece di uno schermo che prova a caricare indirizzi e orari e fallisce.
///
/// Il messaggio e' parametrico perche' cambia col contesto: al checkout si
/// rassicura sul carrello salvato, altrove si spiega cosa si otterrebbe.
Future<void> mostraGateAccount(
  BuildContext context, {
  String messaggio =
      'Accedi o crea un account per completare l\'ordine. '
      'Il tuo carrello resta salvato.',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      // viewInsets per la tastiera, padding.bottom per la barra gesti: il
      // secondo evita che i pulsanti finiscano sotto l'home indicator.
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 +
            MediaQuery.viewInsetsOf(ctx).bottom +
            MediaQuery.paddingOf(ctx).bottom,
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
            messaggio,
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
