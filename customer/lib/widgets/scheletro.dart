import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Segnaposto animato da mostrare mentre i dati arrivano.
///
/// Sostituisce la rotella. Una rotella dice "aspetta" e basta: la schermata
/// resta vuota, non si capisce cosa stia per arrivare e l'attesa sembra piu'
/// lunga di quella che e'. Il segnaposto invece disegna gia' la forma del
/// contenuto — la foto, il titolo, le due righe di testo — cosi' l'occhio si
/// prepara e il salto al contenuto vero non sposta niente.
///
/// Il riflesso che scorre e' quello che lo fa leggere come "sta caricando"
/// invece che come un blocco grigio rotto.
class Scheletro extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Scheletro({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  /// Riga di testo: piu' corta dell'ultima riga, come nel testo vero.
  const Scheletro.testo({super.key, this.width, this.height = 12})
    : radius = 6;

  @override
  State<Scheletro> createState() => _ScheletroState();
}

class _ScheletroState extends State<Scheletro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Il riflesso attraversa la forma da sinistra a destra: le tre tappe
        // si spostano insieme, restando sempre a distanza fissa.
        final t = _controller.value * 2 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 0.4, 0),
              end: Alignment(t + 0.4, 0),
              colors: [
                AppColors.lightGray.withValues(alpha: 0.30),
                AppColors.lightGray.withValues(alpha: 0.55),
                AppColors.lightGray.withValues(alpha: 0.30),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Scheda piatto o ristorante in attesa: foto, titolo, due righe.
///
/// Le misure ricalcano quelle delle schede vere: e' il punto di tutta la
/// faccenda, altrimenti al momento del cambio la pagina sobbalza.
class ScheletroScheda extends StatelessWidget {
  final double width;
  final double altezzaFoto;

  const ScheletroScheda({super.key, this.width = 170, this.altezzaFoto = 118});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Scheletro(height: altezzaFoto, width: width, radius: 14),
          const SizedBox(height: 10),
          Scheletro.testo(width: width * 0.75, height: 13),
          const SizedBox(height: 7),
          Scheletro.testo(width: width * 0.45, height: 11),
        ],
      ),
    );
  }
}

/// Riga di lista in attesa: miniatura quadrata e testo accanto.
class ScheletroRiga extends StatelessWidget {
  const ScheletroRiga({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Scheletro(width: 78, height: 78, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                const Scheletro.testo(width: 150, height: 14),
                const SizedBox(height: 9),
                Scheletro.testo(
                  width: MediaQuery.sizeOf(context).width * 0.5,
                  height: 11,
                ),
                const SizedBox(height: 7),
                const Scheletro.testo(width: 90, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
