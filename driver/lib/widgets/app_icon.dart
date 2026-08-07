import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icona del set custom "Lenny Icons" (assets/icons_svg, condiviso con
/// l'app cliente): SVG vettoriali con tratto blu e blob organico di fondo.
///
/// Accetta sia il nome corto ('portafoglio') sia un path storico in stile
/// cliente ('assets/icons/icons8-portafoglio-32.png'): in entrambi i casi
/// risolve il file SVG corrispondente. La tinta via [color] usa srcIn e
/// preserva l'alpha del blob.
class AppIcon extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final double? size;
  final Color? color;
  final BoxFit fit;

  const AppIcon(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.size,
    this.color,
    this.fit = BoxFit.contain,
  });

  String get _svgPath {
    var base = asset.split('/').last;
    final punto = base.lastIndexOf('.');
    if (punto > 0) base = base.substring(0, punto);
    if (!base.startsWith('icons8-') && !base.startsWith('lenny-')) {
      base = 'icons8-$base-32';
    }
    return 'assets/icons_svg/$base.svg';
  }

  @override
  Widget build(BuildContext context) {
    final w = size ?? width;
    final h = size ?? height;
    return SvgPicture.asset(
      _svgPath,
      width: w,
      height: h,
      fit: fit,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
