import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../services/auth_service.dart';

/// Avvolge una schermata riservata agli utenti registrati.
///
/// Se c'e' un account mostra la schermata; altrimenti presenta l'invito a
/// registrarsi al posto suo, senza che le chiamate al server partano e
/// falliscano. Si usa ai punti di navigazione, cosi' la schermata avvolta
/// resta invariata.
class SoloUtenti extends StatelessWidget {
  final Widget schermata;
  final String titolo;
  final String messaggio;
  final IconData icona;

  const SoloUtenti({
    super.key,
    required this.schermata,
    required this.titolo,
    required this.messaggio,
    required this.icona,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) return schermata;
        return GuestGate(titolo: titolo, messaggio: messaggio, icona: icona);
      },
    );
  }
}

/// Schermata mostrata all'ospite al posto di una sezione che richiede l'account.
///
/// L'app e' guest-first: si naviga e si riempie il carrello senza registrarsi.
/// Le sezioni personali (ordini, preferiti, profilo, portafoglio, notifiche)
/// pero' non hanno nulla da mostrare senza un account: invece di lasciar
/// fallire le chiamate e presentare un errore, si spiega perche' e si invita a
/// registrarsi, con lo stesso tono del passaggio finale del checkout.
class GuestGate extends StatelessWidget {
  /// Titolo breve, es. "I tuoi ordini".
  final String titolo;

  /// Frase che spiega cosa si otterrebbe con un account.
  final String messaggio;

  final IconData icona;

  /// Se true mostra una AppBar con il tasto indietro (schermate aperte da push).
  final bool conAppBar;

  const GuestGate({
    super.key,
    required this.titolo,
    required this.messaggio,
    required this.icona,
    this.conAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final contenuto = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icona, size: 42, color: AppColors.primary),
            ),
            const SizedBox(height: 22),
            Text(
              titolo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              messaggio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.grayDark,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.push('/register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
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
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => context.push('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Ho gia\' un account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!conAppBar) return contenuto;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dark),
        title: Text(
          titolo,
          style: const TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: contenuto,
    );
  }
}
