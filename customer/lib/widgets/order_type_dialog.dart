import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../screens/delivery_address_selection_screen.dart';

/// Dialog Full Screen per selezione tipo ordine - Stile Lenny
class OrderTypeDialog extends StatelessWidget {
  const OrderTypeDialog({super.key});

  // Colori coerenti con l'app
  static const Color primaryDarkPink = Color(0xFFFF7566); // primary dell'app
  static const Color accentYellow = Color(
    0xFFF6E644,
  ); // splash gradient dell'app
  static const Color darkColor = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F0),
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
                Expanded(child: ClipPath(
                  clipper: _WaveClipper(),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(child: Padding(
                      padding: EdgeInsets.fromLTRB(28, 80, 28, 40 + MediaQuery.of(context).padding.bottom),
                      child: Column(
                        children: [
                          // Pulsante CONSEGNA
                          _OrderTypeButton(
                            iconPath: 'assets/icons/icons8-in-transito-32.png',
                            title: 'Consegna a domicilio',
                            subtitle: 'Ti portiamo il cibo dove vuoi',
                            color: primaryDarkPink,
                            textColor: darkColor,
                            onTap: () => _handleDeliverySelection(context),
                          ),

                          const SizedBox(height: 16),

                          // Pulsante RITIRO
                          _OrderTypeButton(
                            iconPath: 'assets/icons/icons8-negozio-32.png',
                            title: 'Ritiro al ristorante',
                            subtitle: 'Passa a prendere il tuo ordine',
                            color: accentYellow,
                            textColor: darkColor,
                            onTap: () => _handlePickupSelection(context),
                          ),

                          const SizedBox(height: 28),

                          // Info bottom con badge
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD8D8D8),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
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
                                        'Potrai modificare in qualsiasi momento',
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
                                const SizedBox(height: 12),
                                Text(
                                  'cliccando sul badge:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Badge Consegna
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryDarkPink,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.delivery_dining,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Consegna',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Badge Ritiro
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentYellow,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.storefront,
                                            color: darkColor,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Ritiro',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: darkColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Avviso cambio indirizzo
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange[700],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Cambiando indirizzo durante il checkout, costi e tempi di consegna potrebbero variare',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.orange[900],
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ),
                )),
              ],
            ),
          ),
        ),
    );
  }

  /// Gestisce selezione CONSEGNA
  void _handleDeliverySelection(BuildContext context) async {
    // NON chiudere il dialog ancora, apri selezione indirizzo
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeliveryAddressSelectionScreen(),
      ),
    );

    // Chiudi il dialog SOLO se l'utente ha selezionato un indirizzo
    if (result != null && context.mounted) {
      Navigator.of(context).pop();
      print('✅ Indirizzo consegna selezionato');
    }
    // Altrimenti l'utente è tornato indietro, il dialog rimane aperto
  }

  /// Gestisce selezione RITIRO
  void _handlePickupSelection(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Imposta modalità RITIRO
    locationProvider.setOrderType('pickup');

    // Chiudi il dialog
    Navigator.of(context).pop();
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
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
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
                  color: textColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  iconPath,
                  width: 26,
                  height: 26,
                  color: textColor,
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
                        color: textColor.withOpacity(0.8),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Freccia
              Icon(
                Icons.arrow_forward_ios,
                color: textColor.withOpacity(0.6),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom clipper per creare effetto onda
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Inizia dall'angolo in alto a sinistra con l'onda
    path.lineTo(0, 40);

    // Curva ondulata in alto
    final firstControlPoint = Offset(size.width * 0.25, 0);
    final firstEndPoint = Offset(size.width * 0.5, 20);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.75, 40);
    final secondEndPoint = Offset(size.width, 20);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    // Completa il rettangolo
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
