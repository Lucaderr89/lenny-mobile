import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import 'wave_clipper.dart';
import 'app_icon.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../services/auth_service.dart';
import '../screens/delivery_address_selection_screen.dart';

/// Dialog Full Screen per selezione tipo ordine - Stile Lenny
class OrderTypeDialog extends StatefulWidget {
  const OrderTypeDialog({super.key});

  // Colori coerenti con l'app
  static const Color primaryDarkPink = AppColors.primary;
  static const Color accentYellow = AppColors.accent;
  static const Color darkColor = Color(0xFF0A0A0A);

  @override
  State<OrderTypeDialog> createState() => _OrderTypeDialogState();
}

class _OrderTypeDialogState extends State<OrderTypeDialog> {
  static const Color primaryDarkPink = OrderTypeDialog.primaryDarkPink;
  static const Color accentYellow = OrderTypeDialog.accentYellow;
  static const Color darkColor = OrderTypeDialog.darkColor;

  /// Una scelta e' gia' in corso: un secondo tocco non deve avviarne un'altra.
  bool _sceltaInCorso = false;

  /// Il dialog e' gia' stato chiuso. Serve perche' la chiusura puo' arrivare
  /// dopo un'attesa asincrona: senza questo controllo una seconda pop
  /// toglierebbe anche la schermata sotto e lascerebbe lo schermo nero.
  bool _chiuso = false;

  /// Chiude il dialog una volta sola e mai se non c'e' nulla sotto.
  void _chiudi() {
    if (_chiuso || !mounted) return;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    _chiuso = true;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header con testo e immagine in stile login
              SizedBox(
                width: double.infinity,
                height: 140,
                child: Stack(
                  children: [
                    // Testo a sinistra
                    Positioned(
                      left: 28,
                      top: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Come vuoi\nordinare?',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: darkColor,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Immagine a destra
                    Positioned(
                      right: -10,
                      bottom: -40,
                      child: Image.asset(
                        'assets/images/ORDINA.png',
                        width: 198,
                        height: 198,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),

              // Card bianca - Expanded riempie tutto lo spazio rimanente
              Expanded(
                child: ClipPath(
                  clipper: const WaveClipper(),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          80,
                          28,
                          40 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: Column(
                          children: [
                            // Pulsante CONSEGNA
                            _OrderTypeButton(
                              iconPath:
                                  'assets/icons/icons8-in-transito-32.png',
                              title: 'Consegna a domicilio',
                              subtitle: 'Ti portiamo il cibo dove vuoi',
                              color: primaryDarkPink,
                              textColor: darkColor,
                              onTap: _handleDeliverySelection,
                            ),

                            const SizedBox(height: 16),

                            // Pulsante RITIRO
                            _OrderTypeButton(
                              iconPath: 'assets/icons/icons8-negozio-32.png',
                              title: 'Ritiro al ristorante',
                              subtitle: 'Passa a prendere il tuo ordine',
                              color: accentYellow,
                              textColor: darkColor,
                              onTap: _handlePickupSelection,
                            ),

                            const SizedBox(height: 28),

                            // Una riga sola: la spiegazione del badge in home
                            // avviene sul badge vero (coach-mark alla prima
                            // visita), non con un tutorial preventivo qui.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Potrai cambiare in qualsiasi momento',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gestisce selezione CONSEGNA
  Future<void> _handleDeliverySelection() async {
    if (_sceltaInCorso) return;
    _sceltaInCorso = true;

    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final loggato = await AuthService().isLoggedIn();
    if (!mounted) return;

    // Ospite: non ha indirizzi salvati, quindi far scegliere tra "posizione
    // attuale" e "indirizzi salvati" non ha senso (e la lista fallirebbe).
    // Si usa direttamente la posizione del telefono.
    if (!loggato) {
      locationProvider.setOrderType('delivery');

      // Il dialog si chiude subito. La posizione NON viene attesa: fra
      // permesso di sistema, aggancio del GPS e reverse geocoding puo'
      // richiedere anche una quindicina di secondi, e nel frattempo qui
      // resterebbe una schermata ferma senza spiegazione. La home si aggiorna
      // da sola quando le coordinate arrivano.
      _chiudi();
      unawaited(locationProvider.requestCurrentPosition());
      return;
    }

    // Utente registrato: sceglie tra posizione attuale e indirizzi salvati.
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeliveryAddressSelectionScreen(),
      ),
    );
    if (!mounted) return;

    // Chiudi il dialog SOLO se l'utente ha selezionato un indirizzo
    if (result != null) {
      _chiudi();
    } else {
      // È tornato indietro: il dialog resta aperto e riabilita la scelta.
      _sceltaInCorso = false;
    }
  }

  /// Gestisce selezione RITIRO
  void _handlePickupSelection() {
    if (_sceltaInCorso) return;
    _sceltaInCorso = true;

    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Imposta modalità RITIRO
    locationProvider.setOrderType('pickup');

    // Chiudi il dialog
    _chiudi();
  }
}

/// Widget pulsante tipo ordine - Stile minimale
class _OrderTypeButton extends StatelessWidget {
  final String iconPath;
  final String title;
  final String subtitle;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _OrderTypeButton({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.color,
    this.textColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icona
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: AppIcon(iconPath, size: 26, color: textColor),
                ),
              ),

              const SizedBox(width: 16),

              // Testi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: textColor.withValues(alpha: 0.8),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Freccia
              Icon(
                Icons.arrow_forward_ios,
                color: textColor.withValues(alpha: 0.6),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
