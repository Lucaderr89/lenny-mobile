import 'package:flutter/material.dart';

/// L'ONDA di Lenny: il bordo superiore ondulato delle card bianche a tutta
/// pagina (scelta tipo ordine, selezione indirizzo). E' una firma visiva
/// dell'app: prima era duplicata riga per riga in piu' file, ora vive qui.
///
/// Geometria: parte a y=40 a sinistra, due curve quadratiche
/// (0.25→0, 0.5→20, 0.75→40, destra→20).
class WaveClipper extends CustomClipper<Path> {
  const WaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, 40);

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

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
