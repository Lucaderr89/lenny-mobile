import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';

/// Dialog che avvisa l'utente che ha prodotti di un altro ristorante nel carrello
Future<bool?> showCartConflictDialog({
  required BuildContext context,
  required String currentRestaurantName,
  required VoidCallback onClearCart,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icona carrello
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD042).withOpacity(0.2),
                    const Color(0xFFFF8E53).withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: 24),

            // Titolo
            Text(
              'Attenzione!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0A0A0A),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Messaggio
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: const Color(0xFF595959),
                  height: 1.6,
                ),
                children: [
                  const TextSpan(text: 'Nel carrello hai prodotti di '),
                  TextSpan(
                    text: currentRestaurantName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '.\n\nNon puoi ordinare da ristoranti diversi '
                        'nello stesso carrello.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Pulsanti
            Column(
              children: [
                // Pulsante Svuota carrello
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, true); // Conferma svuotamento
                      onClearCart();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Svuota carrello',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Pulsante Torna indietro
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0A0A0A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: const Color(0xFFD8D8D8),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Torna indietro',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
