import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ponte dalle vecchie icone PNG (Icons8, 32px raster: sfocate sui display
/// moderni) al set SVG custom "Lenny Icons" in assets/icons_svg/.
///
/// Le chiamate nel codice continuano a passare il PATH PNG STORICO: la
/// mappatura al file .svg avviene qui, in un punto solo. Cosi' anche le due
/// sostituzioni concordate (Iron Man -> corona, libro -> cuore) sono
/// centralizzate e non sparse per le schermate.
class AppIcon extends StatelessWidget {
  /// Path storico dell'asset PNG, es. 'assets/icons/icons8-allarme-32.png'
  final String asset;
  final double? width;
  final double? height;

  /// Scorciatoia quadrata (equivalente di ImageIcon.size)
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

  /// Nomi rimappati: icone eliminate dal set per decisione di prodotto
  static const Map<String, String> _rimappate = {
    'icons8-iron-man-48': 'lenny-corona', // IP Marvel: mai piu' in app
    'icons8-romanzo-32': 'lenny-cuore', // il "libro" dei preferiti
  };

  String get _svgPath {
    var base = asset.split('/').last;
    final punto = base.lastIndexOf('.');
    if (punto != -1) base = base.substring(0, punto);
    base = _rimappate[base] ?? base;
    return 'assets/icons_svg/$base.svg';
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _svgPath,
      width: size ?? width,
      height: size ?? height,
      fit: fit,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
